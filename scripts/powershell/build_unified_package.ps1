# CloudToLocalLLM Unified Package Builder (PowerShell)
# Builds unified Flutter application with proper dependency alignment for Windows and Linux

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('windows', 'linux', 'web', 'all')]
    [string]$Platform = 'windows',

    [switch]$Clean,
    [switch]$SkipTests,
    [string]$OutputPath,
    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck,
    [switch]$VerboseOutput,
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
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\build_unified_package.ps1 [PLATFORM] [OPTIONS]"
    Write-Host ""
    Write-Host "PLATFORMS:" -ForegroundColor Yellow
    Write-Host "    windows         Build for Windows (default)"
    Write-Host "    linux           Build for Linux (via WSL)"
    Write-Host "    web             Build for Web"
    Write-Host "    all             Build for all platforms"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "    -Clean              Clean previous builds before building"
    Write-Host "    -SkipTests          Skip running tests"
    Write-Host "    -OutputPath         Custom output directory path"
    Write-Host "    -AutoInstall        Automatically install missing dependencies"
    Write-Host "    -SkipDependencyCheck Skip dependency validation"
    Write-Host "    -VerboseOutput      Enable verbose output"
    Write-Host "    -Help               Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "    .\build_unified_package.ps1 windows -Clean"
    Write-Host "    .\build_unified_package.ps1 linux -AutoInstall"
    Write-Host "    .\build_unified_package.ps1 all -VerboseOutput"
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "    Builds the unified CloudToLocalLLM Flutter application for specified platforms."
    Write-Host "    Creates distributable packages with proper dependency alignment."
    Write-Host "    Supports Windows native builds and Linux builds via WSL integration."
    exit 0
}

# Check prerequisites for the specified platform
function Test-Prerequisites {
    [CmdletBinding()]
    param([string]$TargetPlatform)

    Write-LogInfo "Checking prerequisites for $TargetPlatform build..."

    $requiredPackages = @('flutter', 'git')

    # Platform-specific requirements
    switch ($TargetPlatform) {
        'windows' {
            # Windows builds require Visual Studio Build Tools
            $requiredPackages += @('visualstudio')
        }
        'linux' {
            # Linux builds require WSL
            if (-not (Test-WSLAvailable)) {
                Write-LogError "WSL is required for Linux builds but not available"
                return $false
            }

            $linuxDistro = Find-WSLDistribution -Purpose 'Any'
            if (-not $linuxDistro) {
                Write-LogError "No running WSL distribution found for Linux builds"
                return $false
            }

            Write-LogInfo "Using WSL distribution: $linuxDistro"
        }
        'web' {
            # Web builds have no additional requirements beyond Flutter
        }
        'all' {
            # All platforms require WSL for Linux builds
            if (-not (Test-WSLAvailable)) {
                Write-LogWarning "WSL not available - Linux builds will be skipped"
            }
            $requiredPackages += @('visualstudio')
        }
    }

    # Install dependencies if needed
    if (-not $SkipDependencyCheck) {
        if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
            Write-LogError "Failed to install required dependencies for $TargetPlatform build"
            return $false
        }
    }

    # Check if we're in a Flutter project
    if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
        Write-LogError "Not in a Flutter project directory"
        return $false
    }

    Write-LogSuccess "Prerequisites check completed for $TargetPlatform"
    return $true
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

# Build Flutter application for Windows
function Build-WindowsApp {
    [CmdletBinding()]
    param()

    Write-LogInfo "Building Flutter application for Windows..."

    try {
        Set-Location $ProjectRoot

        # Get dependencies
        Write-LogInfo "Getting Flutter dependencies..."
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter pub get failed with exit code $LASTEXITCODE"
        }

        # Build for Windows
        Write-LogInfo "Building Windows release..."
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build windows failed with exit code $LASTEXITCODE"
        }

        # Verify build output
        $windowsBuildPath = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
        if (-not (Test-Path $windowsBuildPath)) {
            throw "Windows build output not found at $windowsBuildPath"
        }

        Write-LogSuccess "Windows application built successfully"
        return $true
    }
    catch {
        Write-LogError "Failed to build Windows application: $($_.Exception.Message)"
        return $false
    }
}

