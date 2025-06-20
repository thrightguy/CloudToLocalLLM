# CloudToLocalLLM Unified Package Builder (PowerShell)
# Builds all applications with proper dependency alignment for Windows

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipTests,
    [string]$OutputPath,
    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck,
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
$BuildDir = Join-Path $ProjectRoot "build"
$DistDir = Join-Path $ProjectRoot "dist"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
if (-not (Test-Path $versionManagerPath)) {
    Write-LogError "Version manager not found at $versionManagerPath"
    exit 1
}

$Version = & $versionManagerPath get-semantic
if (-not $Version) {
    Write-LogError "Failed to get version from version manager"
    exit 1
}

$PackageDir = Join-Path $DistDir "cloudtolocalllm-$Version"

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Unified Package Builder (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\build_unified_package.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Clean                Clean previous builds before building"
    Write-Host "  -SkipTests            Skip running tests"
    Write-Host "  -OutputPath           Custom output directory path"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\build_unified_package.ps1 -Clean"
    Write-Host "  .\build_unified_package.ps1 -OutputPath C:\MyBuilds"
    exit 0
}

# Check prerequisites
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking prerequisites..."

    # Install build dependencies
    $requiredPackages = @('flutter', 'git', 'visualstudio')
    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies"
        exit 1
    }

    # Check if we're in a Flutter project
    if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
        Write-LogError "Not in a Flutter project directory"
        exit 1
    }

    Write-LogSuccess "Prerequisites check passed"
}

# Clean previous builds
function Clear-Builds {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Cleaning previous builds..."
    
    if (Test-Path $BuildDir) {
        Remove-Item $BuildDir -Recurse -Force
        Write-LogInfo "Removed build directory"
    }
    
    if (Test-Path $PackageDir) {
        Remove-Item $PackageDir -Recurse -Force
        Write-LogInfo "Removed package directory"
    }
    
    # Flutter clean
    Push-Location $ProjectRoot
    try {
        flutter clean
        Write-LogSuccess "Flutter clean completed"
    }
    finally {
        Pop-Location
    }
}

# Build main Flutter application
function Build-MainApp {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Building main Flutter application..."
    
    Push-Location $ProjectRoot
    try {
        # Get dependencies
        Write-LogInfo "Getting Flutter dependencies..."
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get Flutter dependencies"
        }
        
        # Build for Windows
        Write-LogInfo "Building Flutter for Windows..."
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Flutter for Windows"
        }
        
        # Verify build output
        $windowsBuildPath = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
        if (-not (Test-Path $windowsBuildPath)) {
            throw "Windows build output not found at $windowsBuildPath"
        }
        
        Write-LogSuccess "Main Flutter application built successfully"
    }
    finally {
        Pop-Location
    }
}

# Create package structure
function New-PackageStructure {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Creating package structure..."
    
    # Create directories
    New-DirectoryIfNotExists -Path $DistDir
    New-DirectoryIfNotExists -Path $PackageDir
    New-DirectoryIfNotExists -Path (Join-Path $PackageDir "bin")
    New-DirectoryIfNotExists -Path (Join-Path $PackageDir "lib")
    New-DirectoryIfNotExists -Path (Join-Path $PackageDir "data")
    New-DirectoryIfNotExists -Path (Join-Path $PackageDir "docs")
    
    Write-LogSuccess "Package structure created"
}

# Copy Flutter application
function Copy-FlutterApp {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Copying Flutter application..."
    
    $sourcePath = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
    $targetPath = Join-Path $PackageDir "bin"
    
    if (-not (Test-Path $sourcePath)) {
        Write-LogError "Flutter build output not found at $sourcePath"
        exit 1
    }
    
    # Copy all files from Release directory
    Copy-Item "$sourcePath\*" $targetPath -Recurse -Force
    
    # Verify main executable
    $mainExe = Join-Path $targetPath "cloudtolocalllm.exe"
    if (-not (Test-Path $mainExe)) {
        Write-LogError "Main executable not found at $mainExe"
        exit 1
    }
    
    Write-LogSuccess "Flutter application copied successfully"
}

# Create wrapper scripts
function New-WrapperScripts {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Creating wrapper scripts..."
    
    # Create PowerShell wrapper
    $psWrapper = Join-Path $PackageDir "cloudtolocalllm.ps1"
    @"
# CloudToLocalLLM PowerShell Wrapper
# Launches the CloudToLocalLLM application

`$ScriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$ExePath = Join-Path `$ScriptDir "bin\cloudtolocalllm.exe"

if (Test-Path `$ExePath) {
    & `$ExePath `$args
}
else {
    Write-Error "CloudToLocalLLM executable not found at `$ExePath"
    exit 1
}
"@ | Set-Content -Path $psWrapper -Encoding UTF8
    
    # Create batch wrapper
    $batWrapper = Join-Path $PackageDir "cloudtolocalllm.bat"
    @"
@echo off
REM CloudToLocalLLM Batch Wrapper
REM Launches the CloudToLocalLLM application

set SCRIPT_DIR=%~dp0
set EXE_PATH=%SCRIPT_DIR%bin\cloudtolocalllm.exe

if exist "%EXE_PATH%" (
    "%EXE_PATH%" %*
) else (
    echo CloudToLocalLLM executable not found at %EXE_PATH%
    exit /b 1
)
"@ | Set-Content -Path $batWrapper -Encoding ASCII
    
    Write-LogSuccess "Wrapper scripts created"
}

# Add metadata and documentation
function Add-Metadata {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Adding package metadata..."
    
    # Create package info file
    $packageInfo = Join-Path $PackageDir "PACKAGE_INFO.txt"
    @"
CloudToLocalLLM v$Version
========================

Package Type: Unified Windows Package
Architecture: x64
Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Contents:
- Flutter Windows application (cloudtolocalllm.exe)
- Integrated system tray functionality
- All required libraries and data files
- PowerShell and Batch wrapper scripts

Installation:
1. Extract package to desired location
2. Run cloudtolocalllm.exe directly or use wrapper scripts
3. Optionally add to PATH for command-line access

Security Features:
- Native Windows application
- Secure authentication flow
- Local data storage

For more information, visit:
https://github.com/imrightguy/CloudToLocalLLM
"@ | Set-Content -Path $packageInfo -Encoding UTF8
    
    # Add version file
    $Version | Set-Content -Path (Join-Path $PackageDir "VERSION") -Encoding UTF8
    
    # Copy documentation
    $docsDir = Join-Path $PackageDir "docs"
    if (Test-Path (Join-Path $ProjectRoot "README.md")) {
        Copy-Item (Join-Path $ProjectRoot "README.md") $docsDir
    }
    if (Test-Path (Join-Path $ProjectRoot "LICENSE")) {
        Copy-Item (Join-Path $ProjectRoot "LICENSE") $docsDir
    }
    
    Write-LogSuccess "Metadata added"
}

# Main build function
function Invoke-Build {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Starting CloudToLocalLLM unified package build v$Version"
    
    Test-Prerequisites
    
    if ($Clean) {
        Clear-Builds
    }
    
    Build-MainApp
    New-PackageStructure
    Copy-FlutterApp
    New-WrapperScripts
    Add-Metadata
    
    Write-LogSuccess "Unified package build completed successfully!"
    Write-LogInfo "Package location: $PackageDir"
    Write-LogInfo "To run: $PackageDir\cloudtolocalllm.exe"
    Write-LogInfo "Or use wrapper: $PackageDir\cloudtolocalllm.ps1"
}

# Run main function
Invoke-Build
