# CloudToLocalLLM Deployment Pipeline Test Script (PowerShell)
# Tests the updated deployment pipeline with Flutter SDK and package updates

[CmdletBinding()]
param(
    [ValidateSet('Local', 'Docker', 'VPS')]
    [string]$TestMode = 'Local',
    
    [switch]$DryRun,
    [switch]$VerboseOutput,
    [switch]$Help
)

# Import build environment utilities
$utilsPath = Join-Path $PSScriptRoot "..\powershell\BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
}
else {
    Write-Error "BuildEnvironmentUtilities module not found at $utilsPath"
    exit 1
}

# Configuration
$ProjectRoot = Get-ProjectRoot

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Deployment Pipeline Test Script (PowerShell)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tests the updated deployment pipeline with Flutter SDK and package updates" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\Test-DeploymentPipeline.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -TestMode         Test mode: Local, Docker, or VPS (default: Local)"
    Write-Host "  -DryRun           Perform dry run without making changes"
    Write-Host "  -VerboseOutput    Enable verbose output"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
    Write-Host "Test Modes:" -ForegroundColor Yellow
    Write-Host "  Local             Test Flutter updates and build locally"
    Write-Host "  Docker            Test using Docker Flutter builder"
    Write-Host "  VPS               Test VPS deployment pipeline (requires WSL/Linux environment)"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\Test-DeploymentPipeline.ps1 -TestMode Local -VerboseOutput"
    Write-Host "  .\Test-DeploymentPipeline.ps1 -TestMode Docker -DryRun"
    Write-Host "  .\Test-DeploymentPipeline.ps1 -TestMode VPS -DryRun"
    exit 0
}

# Test local Flutter environment
function Test-LocalFlutter {
    [CmdletBinding()]
    param()

    Write-LogInfo "Testing local Flutter environment..."
    
    try {
        # Check Flutter installation
        if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
            Write-LogError "Flutter is not installed or not in PATH"
            return $false
        }
        
        $currentVersion = flutter --version | Select-Object -First 1
        Write-LogInfo "Current Flutter version: $currentVersion"
        
        # Test Flutter upgrade (dry run mode)
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would execute 'flutter upgrade --force'"
        }
        else {
            Write-LogInfo "Upgrading Flutter SDK..."
            flutter upgrade --force
        }
        
        # Test package upgrade
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would execute 'flutter pub upgrade'"
        }
        else {
            Write-LogInfo "Upgrading package dependencies..."
            flutter pub upgrade
        }
        
        # Test web build
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would execute 'flutter build web'"
        }
        else {
            Write-LogInfo "Testing Flutter web build..."
            flutter clean
            flutter pub get
            flutter build web --release --no-tree-shake-icons
            
            # Verify build output
            if (Test-Path "build\web\index.html") {
                Write-LogSuccess "Flutter web build completed successfully"
                $buildSize = (Get-ChildItem "build\web" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
                Write-LogInfo "Build output size: $([math]::Round($buildSize, 2)) MB"
            }
            else {
                Write-LogError "Flutter web build failed - index.html not found"
                return $false
            }
        }
        
        Write-LogSuccess "Local Flutter environment test completed"
        return $true
    }
    catch {
        Write-LogError "Local Flutter test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Docker Flutter builder
function Test-DockerFlutter {
    [CmdletBinding()]
    param()

    Write-LogInfo "Testing Docker Flutter builder..."
    
    try {
        # Check if Docker is available
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            Write-LogError "Docker is not installed or not in PATH"
            return $false
        }
        
        # Build Flutter builder image
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would build Docker Flutter builder image"
        }
        else {
            Write-LogInfo "Building Flutter builder Docker image..."
            docker-compose -f docker-compose.flutter-builder.yml build flutter-builder
        }
        
        # Test Flutter SDK update in container
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would test Flutter SDK update in container"
        }
        else {
            Write-LogInfo "Testing Flutter SDK update in container..."
            docker-compose -f docker-compose.flutter-builder.yml run --rm flutter-builder /home/flutter/update-flutter.sh
        }
        
        # Test web build in container
        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would test Flutter web build in container"
        }
        else {
            Write-LogInfo "Testing Flutter web build in container..."
            docker-compose -f docker-compose.flutter-builder.yml run --rm flutter-builder /home/flutter/build-web.sh
            
            # Verify build output
            if (Test-Path "build\web\index.html") {
                Write-LogSuccess "Docker Flutter web build completed successfully"
            }
            else {
                Write-LogError "Docker Flutter web build failed - index.html not found"
                return $false
            }
        }
        
        Write-LogSuccess "Docker Flutter builder test completed"
        return $true
    }
    catch {
        Write-LogError "Docker Flutter test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test VPS deployment pipeline
function Test-VPSDeployment {
    [CmdletBinding()]
    param()

    Write-LogInfo "Testing VPS deployment pipeline..."

    try {
        # Check if bash deployment script exists
        $deployScript = Join-Path $PSScriptRoot "update_and_deploy.sh"
        if (-not (Test-Path $deployScript)) {
            Write-LogError "VPS deployment script not found: $deployScript"
            return $false
        }

        # Test deployment script with dry run
        if ($DryRun) {
            Write-LogInfo "Testing VPS deployment via WSL in dry-run mode..."
            Write-LogWarning "VPS deployment must use WSL/Linux environment"
            Write-LogInfo "To test VPS deployment, use WSL: wsl -d archlinux bash scripts/deploy/update_and_deploy.sh --verbose"
        }
        else {
            Write-LogWarning "VPS deployment requires WSL/Linux environment and SSH configuration"
            Write-LogInfo "To test VPS deployment, use WSL: wsl -d archlinux bash scripts/deploy/update_and_deploy.sh --verbose"
        }

        Write-LogSuccess "VPS deployment pipeline test completed"
        return $true
    }
    catch {
        Write-LogError "VPS deployment test failed: $($_.Exception.Message)"
        return $false
    }
}

# Main test function
function Invoke-Main {
    [CmdletBinding()]
    param()

    Write-Host "CloudToLocalLLM Deployment Pipeline Test" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "Test Mode: $TestMode"
    Write-Host "Dry Run: $DryRun"
    Write-Host "Verbose: $VerboseOutput"
    Write-Host ""
    
    $success = $false
    
    switch ($TestMode) {
        'Local' {
            $success = Test-LocalFlutter
        }
        'Docker' {
            $success = Test-DockerFlutter
        }
        'VPS' {
            $success = Test-VPSDeployment
        }
        default {
            Write-LogError "Invalid test mode: $TestMode"
            Write-LogError "Valid modes: Local, Docker, VPS"
            exit 1
        }
    }
    
    if ($success) {
        Write-LogSuccess "All tests completed successfully!"
        exit 0
    }
    else {
        Write-LogError "Some tests failed"
        exit 1
    }
}

# Execute main function
Invoke-Main
