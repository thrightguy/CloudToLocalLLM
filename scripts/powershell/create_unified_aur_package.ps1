# CloudToLocalLLM Unified AUR Binary Package Creator (PowerShell)
# Creates a binary package from the unified Flutter build output
# Single Flutter application with integrated system tray - no Python dependencies

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [string]$WSLDistro,
    [switch]$UseWSL,
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

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Unified AUR Binary Package Creator (PowerShell)" -ForegroundColor Blue
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Creates a binary package from the unified Flutter build output for AUR distribution" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\create_unified_aur_package.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -SkipBuild            Skip Flutter build step"
    Write-Host "  -SkipTests            Skip package integrity tests"
    Write-Host "  -UseWSL               Use WSL for Linux operations"
    Write-Host "  -WSLDistro            Specific WSL distribution to use"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - Flutter SDK"
    Write-Host "  - WSL with Arch Linux (for makepkg)"
    Write-Host "  - Git"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\create_unified_aur_package.ps1"
    Write-Host "  .\create_unified_aur_package.ps1 -UseWSL -WSLDistro Arch"
    Write-Host "  .\create_unified_aur_package.ps1 -SkipBuild -SkipTests"
    exit 0
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$Version = Get-ProjectVersion
$BuildDir = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
$OutputDir = Join-Path $ProjectRoot "dist"
$PackageName = "cloudtolocalllm-$Version-x86_64"
$PackageDir = Join-Path $OutputDir $PackageName

Write-Host "CloudToLocalLLM Unified AUR Binary Package Creator (PowerShell)" -ForegroundColor Blue
Write-Host "================================================================" -ForegroundColor Blue
Write-Host "Version: $Version"
Write-Host "Output: $OutputDir\$PackageName.tar.gz"
Write-Host ""

# Check prerequisites
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking prerequisites..."

    # Install build dependencies
    $requiredPackages = @('flutter', 'git')
    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies"
        exit 1
    }

    # Check WSL and Arch Linux for makepkg
    if (-not $UseWSL) {
        $UseWSL = $true
        Write-LogInfo "WSL required for AUR package creation, enabling WSL mode"
    }

    if (-not $WSLDistro) {
        $WSLDistro = Find-WSLDistribution -Purpose 'Arch'
        if (-not $WSLDistro) {
            Write-LogError "Arch Linux WSL distribution not found. AUR package creation requires Arch Linux with makepkg."
            Write-LogError "Install Arch Linux WSL: wsl --install -d ArchLinux"
            exit 1
        }
    }

    # Verify makepkg is available in WSL
    if (-not (Test-WSLCommand -DistroName $WSLDistro -CommandName "makepkg")) {
        Write-LogError "makepkg not found in WSL distribution: $WSLDistro"
        Write-LogError "Install base-devel: sudo pacman -S base-devel"
        exit 1
    }

    Write-LogSuccess "Prerequisites check passed"
}

# Build unified Flutter application
function Build-FlutterApp {
    [CmdletBinding()]
    param()

    if ($SkipBuild) {
        Write-LogInfo "Skipping Flutter build as requested"
        return
    }

    Write-LogInfo "Building unified Flutter application..."

    Set-Location $ProjectRoot

    Write-LogInfo "Running flutter pub get..."
    $result = & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "Failed to get dependencies for Flutter app"
        exit 1
    }

    Write-LogInfo "Running flutter build linux --release..."
    $result = & flutter build linux --release
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "Failed to build Flutter app"
        exit 1
    }

    $executablePath = Join-Path $BuildDir "cloudtolocalllm"
    if (-not (Test-Path $executablePath)) {
        Write-LogError "Flutter app executable not found after build"
        exit 1
    }

    Write-LogSuccess "Unified Flutter application built successfully"
}

