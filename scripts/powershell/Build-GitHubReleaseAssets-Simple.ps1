# CloudToLocalLLM Simple Package Builder for GitHub Releases
# Creates Windows portable package for GitHub release

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipBuild,
    [switch]$Help
)

# Import build environment utilities
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
} else {
    Write-Host "BuildEnvironmentUtilities module not found, using basic functions" -ForegroundColor Yellow
    
    # Basic logging functions if utilities not available
    function Write-LogInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
    function Write-LogSuccess { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogError { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Write-LogWarning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Get-ProjectRoot { return (Get-Location).Path }
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$OutputDir = Join-Path $ProjectRoot "dist"
$WindowsBuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$WindowsOutputDir = Join-Path $OutputDir "windows"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
if (Test-Path $versionManagerPath) {
    $Version = & $versionManagerPath get-semantic
} else {
    # Fallback to reading from pubspec.yaml
    $pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
    if (Test-Path $pubspecPath) {
        $pubspecContent = Get-Content $pubspecPath
        $versionLine = $pubspecContent | Where-Object { $_ -match "^version:" }
        if ($versionLine) {
            $Version = ($versionLine -split ":")[1].Trim() -replace "\+.*", ""
        } else {
            $Version = "0.0.0"
        }
    } else {
        $Version = "0.0.0"
    }
}

function Show-Help {
    Write-Host "CloudToLocalLLM Simple Package Builder" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\Build-GitHubReleaseAssets-Simple.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Clean      Clean build directories first"
    Write-Host "  -SkipBuild  Skip Flutter build step"
    Write-Host "  -Help       Show this help message"
    Write-Host ""
    Write-Host "This script creates a Windows portable ZIP package for GitHub releases."
}

function New-DirectoryIfNotExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-LogInfo "Created directory: $Path"
    }
}

function Build-FlutterWindows {
    Write-LogInfo "Building Flutter application for Windows using WSL..."

    try {
        if ($Clean) {
            Write-LogInfo "Cleaning Flutter build..."
            Invoke-WSLFlutterCommand -FlutterArgs "clean" -WorkingDirectory $ProjectRoot
        }

        Write-LogInfo "Running flutter pub get..."
        Invoke-WSLFlutterCommand -FlutterArgs "pub get" -WorkingDirectory $ProjectRoot

        Write-LogInfo "Running flutter build windows --release..."
        Invoke-WSLFlutterCommand -FlutterArgs "build windows --release" -WorkingDirectory $ProjectRoot

        $mainExecutable = Join-Path $WindowsBuildDir "cloudtolocalllm.exe"
        if (-not (Test-Path $mainExecutable)) {
            throw "Flutter Windows executable not found after build"
        }

        Write-LogSuccess "Windows Flutter application built successfully using WSL"
    }
    catch {
        Write-LogError "Flutter build failed: $($_.Exception.Message)"
        throw
    }
}

function New-PortableZipPackage {
    Write-LogInfo "Creating portable ZIP package..."
    
    $packageName = "cloudtolocalllm-$Version-portable.zip"
    New-DirectoryIfNotExists -Path $WindowsOutputDir
    
    if (-not (Test-Path $WindowsBuildDir)) {
        throw "Windows build directory not found. Run Flutter build first."
    }
    
    $zipPath = Join-Path $WindowsOutputDir $packageName
    
    Write-LogInfo "Creating ZIP archive: $packageName"
    Compress-Archive -Path "$WindowsBuildDir\*" -DestinationPath $zipPath -Force
    
    # Generate checksum
    $hash = Get-FileHash -Path $zipPath -Algorithm SHA256
    $checksum = $hash.Hash.ToLower()
    "$checksum  $packageName" | Set-Content -Path "$zipPath.sha256" -Encoding UTF8
    
    Write-LogSuccess "Portable ZIP package created: $packageName"
    Write-LogInfo "Package location: $zipPath"
    Write-LogInfo "Checksum: $checksum"
    
    return $zipPath
}

function Main {
    Write-LogInfo "CloudToLocalLLM Simple Package Builder v$Version"
    Write-LogInfo "================================================"
    
    if ($Help) {
        Show-Help
        return
    }
    
    try {
        # Create output directories
        New-DirectoryIfNotExists -Path $OutputDir
        New-DirectoryIfNotExists -Path $WindowsOutputDir
        
        # Build Flutter application if not skipped
        if (-not $SkipBuild) {
            Build-FlutterWindows
        }
        
        # Create portable ZIP package
        $packagePath = New-PortableZipPackage
        
        Write-LogSuccess "Package creation completed successfully!"
        Write-LogInfo "Package ready for GitHub release: $packagePath"
        
    } catch {
        Write-LogError "Script failed: $($_.Exception.Message)"
        exit 1
    }
}

# Execute main function
Main
