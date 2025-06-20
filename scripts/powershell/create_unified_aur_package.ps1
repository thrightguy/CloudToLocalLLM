# CloudToLocalLLM Unified AUR Binary Package Creator (PowerShell)
# Creates a binary package from the unified Flutter build output with WSL integration

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$TestOnly,
    [string]$WSLDistro,
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
$BuildDir = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
$OutputDir = Join-Path $ProjectRoot "dist"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
$Version = & $versionManagerPath get-semantic
$PackageName = "cloudtolocalllm-$Version-x86_64"
$PackageDir = Join-Path $OutputDir $PackageName

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Unified AUR Binary Package Creator (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\create_unified_aur_package.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -SkipBuild            Skip Flutter build step"
    Write-Host "  -TestOnly             Only test package integrity"
    Write-Host "  -WSLDistro            Specify WSL distribution to use"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - WSL with Arch Linux distribution for makepkg"
    Write-Host "  - Flutter SDK for building"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\create_unified_aur_package.ps1"
    Write-Host "  .\create_unified_aur_package.ps1 -WSLDistro ArchLinux"
    Write-Host "  .\create_unified_aur_package.ps1 -SkipBuild -TestOnly"
    exit 0
}

# Check prerequisites
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking prerequisites..."

    # Install build dependencies
    $requiredPackages = @('git')
    if (-not $SkipBuild) {
        $requiredPackages += 'flutter'
    }

    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies"
        exit 1
    }

    # Check WSL availability
    if (-not (Test-WSLAvailable)) {
        Write-LogError "WSL is not available on this system"
        Write-LogInfo "Install WSL: https://docs.microsoft.com/en-us/windows/wsl/install"
        exit 1
    }

    # Find suitable WSL distribution
    $script:ArchDistro = $WSLDistro
    if (-not $script:ArchDistro) {
        $script:ArchDistro = Find-WSLDistribution -Purpose 'Arch'
        if (-not $script:ArchDistro) {
            Write-LogError "No Arch Linux WSL distribution found"
            Write-LogInfo "Install Arch Linux WSL distribution for AUR package creation"
            Write-LogInfo "Available distributions:"
            Get-WSLDistributions | ForEach-Object { Write-LogInfo "  - $($_.Name) ($($_.State))" }
            exit 1
        }
    }

    Write-LogInfo "Using WSL distribution: $script:ArchDistro"

    # Check required tools in WSL
    $requiredTools = @('makepkg', 'tar', 'gzip', 'sha256sum')
    foreach ($tool in $requiredTools) {
        if (-not (Test-WSLCommand -DistroName $script:ArchDistro -CommandName $tool)) {
            Write-LogError "Required tool not found in WSL: $tool"
            Write-LogInfo "Install in WSL: sudo pacman -S base-devel"
            exit 1
        }
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
    
    Write-LogInfo "Building unified Flutter application for Linux..."
    
    Push-Location $ProjectRoot
    try {
        # Get dependencies
        Write-LogInfo "Running flutter pub get..."
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get dependencies for Flutter app"
        }
        
        # Build for Linux
        Write-LogInfo "Running flutter build linux --release..."
        flutter build linux --release
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Flutter app"
        }
        
        # Verify build output
        $mainExecutable = Join-Path $BuildDir "cloudtolocalllm"
        if (-not (Test-Path $mainExecutable)) {
            throw "Flutter app executable not found after build"
        }
        
        Write-LogSuccess "Unified Flutter application built successfully"
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
    
    # Clean and create package directory
    if (Test-Path $PackageDir) {
        Remove-Item $PackageDir -Recurse -Force
    }
    New-DirectoryIfNotExists -Path $PackageDir
    New-DirectoryIfNotExists -Path $OutputDir
    
    Write-LogSuccess "Package structure created"
}