# Create package structure
function New-PackageStructure {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating package structure..."
    
    # Clean and create package directory
    if (Test-Path $PackageDir) {
        Remove-Item $PackageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    
    Write-LogSuccess "Package structure created"
}

# Copy unified Flutter application
function Copy-FlutterApp {
    [CmdletBinding()]
    param()

    Write-LogInfo "Copying unified Flutter application..."

    # Copy Flutter application with complete bundle structure
    $bundlePath = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
    if (Test-Path $bundlePath) {
        Write-LogInfo "Copying Flutter application bundle..."
        Copy-Item "$bundlePath\*" -Destination $PackageDir -Recurse -Force
        
        # Make executable (will be handled in WSL)
        $libCount = (Get-ChildItem (Join-Path $bundlePath "lib") -File).Count
        Write-LogInfo "Application libraries: $libCount files"
    }
    else {
        Write-LogError "Flutter build bundle not found"
        exit 1
    }

    # Verify essential files and libraries
    $executablePath = Join-Path $PackageDir "cloudtolocalllm"
    if (-not (Test-Path $executablePath)) {
        Write-LogError "Failed to copy main executable"
        exit 1
    }

    # Verify required Flutter plugin libraries
    $requiredLibs = @("libwindow_manager_plugin.so", "libflutter_secure_storage_linux_plugin.so", "liburl_launcher_linux_plugin.so", "libtray_manager_plugin.so")
    $libDir = Join-Path $PackageDir "lib"
    
    foreach ($lib in $requiredLibs) {
        $libPath = Join-Path $libDir $lib
        if (-not (Test-Path $libPath)) {
            Write-LogWarning "Optional library missing: $lib (may not be required for all features)"
        }
        else {
            Write-LogInfo "✅ Required library present: $lib"
        }
    }

    # Verify AOT data (libapp.so) is present
    $aotPath = Join-Path $libDir "libapp.so"
    if (Test-Path $aotPath) {
        Write-LogInfo "✅ AOT data present: libapp.so"
    }
    else {
        Write-LogError "AOT data missing: libapp.so"
        exit 1
    }

    $totalLibs = (Get-ChildItem $libDir -File).Count
    Write-LogInfo "Total libraries: $totalLibs files"
    Write-LogSuccess "Unified Flutter application copied successfully with proper bundle structure"
}

# Add metadata and documentation
function Add-Metadata {
    [CmdletBinding()]
    param()

    Write-LogInfo "Adding package metadata..."
    
    # Create package info file
    $packageInfo = @"
CloudToLocalLLM v$Version
========================

Package Type: Unified Binary Package for AUR
Architecture: x86_64
Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Contents:
- Unified Flutter application (cloudtolocalllm)
- Integrated system tray functionality using tray_manager
- Integrated tunnel manager for connection brokering
- All required libraries and data files
- Single executable with no Python dependencies

Installation:
This package is designed for AUR (Arch User Repository) installation.
Use: yay -S cloudtolocalllm

Security Features:
- Docker containers run as non-root users
- Enhanced permission handling
- Secure authentication flow

For more information, visit:
https://github.com/imrightguy/CloudToLocalLLM
"@
    
    $packageInfoPath = Join-Path $PackageDir "PACKAGE_INFO.txt"
    Set-Content -Path $packageInfoPath -Value $packageInfo -Encoding UTF8
    
    # Add version file for runtime detection
    $versionPath = Join-Path $PackageDir "VERSION"
    Set-Content -Path $versionPath -Value $Version -Encoding UTF8
    
    Write-LogSuccess "Metadata added"
}

# Create archive using WSL
function New-Archive {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating compressed archive..."

    $wslOutputDir = Convert-WindowsPathToWSL -WindowsPath $OutputDir
    $wslPackageName = $PackageName

    # Create tar.gz archive using WSL
    $tarCommand = "cd `"$wslOutputDir`" && tar -czf `"$wslPackageName.tar.gz`" `"$wslPackageName/`""

    try {
        Invoke-WSLCommand -DistroName $WSLDistro -Command $tarCommand
    }
    catch {
        Write-LogError "Failed to create archive: $($_.Exception.Message)"
        exit 1
    }

    $archivePath = Join-Path $OutputDir "$PackageName.tar.gz"
    if (-not (Test-Path $archivePath)) {
        Write-LogError "Failed to create archive"
        exit 1
    }

    # Get archive size
    $archiveSize = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
    Write-LogSuccess "Archive created: $PackageName.tar.gz ($archiveSize MB)"
}

# Generate checksums using WSL
function New-Checksums {
    [CmdletBinding()]
    param()

    Write-LogInfo "Generating checksums..."

    $wslOutputDir = Convert-WindowsPathToWSL -WindowsPath $OutputDir
    $wslPackageName = $PackageName

    # Generate SHA256 checksum using WSL
    $checksumCommand = "cd `"$wslOutputDir`" && sha256sum `"$wslPackageName.tar.gz`" > `"$wslPackageName.tar.gz.sha256`""

    try {
        Invoke-WSLCommand -DistroName $WSLDistro -Command $checksumCommand
    }
    catch {
        Write-LogError "Failed to generate checksum: $($_.Exception.Message)"
        exit 1
    }

    # Read checksum
    $checksumPath = Join-Path $OutputDir "$PackageName.tar.gz.sha256"
    $checksumContent = Get-Content $checksumPath -Raw
    $checksum = ($checksumContent -split '\s+')[0]

    Write-LogSuccess "SHA256: $checksum"

    # Create checksum info for AUR PKGBUILD
    $aurInfo = @"
# AUR PKGBUILD Information for CloudToLocalLLM v$Version
# Static Distribution Configuration

# Update these values in aur-package/PKGBUILD:
pkgver=$Version
sha256sums=('SKIP' '$checksum')

# Static download URL:
source=(
    "https://github.com/imrightguy/CloudToLocalLLM/archive/v`$pkgver.tar.gz"
    "https://cloudtolocalllm.online/cloudtolocalllm-`${pkgver}-x86_64.tar.gz"
)

# Deployment workflow for static distribution:
# 1. Upload cloudtolocalllm-$Version-x86_64.tar.gz to https://cloudtolocalllm.online/
# 2. Update aur-package/PKGBUILD with new version and checksum (AUTOMATED)
# 3. Test AUR package build locally
# 4. Submit updated PKGBUILD to AUR
# 5. Deploy web app to VPS

# Note: PKGBUILD and .SRCINFO are automatically updated by this script
"@

    $aurInfoPath = Join-Path $OutputDir "$PackageName-aur-info.txt"
    Set-Content -Path $aurInfoPath -Value $aurInfo -Encoding UTF8

    Write-LogSuccess "Checksums and AUR info generated"
}

# Update AUR PKGBUILD and .SRCINFO files using WSL
function Update-AURPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Updating AUR PKGBUILD and .SRCINFO files..."

    # Read checksum
    $checksumPath = Join-Path $OutputDir "$PackageName.tar.gz.sha256"
    $checksumContent = Get-Content $checksumPath -Raw
    $checksum = ($checksumContent -split '\s+')[0]

    $aurDir = Join-Path $ProjectRoot "aur-package"

    if (-not (Test-Path $aurDir)) {
        Write-LogError "AUR package directory not found: $aurDir"
        exit 1
    }

    $pkgbuildPath = Join-Path $aurDir "PKGBUILD"
    if (-not (Test-Path $pkgbuildPath)) {
        Write-LogError "PKGBUILD not found: $pkgbuildPath"
        exit 1
    }

    Write-LogInfo "Updating PKGBUILD version to $Version..."

    # Convert paths for WSL
    $wslAurDir = Convert-WindowsPathToWSL -WindowsPath $aurDir

    # Update pkgver in PKGBUILD using WSL
    $updateVersionCommand = "cd `"$wslAurDir`" && sed -i 's/^pkgver=.*/pkgver=$Version/' PKGBUILD"
    Invoke-WSLCommand -DistroName $WSLDistro -Command $updateVersionCommand

    Write-LogInfo "Updating PKGBUILD SHA256 checksum..."

    # Update SHA256 checksum in PKGBUILD using WSL
    $updateChecksumCommand = @"
cd "$wslAurDir" && sed -i "/sha256sums=(/,/)/ {
    s/'[a-f0-9]\{64\}'/'$checksum'/g
    s/# cloudtolocalllm-[0-9.]*-x86_64\.tar\.gz/# cloudtolocalllm-$Version-x86_64.tar.gz/g
}" PKGBUILD
"@
    Invoke-WSLCommand -DistroName $WSLDistro -Command $updateChecksumCommand

    Write-LogInfo "Regenerating .SRCINFO..."

    # Regenerate .SRCINFO using WSL
    $srcInfoCommand = "cd `"$wslAurDir`" && makepkg --printsrcinfo > .SRCINFO"
    try {
        Invoke-WSLCommand -DistroName $WSLDistro -Command $srcInfoCommand
    }
    catch {
        Write-LogError "Failed to regenerate .SRCINFO: $($_.Exception.Message)"
        exit 1
    }

    Write-LogInfo "Validating updated checksums..."

    # Verify the checksum was updated correctly using WSL
    $validateCommand = "cd `"$wslAurDir`" && grep -A1 'sha256sums=(' PKGBUILD | grep -o `"'[a-f0-9]\{64\}'`" | tr -d `"'`""
    $pkgbuildChecksum = Invoke-WSLCommand -DistroName $WSLDistro -Command $validateCommand -PassThru

    if ($pkgbuildChecksum.Trim() -ne $checksum) {
        Write-LogError "Checksum validation failed. PKGBUILD: $($pkgbuildChecksum.Trim()), Expected: $checksum"
        exit 1
    }

    Write-LogSuccess "AUR PKGBUILD and .SRCINFO updated successfully"
    Write-LogInfo "Version: $Version"
    Write-LogInfo "SHA256: $checksum"
}