# Build Flutter application for Linux via WSL
function Build-LinuxApp {
    [CmdletBinding()]
    param()

    Write-LogInfo "Building Flutter application for Linux via WSL..."

    try {
        $linuxDistro = Find-WSLDistribution -Purpose 'Any'
        if (-not $linuxDistro) {
            throw "No running WSL distribution found"
        }

        $projectRootWSL = Convert-WindowsPathToWSL -WindowsPath $ProjectRoot

        # Get dependencies
        Write-LogInfo "Getting Flutter dependencies via WSL..."
        Invoke-WSLCommand -DistroName $linuxDistro -Command "cd '$projectRootWSL' && flutter pub get" -WorkingDirectory $ProjectRoot

        # Build for Linux
        Write-LogInfo "Building Linux release via WSL..."
        Invoke-WSLCommand -DistroName $linuxDistro -Command "cd '$projectRootWSL' && flutter build linux --release" -WorkingDirectory $ProjectRoot

        # Verify build output
        $linuxBuildPath = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
        if (-not (Test-Path $linuxBuildPath)) {
            throw "Linux build output not found at $linuxBuildPath"
        }

        Write-LogSuccess "Linux application built successfully via WSL"
        return $true
    }
    catch {
        Write-LogError "Failed to build Linux application: $($_.Exception.Message)"
        return $false
    }
}

# Build Flutter application for Web
function Build-WebApp {
    [CmdletBinding()]
    param()

    Write-LogInfo "Building Flutter application for Web..."

    try {
        Set-Location $ProjectRoot

        # Get dependencies
        Write-LogInfo "Getting Flutter dependencies..."
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter pub get failed with exit code $LASTEXITCODE"
        }

        # Build for Web
        Write-LogInfo "Building Web release..."
        flutter build web --release
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build web failed with exit code $LASTEXITCODE"
        }

        # Verify build output
        $webBuildPath = Join-Path $ProjectRoot "build\web"
        if (-not (Test-Path $webBuildPath)) {
            throw "Web build output not found at $webBuildPath"
        }

        Write-LogSuccess "Web application built successfully"
        return $true
    }
    catch {
        Write-LogError "Failed to build Web application: $($_.Exception.Message)"
        return $false
    }
}

# Create unified package structure for Windows
function New-WindowsPackageStructure {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating Windows package structure..."

    try {
        $windowsPackageDir = "$PackageDir-windows"
        New-DirectoryIfNotExists -Path $windowsPackageDir
        New-DirectoryIfNotExists -Path "$windowsPackageDir\bin"
        New-DirectoryIfNotExists -Path "$windowsPackageDir\data"
        New-DirectoryIfNotExists -Path "$windowsPackageDir\docs"

        # Copy Windows build output
        $windowsBuildPath = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
        if (Test-Path $windowsBuildPath) {
            Copy-Item "$windowsBuildPath\*" $windowsPackageDir -Recurse -Force
            Write-LogInfo "Copied Windows build output"
        }

        # Create version info
        Set-Content -Path "$windowsPackageDir\VERSION" -Value $Version -Encoding UTF8

        # Create wrapper scripts for Windows
        New-WindowsWrapperScripts -PackageDir $windowsPackageDir

        Write-LogSuccess "Windows package structure created at $windowsPackageDir"
        return $true
    }
    catch {
        Write-LogError "Failed to create Windows package structure: $($_.Exception.Message)"
        return $false
    }
}

# Create unified package structure for Linux
function New-LinuxPackageStructure {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating Linux package structure..."

    try {
        $linuxPackageDir = "$PackageDir-linux"
        New-DirectoryIfNotExists -Path $linuxPackageDir
        New-DirectoryIfNotExists -Path "$linuxPackageDir\bin"
        New-DirectoryIfNotExists -Path "$linuxPackageDir\lib"
        New-DirectoryIfNotExists -Path "$linuxPackageDir\data"
        New-DirectoryIfNotExists -Path "$linuxPackageDir\docs"

        # Copy Linux build output
        $linuxBuildPath = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
        if (Test-Path $linuxBuildPath) {
            Copy-Item "$linuxBuildPath\*" $linuxPackageDir -Recurse -Force

            # Move main executable to bin directory
            $mainExecutable = Join-Path $linuxPackageDir "cloudtolocalllm"
            if (Test-Path $mainExecutable) {
                Move-Item $mainExecutable "$linuxPackageDir\bin\cloudtolocalllm"
            }

            Write-LogInfo "Copied Linux build output"
        }

        # Create version info
        Set-Content -Path "$linuxPackageDir\VERSION" -Value $Version -Encoding UTF8

        Write-LogSuccess "Linux package structure created at $linuxPackageDir"
        return $true
    }
    catch {
        Write-LogError "Failed to create Linux package structure: $($_.Exception.Message)"
        return $false
    }
}