# Copy unified Flutter application
function Copy-FlutterApp {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Copying unified Flutter application..."
    
    # Copy Flutter application with complete bundle structure
    if (Test-Path $BuildDir) {
        Write-LogInfo "Copying Flutter application bundle..."
        Copy-Item "$BuildDir\*" $PackageDir -Recurse -Force
        
        # Verify essential files
        $mainExecutable = Join-Path $PackageDir "cloudtolocalllm"
        if (-not (Test-Path $mainExecutable)) {
            Write-LogError "Failed to copy main executable"
            exit 1
        }
        
        # Check for required libraries
        $libDir = Join-Path $PackageDir "lib"
        if (Test-Path $libDir) {
            $libCount = (Get-ChildItem $libDir).Count
            Write-LogInfo "Application libraries: $libCount files"
        }
        
        # Verify AOT data
        $aotLib = Join-Path $PackageDir "lib\libapp.so"
        if (Test-Path $aotLib) {
            Write-LogInfo "✅ AOT data present: libapp.so"
        }
        else {
            Write-LogError "AOT data missing: libapp.so"
            exit 1
        }
        
        Write-LogSuccess "Unified Flutter application copied successfully"
    }
    else {
        Write-LogError "Flutter build bundle not found at $BuildDir"
        exit 1
    }
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
"@ | Set-Content -Path $packageInfo -Encoding UTF8
    
    # Add version file for runtime detection
    $Version | Set-Content -Path (Join-Path $PackageDir "VERSION") -Encoding UTF8
    
    Write-LogSuccess "Metadata added"
}

# Create archive using WSL
function New-Archive {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Creating compressed archive using WSL..."

    $wslPackageName = $PackageName
    
    try {
        Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $OutputDir -Command "tar -czf `"$wslPackageName.tar.gz`" `"$wslPackageName/`""
        
        $archivePath = Join-Path $OutputDir "$PackageName.tar.gz"
        if (-not (Test-Path $archivePath)) {
            throw "Failed to create archive"
        }
        
        # Get archive size
        $size = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
        Write-LogSuccess "Archive created: $PackageName.tar.gz ($size MB)"
    }
    catch {
        Write-LogError "Failed to create archive: $($_.Exception.Message)"
        exit 1
    }
}

# Generate checksums using WSL
function New-Checksums {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Generating checksums using WSL..."

    $archiveFile = "$PackageName.tar.gz"
    
    try {
        # Generate SHA256 checksum
        $checksumOutput = Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $OutputDir -Command "sha256sum `"$archiveFile`"" -PassThru
        $checksum = ($checksumOutput -split '\s+')[0]
        
        # Save checksum file
        $checksumFile = Join-Path $OutputDir "$PackageName.tar.gz.sha256"
        $checksumOutput | Set-Content -Path $checksumFile -Encoding UTF8
        
        Write-LogSuccess "SHA256: $checksum"
        
        # Create AUR info file
        $aurInfoFile = Join-Path $OutputDir "$PackageName-aur-info.txt"
        @"
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
"@ | Set-Content -Path $aurInfoFile -Encoding UTF8
        
        Write-LogSuccess "Checksums and AUR info generated"
        return $checksum
    }
    catch {
        Write-LogError "Failed to generate checksums: $($_.Exception.Message)"
        exit 1
    }
}

# Update AUR PKGBUILD and .SRCINFO files using WSL
function Update-AurPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Checksum
    )

    Write-LogInfo "Updating AUR PKGBUILD and .SRCINFO files using WSL..."

    $aurDir = Join-Path $ProjectRoot "aur-package"
    $pkgbuildFile = Join-Path $aurDir "PKGBUILD"

    if (-not (Test-Path $aurDir)) {
        Write-LogError "AUR package directory not found: $aurDir"
        exit 1
    }

    if (-not (Test-Path $pkgbuildFile)) {
        Write-LogError "PKGBUILD not found: $pkgbuildFile"
        exit 1
    }

    try {
        Write-LogInfo "Updating PKGBUILD version to $Version..."
        # Update pkgver in PKGBUILD
        $pkgbuildContent = Get-Content $pkgbuildFile
        $updatedContent = $pkgbuildContent | ForEach-Object {
            if ($_ -match '^pkgver=') {
                "pkgver=$Version"
            }
            else {
                $_
            }
        }
        Set-Content -Path $pkgbuildFile -Value $updatedContent -Encoding UTF8

        Write-LogInfo "Updating PKGBUILD SHA256 checksum..."
        # Update SHA256 checksum in PKGBUILD
        $pkgbuildContent = Get-Content $pkgbuildFile
        $inSha256Section = $false
        $updatedContent = $pkgbuildContent | ForEach-Object {
            if ($_ -match '^sha256sums=\(') {
                $inSha256Section = $true
                $_
            }
            elseif ($inSha256Section -and $_ -match '^\s*\)') {
                $inSha256Section = $false
                $_
            }
            elseif ($inSha256Section -and $_ -match "'[a-f0-9]{64}'") {
                $_ -replace "'[a-f0-9]{64}'", "'$Checksum'"
            }
            else {
                $_
            }
        }
        Set-Content -Path $pkgbuildFile -Value $updatedContent -Encoding UTF8

        Write-LogInfo "Regenerating .SRCINFO using WSL..."
        # Change to AUR directory and regenerate .SRCINFO using WSL
        Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $aurDir -Command "makepkg --printsrcinfo > .SRCINFO"

        Write-LogInfo "Validating updated checksums..."
        # Verify the checksum was updated correctly
        $pkgbuildContent = Get-Content $pkgbuildFile -Raw
        if ($pkgbuildContent -match "'([a-f0-9]{64})'") {
            $pkgbuildChecksum = $matches[1]
            if ($pkgbuildChecksum -ne $Checksum) {
                Write-LogError "Checksum validation failed. PKGBUILD: $pkgbuildChecksum, Expected: $Checksum"
                exit 1
            }
        }

        Write-LogSuccess "AUR PKGBUILD and .SRCINFO updated successfully"
        Write-LogInfo "Version: $Version"
        Write-LogInfo "SHA256: $Checksum"
    }
    catch {
        Write-LogError "Failed to update AUR package: $($_.Exception.Message)"
        exit 1
    }
}

# Test package integrity
function Test-PackageIntegrity {
    [CmdletBinding()]
    param()

    Write-LogInfo "Testing package integrity..."

    $testDir = Join-Path $OutputDir "test_$PackageName"

    try {
        # Clean test directory
        if (Test-Path $testDir) {
            Remove-Item $testDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $testDir | Out-Null

        # Extract and test using WSL
        $wslTestDir = Convert-WindowsPathToWSL -WindowsPath $testDir
        Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $OutputDir -Command "tar -xzf `"$PackageName.tar.gz`" -C `"$wslTestDir`""

        $extractedExecutable = Join-Path $testDir "$PackageName\cloudtolocalllm"
        if (Test-Path $extractedExecutable) {
            Write-LogSuccess "Package integrity test passed"
        }
        else {
            Write-LogError "Package integrity test failed - executable not found"
            exit 1
        }

        # Cleanup test directory
        Remove-Item $testDir -Recurse -Force
    }
    catch {
        Write-LogError "Package integrity test failed: $($_.Exception.Message)"
        exit 1
    }
}

