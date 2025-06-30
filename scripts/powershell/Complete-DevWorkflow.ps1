#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete development workflow with automatic commit and push when documentation is ready.

.DESCRIPTION
    This script automates the development workflow for CloudToLocalLLM:
    1. Checks for uncommitted changes
    2. Validates documentation completeness
    3. Runs static analysis (flutter analyze, PSScriptAnalyzer)
    4. Commits changes with appropriate messages
    5. Pushes to remote repository
    6. Optionally creates a development release

.PARAMETER CommitMessage
    Custom commit message. If not provided, generates one based on changes.

.PARAMETER SkipAnalysis
    Skip static analysis checks (flutter analyze, PSScriptAnalyzer).

.PARAMETER SkipPush
    Commit changes but don't push to remote.

.PARAMETER CreateDevRelease
    Create a development release after successful push.

.PARAMETER Force
    Force commit and push even if there are analysis issues.

.PARAMETER Verbose
    Enable verbose output for debugging.

.EXAMPLE
    .\Complete-DevWorkflow.ps1
    # Automatically detects changes, validates, and pushes

.EXAMPLE
    .\Complete-DevWorkflow.ps1 -CommitMessage "Implement zrok service with platform abstraction" -CreateDevRelease
    # Custom commit message and create development release

.EXAMPLE
    .\Complete-DevWorkflow.ps1 -SkipAnalysis -Force
    # Skip analysis and force push (use with caution)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CommitMessage = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAnalysis,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPush,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateDevRelease,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        "ERROR" { "❌ [ERROR]" }
        "WARN"  { "⚠️ [WARN]" }
        "SUCCESS" { "✅ [SUCCESS]" }
        default { "ℹ️ [INFO]" }
    }
    Write-Host "$prefix $timestamp - $Message"
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n🔄 [STEP] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
}

function Write-Header {
    Write-Host "`n================================================================" -ForegroundColor Green
    Write-Host "CloudToLocalLLM Development Workflow Automation" -ForegroundColor Green
    Write-Host "Version: 1.0.0 - Auto-commit and push when documentation ready" -ForegroundColor Green
    Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
    Write-Host "================================================================`n" -ForegroundColor Green
}

function Test-GitRepository {
    if (-not (Test-Path ".git")) {
        Write-Log "Not in a Git repository" "ERROR"
        exit 1
    }
    Write-Log "Git repository detected" "SUCCESS"
}

function Get-UncommittedChanges {
    $status = git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to get git status" "ERROR"
        exit 1
    }
    return $status
}

function Test-DocumentationCompleteness {
    Write-Step "Checking documentation completeness"
    
    $requiredDocs = @(
        "README.md",
        "docs/RELEASE_WORKFLOW.md",
        "docs/BUILD_SCRIPTS_GUIDE.md"
    )
    
    $missingDocs = @()
    foreach ($doc in $requiredDocs) {
        if (-not (Test-Path $doc)) {
            $missingDocs += $doc
        }
    }
    
    if ($missingDocs.Count -gt 0) {
        Write-Log "Missing required documentation: $($missingDocs -join ', ')" "WARN"
        return $false
    }
    
    # Check if zrok service has documentation
    if (Test-Path "lib/services/zrok_service.dart") {
        $zrokContent = Get-Content "lib/services/zrok_service.dart" -Raw
        if ($zrokContent -notmatch "///.*[Zz]rok.*service") {
            Write-Log "Zrok service implementation found but lacks proper documentation" "WARN"
            return $false
        }
    }
    
    Write-Log "Documentation completeness check passed" "SUCCESS"
    return $true
}

function Invoke-StaticAnalysis {
    Write-Step "Running static analysis"
    
    # Flutter analyze using WSL
    Write-Log "Running flutter analyze via WSL..."
    try {
        Invoke-WSLFlutterCommand -FlutterArgs "analyze" -WorkingDirectory (Get-Location).Path
        Write-Log "Flutter analyze passed" "SUCCESS"
    }
    catch {
        Write-Log "Flutter analyze found issues" "ERROR"
        return $false
    }
    
    # PSScriptAnalyzer for PowerShell scripts
    Write-Log "Running PSScriptAnalyzer on PowerShell scripts..."
    $psScripts = Get-ChildItem -Path "scripts/powershell" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
    foreach ($script in $psScripts) {
        $issues = Invoke-ScriptAnalyzer -Path $script.FullName -Severity Error
        if ($issues.Count -gt 0) {
            Write-Log "PSScriptAnalyzer found issues in $($script.Name)" "ERROR"
            $issues | ForEach-Object { Write-Log "  - $($_.Message)" "ERROR" }
            return $false
        }
    }
    Write-Log "PSScriptAnalyzer passed" "SUCCESS"
    
    return $true
}