# Test package integrity
function Test-Package {
    [CmdletBinding()]
    param()

    if ($SkipTests) {
        Write-LogInfo "Skipping package integrity tests as requested"
        return
    }

    Write-LogInfo "Testing package integrity..."

    $testDir = Join-Path $OutputDir "test_$PackageName"

    # Clean test directory
    if (Test-Path $testDir) {
        Remove-Item $testDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    # Extract and test using WSL
    $wslOutputDir = Convert-WindowsPathToWSL -WindowsPath $OutputDir
    $wslTestDir = Convert-WindowsPathToWSL -WindowsPath $testDir
    $extractCommand = "cd `"$wslOutputDir`" && tar -xzf `"$PackageName.tar.gz`" -C `"$wslTestDir`""

    try {
        Invoke-WSLCommand -DistroName $WSLDistro -Command $extractCommand
    }
    catch {
        Write-LogError "Failed to extract package for testing: $($_.Exception.Message)"
        exit 1
    }

    $testExecutable = Join-Path $testDir "$PackageName\cloudtolocalllm"
    if (Test-Path $testExecutable) {
        Write-LogSuccess "Package integrity test passed"
    }
    else {
        Write-LogError "Package integrity test failed"
        exit 1
    }

    # Cleanup test directory
    Remove-Item $testDir -Recurse -Force
}

# Display package information
function Show-PackageInfo {
    [CmdletBinding()]
    param()

    $archivePath = Join-Path $OutputDir "$PackageName.tar.gz"
    $checksumPath = Join-Path $OutputDir "$PackageName.tar.gz.sha256"

    $archiveSize = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
    $checksumContent = Get-Content $checksumPath -Raw
    $checksum = ($checksumContent -split '\s+')[0]

    Write-Host ""
    Write-Host "📦 Package Information" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    Write-Host "Package: $PackageName.tar.gz"
    Write-Host "Size: $archiveSize MB"
    Write-Host "SHA256: $checksum"
    Write-Host ""
    Write-Host "📁 Files created:" -ForegroundColor Blue
    Write-Host "  • $OutputDir\$PackageName.tar.gz"
    Write-Host "  • $OutputDir\$PackageName.tar.gz.sha256"
    Write-Host "  • $OutputDir\$PackageName-aur-info.txt"
    Write-Host ""
    Write-Host "📋 Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Test AUR package build locally: cd aur-package; makepkg -si"
    Write-Host "  2. Commit updated PKGBUILD and .SRCINFO to git"
    Write-Host "  3. Submit updated PKGBUILD to AUR repository"
    Write-Host "  4. Deploy to VPS: scripts\deploy\complete_automated_deployment.sh"
    Write-Host ""
    Write-Host "✅ AUR PKGBUILD automatically updated with:" -ForegroundColor Green
    Write-Host "  • Version: $Version"
    Write-Host "  • SHA256: $checksum"
}

# Cleanup temporary files
function Remove-TemporaryFiles {
    [CmdletBinding()]
    param()

    Write-LogInfo "Cleaning up temporary files..."

    if (Test-Path $PackageDir) {
        Remove-Item $PackageDir -Recurse -Force
    }

    Write-LogSuccess "Cleanup completed"
}

# Main execution function
function Invoke-Main {
    [CmdletBinding()]
    param()

    Test-Prerequisites
    Build-FlutterApp
    New-PackageStructure
    Copy-FlutterApp
    Add-Metadata
    New-Archive
    New-Checksums
    Update-AURPackage
    Test-Package
    Show-PackageInfo
    Remove-TemporaryFiles

    Write-Host ""
    Write-LogSuccess "🎉 Unified AUR binary package created successfully!"
    Write-Host "📦 Ready for GitHub release and AUR deployment" -ForegroundColor Green
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