# Display package information
function Show-PackageInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Checksum
    )

    $archivePath = Join-Path $OutputDir "$PackageName.tar.gz"
    $size = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)

    Write-Host ""
    Write-Host "[PACKAGE] Package Information" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    Write-Host "Package: $PackageName.tar.gz"
    Write-Host "Size: $size MB"
    Write-Host "SHA256: $Checksum"
    Write-Host ""
    Write-Host "[FILES] Files created:" -ForegroundColor Blue
    Write-Host "  • $OutputDir\$PackageName.tar.gz"
    Write-Host "  • $OutputDir\$PackageName.tar.gz.sha256"
    Write-Host "  • $OutputDir\$PackageName-aur-info.txt"
    Write-Host ""
    Write-Host "[NEXT] Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Test AUR package build locally in WSL: cd aur-package; makepkg -si"
    Write-Host "  2. Commit updated PKGBUILD and .SRCINFO to git"
    Write-Host "  3. Submit updated PKGBUILD to AUR repository"
    Write-Host "  4. Deploy to VPS using deploy_vps.ps1"
    Write-Host ""
    Write-Host "[SUCCESS] AUR PKGBUILD automatically updated with:" -ForegroundColor Green
    Write-Host "  • Version: $Version"
    Write-Host "  • SHA256: $Checksum"
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

# Main execution
function Invoke-Main {
    [CmdletBinding()]
    param()

    Write-Host "CloudToLocalLLM Unified AUR Binary Package Creator (PowerShell)" -ForegroundColor Blue
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host "Version: $Version"
    Write-Host "Output: $OutputDir\$PackageName.tar.gz"
    Write-Host ""

    if ($TestOnly) {
        Test-PackageIntegrity
        return
    }

    Test-Prerequisites
    Build-FlutterApp
    New-PackageStructure
    Copy-FlutterApp
    Add-Metadata
    New-Archive
    $checksum = New-Checksums
    Update-AurPackage -Checksum $checksum
    Test-PackageIntegrity
    Show-PackageInfo -Checksum $checksum
    Remove-TemporaryFiles

    Write-Host ""
    Write-LogSuccess "[SUCCESS] Unified AUR binary package created successfully!"
    Write-Host "[READY] Ready for GitHub release and AUR deployment" -ForegroundColor Green
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
