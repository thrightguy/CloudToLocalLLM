#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automatically commit and push development changes when documentation is complete.

.DESCRIPTION
    Simple script to automatically commit and push uncommitted changes in CloudToLocalLLM.
    Designed to be run at the end of development sessions to ensure changes are saved.

.PARAMETER Message
    Custom commit message. Auto-generated if not provided.

.PARAMETER Force
    Skip validation checks and force commit/push.

.PARAMETER DryRun
    Show what would be committed without actually doing it.

.EXAMPLE
    .\Auto-CommitAndPush.ps1
    # Auto-commit and push with generated message

.EXAMPLE
    .\Auto-CommitAndPush.ps1 -Message "Complete zrok service implementation"
    # Custom commit message

.EXAMPLE
    .\Auto-CommitAndPush.ps1 -DryRun
    # Preview what would be committed
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Message = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

function Write-Status {
    param([string]$Text, [string]$Type = "INFO")
    $color = switch ($Type) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        default { "Cyan" }
    }
    Write-Host "🔄 $Text" -ForegroundColor $color
}

function Get-AutoCommitMessage {
    $status = git status --porcelain
    
    # Analyze changes
    $newFiles = @($status | Where-Object { $_ -match "^\?\?" })
    $modifiedFiles = @($status | Where-Object { $_ -match "^.M" })
    $deletedFiles = @($status | Where-Object { $_ -match "^.D" })
    
    $hasZrok = $status | Where-Object { $_ -match "zrok" }
    $hasNgrokDeletion = $status | Where-Object { $_ -match "ngrok.*D" }
    $hasDocs = $status | Where-Object { $_ -match "docs/|README" }
    $hasTests = $status | Where-Object { $_ -match "test/" }
    
    # Generate message based on changes
    $components = @()
    
    if ($hasZrok) {
        $components += "zrok service implementation"
    }
    
    if ($hasNgrokDeletion) {
        $components += "ngrok service removal"
    }
    
    if ($hasDocs) {
        $components += "documentation updates"
    }
    
    if ($hasTests) {
        $components += "test updates"
    }
    
    if ($components.Count -eq 0) {
        $summary = "Development updates"
    } else {
        $summary = $components -join ", "
    }
    
    return "Development: $summary

Changes:
- New files: $($newFiles.Count)
- Modified files: $($modifiedFiles.Count)
- Deleted files: $($deletedFiles.Count)

Maintains platform abstraction patterns and CloudToLocalLLM standards."
}

# Main execution
try {
    Write-Status "CloudToLocalLLM Auto-Commit and Push" "INFO"
    
    # Check if we're in a git repository
    if (-not (Test-Path ".git")) {
        Write-Status "Not in a Git repository!" "ERROR"
        exit 1
    }
    
    # Check for uncommitted changes
    $changes = git status --porcelain
    if (-not $changes) {
        Write-Status "No uncommitted changes found." "SUCCESS"
        exit 0
    }
    
    Write-Status "Found $($changes.Count) uncommitted changes" "INFO"
    
    # Show changes if dry run
    if ($DryRun) {
        Write-Status "Changes that would be committed:" "INFO"
        git status --short
        
        $commitMsg = if ($Message) { $Message } else { Get-AutoCommitMessage }
        Write-Status "`nCommit message that would be used:" "INFO"
        Write-Host $commitMsg -ForegroundColor Gray
        exit 0
    }
    
    # Quick validation (unless forced)
    if (-not $Force) {
        # Check if flutter analyze passes
        Write-Status "Running quick flutter analyze check..." "INFO"
        $analyzeResult = flutter analyze 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Flutter analyze found issues. Use -Force to override." "WARN"
            Write-Host $analyzeResult -ForegroundColor Yellow
            if (-not $Force) {
                exit 1
            }
        }
    }
    
    # Generate commit message
    $commitMessage = if ($Message) { $Message } else { Get-AutoCommitMessage }
    
    Write-Status "Staging all changes..." "INFO"
    git add .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to stage changes!" "ERROR"
        exit 1
    }
    
    Write-Status "Committing changes..." "INFO"
    git commit -m $commitMessage
    
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to commit changes!" "ERROR"
        exit 1
    }
    
    Write-Status "Pushing to remote..." "INFO"
    git push origin master
    
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to push to remote!" "ERROR"
        exit 1
    }
    
    Write-Status "Successfully committed and pushed all changes!" "SUCCESS"
    Write-Status "Commit message: $($commitMessage.Split("`n")[0])" "INFO"
    
} catch {
    Write-Status "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}
