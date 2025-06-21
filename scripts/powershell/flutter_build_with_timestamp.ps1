# CloudToLocalLLM Flutter Build Wrapper with Build-Time Timestamp Injection (PowerShell)
# Wraps Flutter build commands to inject actual build timestamp at build execution time

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$BuildTarget,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs = @(),

    [switch]$VerboseOutput,
    [switch]$DryRun,
    [switch]$SkipInjection,
    [switch]$Help
)

# Import build environment utilities
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
}
else {
    Write-Error "BuildEnvironmentUtilities module not found at $utilsPath"
    exit 1
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$TimestampInjectorPath = Join-Path $PSScriptRoot "simple_timestamp_injector.ps1"

# Show usage information
function Show-Usage {
    Write-Host "CloudToLocalLLM Flutter Build Wrapper with Build-Time Timestamp Injection (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\flutter_build_with_timestamp.ps1 <build_target> [flutter_args...] [OPTIONS]"
    Write-Host ""
    Write-Host "BUILD TARGETS:" -ForegroundColor Yellow
    Write-Host "    windows         Build for Windows"
    Write-Host "    linux           Build for Linux (via WSL)"
    Write-Host "    web             Build for Web"
    Write-Host "    android         Build for Android"
    Write-Host "    ios             Build for iOS"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "    -VerboseOutput  Enable detailed logging"
    Write-Host "    -DryRun         Simulate build without actual execution"
    Write-Host "    -SkipInjection  Skip timestamp injection (use existing version)"
    Write-Host "    -Help           Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "    .\flutter_build_with_timestamp.ps1 web --release"
    Write-Host "    .\flutter_build_with_timestamp.ps1 windows --release -VerboseOutput"
    Write-Host "    .\flutter_build_with_timestamp.ps1 linux --release -DryRun"
    Write-Host ""
    Write-Host "WORKFLOW:" -ForegroundColor Yellow
    Write-Host "    1. Inject current timestamp into version files"
    Write-Host "    2. Execute Flutter build command"
    Write-Host "    3. Build artifacts contain exact timestamp of build execution"
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

if (-not $BuildTarget) {
    Write-LogError "No build target specified"
    Show-Usage
    exit 1
}

# Header
Write-Host "CloudToLocalLLM Flutter Build with Build-Time Timestamp Injection (PowerShell)" -ForegroundColor Blue
Write-Host "=============================================================================" -ForegroundColor Blue
Write-Host ""

# Check prerequisites
if (-not (Test-Path $TimestampInjectorPath)) {
    Write-LogError "Timestamp injector script not found: $TimestampInjectorPath"
    exit 1
}

# Execute build workflow
try {
    # Inject timestamp if not skipped
    if (-not $SkipInjection) {
        Write-LogInfo "Injecting build timestamp..."

        if ($DryRun) {
            Write-LogInfo "DRY RUN: Would inject build timestamp"
        }
        else {
            if ($VerboseOutput) {
                & $TimestampInjectorPath -VerboseOutput
            }
            else {
                & $TimestampInjectorPath
            }

            if ($LASTEXITCODE -ne 0) {
                throw "Timestamp injection failed with exit code $LASTEXITCODE"
            }

            Write-LogSuccess "Build timestamp injected"
        }
    }
    else {
        Write-LogWarning "Skipping timestamp injection (-SkipInjection flag)"
    }

    # Execute Flutter build
    $flutterCommand = "flutter build $BuildTarget"
    if ($FlutterArgs.Count -gt 0) {
        $flutterCommand += " " + ($FlutterArgs -join " ")
    }

    Write-LogInfo "Executing Flutter build: $flutterCommand"

    if ($DryRun) {
        Write-LogInfo "DRY RUN: Would execute: $flutterCommand"
    }
    else {
        Set-Location $ProjectRoot

        $buildStartTime = Get-Date
        Write-LogInfo "Build started at: $buildStartTime"

        # Handle different build targets
        switch ($BuildTarget.ToLower()) {
            'linux' {
                # Linux builds require WSL
                if (-not (Test-WSLAvailable)) {
                    throw "WSL is required for Linux builds but not available"
                }

                $linuxDistro = Find-WSLDistribution -Purpose 'Any'
                if (-not $linuxDistro) {
                    throw "No running WSL distribution found for Linux builds"
                }

                $projectRootWSL = Convert-WindowsPathToWSL -WindowsPath $ProjectRoot
                $bashCommand = "cd '$projectRootWSL' && $flutterCommand"

                if ($VerboseOutput) {
                    Invoke-WSLCommand -DistroName $linuxDistro -Command $bashCommand -WorkingDirectory $ProjectRoot
                }
                else {
                    Invoke-WSLCommand -DistroName $linuxDistro -Command $bashCommand -WorkingDirectory $ProjectRoot | Out-Null
                }
            }
            default {
                # Windows, Web, Android, iOS builds
                if ($VerboseOutput) {
                    Invoke-Expression $flutterCommand
                }
                else {
                    Invoke-Expression $flutterCommand | Out-Null
                }
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build failed with exit code $LASTEXITCODE"
        }

        $buildEndTime = Get-Date
        Write-LogInfo "Build completed at: $buildEndTime"
    }

    Write-LogSuccess "Flutter build completed successfully!"
}
catch {
    $errorMessage = $_.Exception.Message
    Write-LogError "Unexpected error: $errorMessage"
    exit 3
}