# Create unified package structure for Web
function New-WebPackageStructure {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating Web package structure..."

    try {
        $webPackageDir = "$PackageDir-web"
        New-DirectoryIfNotExists -Path $webPackageDir

        # Copy Web build output
        $webBuildPath = Join-Path $ProjectRoot "build\web"
        if (Test-Path $webBuildPath) {
            Copy-Item "$webBuildPath\*" $webPackageDir -Recurse -Force
            Write-LogInfo "Copied Web build output"
        }

        # Create version info
        Set-Content -Path "$webPackageDir\VERSION" -Value $Version -Encoding UTF8

        Write-LogSuccess "Web package structure created at $webPackageDir"
        return $true
    }
    catch {
        Write-LogError "Failed to create Web package structure: $($_.Exception.Message)"
        return $false
    }
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

# Create wrapper scripts for Windows
function New-WindowsWrapperScripts {
    [CmdletBinding()]
    param([string]$PackageDir)

    Write-LogInfo "Creating Windows wrapper scripts..."

    # Create PowerShell wrapper
    $psWrapper = Join-Path $PackageDir "cloudtolocalllm.ps1"
    @"
# CloudToLocalLLM PowerShell Wrapper
# Launches the CloudToLocalLLM application

`$ScriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$ExePath = Join-Path `$ScriptDir "cloudtolocalllm.exe"

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
set EXE_PATH=%SCRIPT_DIR%cloudtolocalllm.exe

if exist "%EXE_PATH%" (
    "%EXE_PATH%" %*
) else (
    echo CloudToLocalLLM executable not found at %EXE_PATH%
    exit /b 1
)
"@ | Set-Content -Path $batWrapper -Encoding ASCII

    Write-LogSuccess "Windows wrapper scripts created"
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
function Invoke-UnifiedBuild {
    [CmdletBinding()]
    param([string]$TargetPlatform)

    Write-LogInfo "Starting CloudToLocalLLM unified package build v$Version for $TargetPlatform"

    # Check prerequisites
    if (-not (Test-Prerequisites -TargetPlatform $TargetPlatform)) {
        return $false
    }

    # Clean builds if requested
    if ($Clean) {
        if (-not (Clear-Builds)) {
            return $false
        }
    }

    # Build based on platform
    $buildSuccess = $false
    switch ($TargetPlatform) {
        'windows' {
            $buildSuccess = Build-WindowsApp
            if ($buildSuccess) {
                $buildSuccess = New-WindowsPackageStructure
            }
        }
        'linux' {
            $buildSuccess = Build-LinuxApp
            if ($buildSuccess) {
                $buildSuccess = New-LinuxPackageStructure
            }
        }
        'web' {
            $buildSuccess = Build-WebApp
            if ($buildSuccess) {
                $buildSuccess = New-WebPackageStructure
            }
        }
        'all' {
            $allSuccess = $true

            # Build Windows
            if (Build-WindowsApp) {
                $allSuccess = $allSuccess -and (New-WindowsPackageStructure)
            } else {
                Write-LogWarning "Windows build failed"
                $allSuccess = $false
            }

            # Build Linux (if WSL available)
            if (Test-WSLAvailable) {
                if (Build-LinuxApp) {
                    $allSuccess = $allSuccess -and (New-LinuxPackageStructure)
                } else {
                    Write-LogWarning "Linux build failed"
                    $allSuccess = $false
                }
            } else {
                Write-LogWarning "Skipping Linux build - WSL not available"
            }

            # Build Web
            if (Build-WebApp) {
                $allSuccess = $allSuccess -and (New-WebPackageStructure)
            } else {
                Write-LogWarning "Web build failed"
                $allSuccess = $false
            }

            $buildSuccess = $allSuccess
        }
    }

    if ($buildSuccess) {
        Write-LogSuccess "Unified package build completed successfully for $TargetPlatform!"
        Write-LogInfo "Package location: $DistDir"
        return $true
    }
    else {
        Write-LogError "Build failed for $TargetPlatform"
        return $false
    }
}

# Main execution
if ($VerboseOutput) {
    Write-LogInfo "CloudToLocalLLM Unified Package Builder (PowerShell)"
    Write-LogInfo "Project root: $ProjectRoot"
    Write-LogInfo "Target platform: $Platform"
    Write-LogInfo "Version: $Version"
}

# Execute build
$success = Invoke-UnifiedBuild -TargetPlatform $Platform

if ($success) {
    Write-LogSuccess "🎉 Build completed successfully!"
    exit 0
}
else {
    Write-LogError "❌ Build failed"
    exit 1
}