function New-CommitMessage {
    param([array]$Changes)
    
    if ($CommitMessage) {
        return $CommitMessage
    }
    
    # Analyze changes to generate appropriate commit message
    $hasZrokChanges = $Changes | Where-Object { $_ -match "zrok" }
    $hasNgrokDeletions = $Changes | Where-Object { $_ -match "^D.*ngrok" }
    $hasDocChanges = $Changes | Where-Object { $_ -match "docs/" -or $_ -match "README" }
    $hasTestChanges = $Changes | Where-Object { $_ -match "test/" }
    
    $components = @()
    
    if ($hasZrokChanges) {
        $components += "Implement zrok service with platform abstraction"
    }
    
    if ($hasNgrokDeletions) {
        $components += "Remove ngrok service implementation"
    }
    
    if ($hasDocChanges) {
        $components += "Update documentation"
    }
    
    if ($hasTestChanges) {
        $components += "Update tests"
    }
    
    if ($components.Count -eq 0) {
        return "Development workflow: Update implementation and documentation"
    }
    
    $message = $components -join ", "
    return "Development workflow: $message

- Maintain platform abstraction patterns
- Follow CloudToLocalLLM coding standards
- Ensure cross-platform compatibility
- Update tests and documentation"
}

# Main execution
try {
    Write-Header
    
    # Step 1: Validate Git repository
    Test-GitRepository
    
    # Step 2: Check for uncommitted changes
    Write-Step "Checking for uncommitted changes"
    $changes = Get-UncommittedChanges
    if (-not $changes) {
        Write-Log "No uncommitted changes found" "SUCCESS"
        Write-Log "Development workflow complete - nothing to commit"
        exit 0
    }
    
    Write-Log "Found $($changes.Count) uncommitted changes"
    if ($Verbose) {
        $changes | ForEach-Object { Write-Log "  $_" }
    }
    
    # Step 3: Check documentation completeness
    if (-not $Force) {
        $docsComplete = Test-DocumentationCompleteness
        if (-not $docsComplete) {
            Write-Log "Documentation is incomplete. Use -Force to override." "ERROR"
            exit 1
        }
    }
    
    # Step 4: Run static analysis
    if (-not $SkipAnalysis -and -not $Force) {
        $analysisPass = Invoke-StaticAnalysis
        if (-not $analysisPass) {
            Write-Log "Static analysis failed. Use -Force to override or -SkipAnalysis to skip." "ERROR"
            exit 1
        }
    }
    
    # Step 5: Stage and commit changes
    Write-Step "Staging and committing changes"
    
    # Add all changes
    git add .
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to stage changes" "ERROR"
        exit 1
    }
    
    # Generate commit message
    $finalCommitMessage = New-CommitMessage -Changes $changes
    Write-Log "Commit message: $finalCommitMessage"
    
    # Commit changes
    git commit -m $finalCommitMessage
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to commit changes" "ERROR"
        exit 1
    }
    Write-Log "Changes committed successfully" "SUCCESS"
    
    # Step 6: Push to remote (unless skipped)
    if (-not $SkipPush) {
        Write-Step "Pushing to remote repository"
        git push origin master
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to push to remote" "ERROR"
            exit 1
        }
        Write-Log "Changes pushed to remote successfully" "SUCCESS"
    }
    
    # Step 7: Create development release (if requested)
    if ($CreateDevRelease) {
        Write-Step "Creating development release"
        $devVersion = "dev-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        git tag $devVersion
        git push origin $devVersion
        Write-Log "Development release created: $devVersion" "SUCCESS"
    }
    
    Write-Log "Development workflow completed successfully!" "SUCCESS"

    # Step 8: Create documentation complete marker
    if (-not $SkipPush) {
        Write-Step "Creating documentation complete marker"
        Set-Content -Path ".docs-complete" -Value "Documentation complete at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Log "Documentation complete marker created" "SUCCESS"
    }

} catch {
    Write-Log "Development workflow failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Helper function to install git hooks
function Install-GitHooks {
    Write-Step "Installing Git hooks for auto-push"

    $hookSource = "scripts/git-hooks/post-commit"
    $hookDest = ".git/hooks/post-commit"

    if (Test-Path $hookSource) {
        Copy-Item $hookSource $hookDest -Force

        # Make executable on Unix systems
        if ($IsLinux -or $IsMacOS) {
            chmod +x $hookDest
        }

        Write-Log "Git post-commit hook installed" "SUCCESS"
    } else {
        Write-Log "Git hook source not found: $hookSource" "WARN"
    }
}
