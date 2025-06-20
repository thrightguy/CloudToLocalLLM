# CloudToLocalLLM Debian Package Build Script (PowerShell)
# Creates .deb packages for Ubuntu, Debian, and derivatives with WSL integration

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$UseDocker,
    [string]$WSLDistro,
    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck,
    [switch]$Help
)

# Import utilities
$utilsPath = Join-Path $PSScriptRoot "utils.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
}
else {
    Write-Error "Utils module not found at $utilsPath"
    exit 1
}

# Script configuration
$ProjectRoot = Get-ProjectRoot
$BuildDir = Join-Path $ProjectRoot "build\debian"
$DistDir = Join-Path $ProjectRoot "dist\debian"
$DockerDir = Join-Path $ProjectRoot "docker\debian-builder"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
$Version = & $versionManagerPath get-semantic

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Debian Package Build Script (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\build_deb.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -SkipBuild            Skip Flutter build step"
    Write-Host "  -UseDocker            Use Docker for building (requires Docker Desktop)"
    Write-Host "  -WSLDistro            Specify WSL distribution to use"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - WSL with Ubuntu/Debian distribution for dpkg-deb"
    Write-Host "  - OR Docker Desktop for containerized building"
    Write-Host "  - Flutter SDK for building"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\build_deb.ps1"
    Write-Host "  .\build_deb.ps1 -UseDocker"
    Write-Host "  .\build_deb.ps1 -WSLDistro Ubuntu-22.04"
    exit 0
}

# Check if Docker is available
function Test-Docker {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Command "docker")) {
        Write-LogError "Docker is required for containerized Debian package building"
        Write-LogInfo "Install Docker Desktop: https://docs.docker.com/desktop/windows/"
        return $false
    }
    
    try {
        docker info | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-LogError "Docker daemon is not running or not accessible"
            Write-LogInfo "Start Docker Desktop or check Docker service"
            return $false
        }
    }
    catch {
        Write-LogError "Docker is not accessible: $($_.Exception.Message)"
        return $false
    }
    
    Write-LogSuccess "Docker is available and running"
    return $true
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
    if ($UseDocker) {
        $requiredPackages += 'docker'
    }

    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies"
        exit 1
    }

    # Check build method
    if ($UseDocker) {
        if (-not (Test-Docker)) {
            exit 1
        }
        $script:BuildMethod = "Docker"
    }
    else {
        # Check WSL availability
        if (-not (Test-WSLAvailable)) {
            Write-LogError "WSL is not available on this system"
            Write-LogInfo "Install WSL: https://docs.microsoft.com/en-us/windows/wsl/install"
            Write-LogInfo "Or use -UseDocker flag for containerized building"
            exit 1
        }

        # Find suitable WSL distribution
        $script:DebianDistro = $WSLDistro
        if (-not $script:DebianDistro) {
            $script:DebianDistro = Find-WSLDistribution -Purpose 'Debian'
            if (-not $script:DebianDistro) {
                Write-LogError "No Ubuntu/Debian WSL distribution found"
                Write-LogInfo "Install Ubuntu WSL distribution for Debian package creation"
                Write-LogInfo "Or use -UseDocker flag for containerized building"
                Write-LogInfo "Available distributions:"
                Get-WSLDistributions | ForEach-Object { Write-LogInfo "  - $($_.Name) ($($_.State))" }
                exit 1
            }
        }

        Write-LogInfo "Using WSL distribution: $script:DebianDistro"

        # Check required tools in WSL
        $requiredTools = @('dpkg-deb', 'fakeroot', 'tar', 'gzip')
        foreach ($tool in $requiredTools) {
            if (-not (Test-WSLCommand -DistroName $script:DebianDistro -CommandName $tool)) {
                Write-LogError "Required tool not found in WSL: $tool"
                Write-LogInfo "Install in WSL: sudo apt-get update && sudo apt-get install dpkg-dev fakeroot"
                exit 1
            }
        }

        $script:BuildMethod = "WSL"
    }

    Write-LogSuccess "Prerequisites check passed (using $($script:BuildMethod))"
}

# Create Docker build environment
function New-DockerEnvironment {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Creating Docker build environment..."
    
    New-DirectoryIfNotExists -Path $DockerDir
    
    # Create Dockerfile for Debian builder
    $dockerfileContent = @'
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    dpkg-dev \
    fakeroot \
    lintian \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    pkg-config \
    cmake \
    ninja-build \
    clang \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

# Pre-download Flutter dependencies
RUN flutter doctor
RUN flutter precache --linux

# Create non-root user for building
RUN useradd -m -s /bin/bash builder

# Give builder user ownership of Flutter directory
RUN chown -R builder:builder /opt/flutter

USER builder
WORKDIR /workspace

# Set Flutter path for builder user
ENV PATH="/opt/flutter/bin:${PATH}"

CMD ["/bin/bash"]
'@
    
    $dockerfilePath = Join-Path $DockerDir "Dockerfile"
    Set-Content -Path $dockerfilePath -Value $dockerfileContent -Encoding UTF8
    
    Write-LogSuccess "Docker build environment created"
}

# Build Docker image
function Build-DockerImage {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Building Docker image for Debian packaging..."
    
    Push-Location $DockerDir
    try {
        docker build -t cloudtolocalllm-debian-builder .
        if ($LASTEXITCODE -ne 0) {
            throw "Docker build failed"
        }
    }
    finally {
        Pop-Location
    }
    
    Write-LogSuccess "Docker image built successfully"
}

# Build Flutter application in Docker
function Build-FlutterInDocker {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Building Flutter application in Docker container..."
    
    $dockerCommand = @"
set -e
echo 'Setting up Git safe directories...'
git config --global --add safe.directory /opt/flutter
git config --global --add safe.directory /workspace

echo 'Cleaning previous builds...'
flutter clean

echo 'Getting dependencies...'
flutter pub get

echo 'Building Flutter for Linux...'
flutter build linux --release

echo 'Flutter build completed successfully'
"@
    
    # Run Flutter build in Docker container
    docker run --rm `
        -v "${ProjectRoot}:/workspace" `
        -w /workspace `
        cloudtolocalllm-debian-builder `
        bash -c $dockerCommand
    
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "Flutter build in Docker failed"
        exit 1
    }
    
    $flutterBuildPath = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
    if (-not (Test-Path $flutterBuildPath)) {
        Write-LogError "Flutter build failed - output directory not found"
        exit 1
    }
    
    Write-LogSuccess "Flutter application built in Docker"
}

# Build Flutter application using WSL
function Build-FlutterInWSL {
    [CmdletBinding()]
    param()
    
    if ($SkipBuild) {
        Write-LogInfo "Skipping Flutter build as requested"
        return
    }
    
    Write-LogInfo "Building Flutter application using WSL..."
    
    try {
        # Install Flutter in WSL if needed
        Invoke-WSLCommand -DistroName $script:DebianDistro -Command "which flutter" -PassThru 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-LogInfo "Installing Flutter in WSL..."
            Invoke-WSLCommand -DistroName $script:DebianDistro -Command "
                sudo apt-get update && 
                sudo apt-get install -y curl git unzip xz-utils zip libgtk-3-dev &&
                git clone https://github.com/flutter/flutter.git -b stable /opt/flutter &&
                echo 'export PATH=\"/opt/flutter/bin:\$PATH\"' >> ~/.bashrc
            "
        }
        
        # Build Flutter application
        Invoke-WSLCommand -DistroName $script:DebianDistro -WorkingDirectory $ProjectRoot -Command "
            export PATH=\"/opt/flutter/bin:\$PATH\" &&
            flutter clean &&
            flutter pub get &&
            flutter build linux --release
        "
        
        $flutterBuildPath = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
        if (-not (Test-Path $flutterBuildPath)) {
            throw "Flutter build failed - output directory not found"
        }
        
        Write-LogSuccess "Flutter application built using WSL"
    }
    catch {
        Write-LogError "Failed to build Flutter application in WSL: $($_.Exception.Message)"
        exit 1
    }
}

# Prepare package directory structure
function New-PackageStructure {
    [CmdletBinding()]
    param()

    Write-LogInfo "Preparing package directory structure..."

    $packageDir = Join-Path $BuildDir "package"

    # Clean and create package directory
    if (Test-Path $packageDir) {
        Remove-Item $packageDir -Recurse -Force
    }

    # Create directory structure
    New-DirectoryIfNotExists -Path $packageDir
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\bin")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\applications")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\icons\hicolor\16x16\apps")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\icons\hicolor\32x32\apps")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\icons\hicolor\48x48\apps")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\icons\hicolor\64x64\apps")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\icons\hicolor\128x128\apps")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\doc\cloudtolocalllm")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\licenses\cloudtolocalllm")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "usr\share\man\man1")
    New-DirectoryIfNotExists -Path (Join-Path $packageDir "DEBIAN")

    Write-LogSuccess "Package directory structure created"
    return $packageDir
}

# Copy application files
function Copy-ApplicationFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDir
    )

    Write-LogInfo "Copying application files..."

    $flutterBundle = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
    $targetBinDir = Join-Path $PackageDir "usr\bin"

    # Copy Flutter bundle
    Copy-Item "$flutterBundle\*" $targetBinDir -Recurse -Force

    # Verify main executable
    $mainExecutable = Join-Path $targetBinDir "cloudtolocalllm"
    if (-not (Test-Path $mainExecutable)) {
        Write-LogError "Main executable not found in Flutter build"
        exit 1
    }

    # Copy documentation
    $docDir = Join-Path $PackageDir "usr\share\doc\cloudtolocalllm"
    if (Test-Path (Join-Path $ProjectRoot "README.md")) {
        Copy-Item (Join-Path $ProjectRoot "README.md") $docDir
    }
    if (Test-Path (Join-Path $ProjectRoot "CHANGELOG.md")) {
        Copy-Item (Join-Path $ProjectRoot "CHANGELOG.md") $docDir
    }
    if (Test-Path (Join-Path $ProjectRoot "LICENSE")) {
        Copy-Item (Join-Path $ProjectRoot "LICENSE") (Join-Path $PackageDir "usr\share\licenses\cloudtolocalllm")
    }

    # Create copyright file
    $copyrightContent = @"
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: CloudToLocalLLM
Upstream-Contact: CloudToLocalLLM Team <support@cloudtolocalllm.online>
Source: https://github.com/imrightguy/CloudToLocalLLM

Files: *
Copyright: $(Get-Date -Format yyyy) CloudToLocalLLM Team
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
"@

    $copyrightPath = Join-Path $docDir "copyright"
    Set-Content -Path $copyrightPath -Value $copyrightContent -Encoding UTF8

    Write-LogSuccess "Application files copied"
}

# Copy and generate icons
function Copy-Icons {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDir
    )

    Write-LogInfo "Copying and generating icons..."

    $assetsDir = Join-Path $ProjectRoot "assets\images"
    $iconSizes = @(16, 32, 48, 64, 128)

    foreach ($size in $iconSizes) {
        $sourceIcon = Join-Path $assetsDir "tray_icon_contrast_$size.png"
        $targetDir = Join-Path $PackageDir "usr\share\icons\hicolor\${size}x${size}\apps"
        $targetIcon = Join-Path $targetDir "cloudtolocalllm.png"

        if (Test-Path $sourceIcon) {
            Copy-Item $sourceIcon $targetIcon
        }
        else {
            # Use 32px as fallback
            $fallbackIcon = Join-Path $assetsDir "tray_icon_contrast_32.png"
            if (Test-Path $fallbackIcon) {
                Copy-Item $fallbackIcon $targetIcon
            }
        }
    }

    Write-LogSuccess "Icons copied"
}

# Create desktop file
function New-DesktopFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDir
    )

    Write-LogInfo "Creating desktop file..."

    $desktopContent = @"
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Multi-tenant streaming LLM management with system tray integration
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Type=Application
Categories=Network;Development;
StartupNotify=true
StartupWMClass=cloudtolocalllm
Keywords=LLM;AI;Chat;Ollama;Streaming;Machine Learning;
Version=1.0
Terminal=false
MimeType=application/x-cloudtolocalllm;
"@

    $desktopPath = Join-Path $PackageDir "usr\share\applications\cloudtolocalllm.desktop"
    Set-Content -Path $desktopPath -Value $desktopContent -Encoding UTF8

    Write-LogSuccess "Desktop file created"
}

# Create man page
function New-ManPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDir
    )

    Write-LogInfo "Creating man page..."

    $manContent = @"
.TH CLOUDTOLOCALLLM 1 "$(Get-Date -Format 'MMMM yyyy')" "CloudToLocalLLM $Version" "User Commands"
.SH NAME
cloudtolocalllm \- Multi-tenant streaming LLM management application
.SH SYNOPSIS
.B cloudtolocalllm
[\fIOPTIONS\fR]
.SH DESCRIPTION
CloudToLocalLLM provides secure, scalable multi-tenant streaming for local LLM management with system tray integration.
.PP
The application features a modern ChatGPT-like interface with platform-specific connection logic:
.IP \(bu 2
Web platform: Uses CloudToLocalLLM streaming proxy with authentication
.IP \(bu 2
Desktop platform: Direct connection to localhost Ollama instances
.PP
Key features include multi-tenant streaming proxy architecture, system tray integration with minimize-to-tray, cross-platform support, and secure authentication with user isolation.
.SH OPTIONS
.TP
.B \-h, \-\-help
Display help information and exit.
.TP
.B \-v, \-\-version
Display version information and exit.
.SH FILES
.TP
.I ~/.config/cloudtolocalllm/
User configuration directory
.TP
.I ~/.local/share/cloudtolocalllm/
User data directory
.SH EXAMPLES
.TP
Start CloudToLocalLLM:
.B cloudtolocalllm
.SH BUGS
Report bugs at: https://github.com/imrightguy/CloudToLocalLLM/issues
.SH AUTHOR
CloudToLocalLLM Team <support@cloudtolocalllm.online>
.SH SEE ALSO
.BR ollama (1)
"@

    $manPath = Join-Path $PackageDir "usr\share\man\man1\cloudtolocalllm.1"
    Set-Content -Path $manPath -Value $manContent -Encoding UTF8

    Write-LogSuccess "Man page created"
}

# Create DEBIAN control files
function New-ControlFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDir
    )

    Write-LogInfo "Creating DEBIAN control files..."

    $debianDir = Join-Path $PackageDir "DEBIAN"

    # Calculate installed size
    $installedSize = [math]::Round((Get-ChildItem (Join-Path $PackageDir "usr") -Recurse | Measure-Object -Property Length -Sum).Sum / 1KB)

    # Create control file
    $controlContent = @"
Package: cloudtolocalllm
Version: $Version
Section: net
Priority: optional
Architecture: amd64
Depends: libayatana-appindicator3-1, libgtk-3-0, libc6 (>= 2.31), libgcc-s1 (>= 3.0)
Recommends: ollama
Suggests: firefox | chromium-browser
Installed-Size: $installedSize
Maintainer: CloudToLocalLLM Team <support@cloudtolocalllm.online>
Description: Multi-tenant streaming LLM management application
 CloudToLocalLLM provides secure, scalable multi-tenant streaming
 for local LLM management with system tray integration.
 .
 Features include:
  - Multi-tenant streaming proxy architecture
  - System tray integration with minimize-to-tray
  - Cross-platform support (web and desktop)
  - Secure authentication and user isolation
  - Platform-specific connection logic (web proxy vs direct)
  - Professional "Coming Soon" placeholders for future features
Homepage: https://cloudtolocalllm.online
"@

    Set-Content -Path (Join-Path $debianDir "control") -Value $controlContent -Encoding UTF8

    # Create postinst script
    $postinstContent = @'
#!/bin/bash
set -e

# Update icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi

echo "CloudToLocalLLM installed successfully!"
echo "Start from applications menu or run 'cloudtolocalllm' in terminal"

#DEBHELPER#

exit 0
'@

    Set-Content -Path (Join-Path $debianDir "postinst") -Value $postinstContent -Encoding UTF8

    # Create prerm script
    $prermContent = @'
#!/bin/bash
set -e

echo "Removing CloudToLocalLLM..."

#DEBHELPER#

exit 0
'@

    Set-Content -Path (Join-Path $debianDir "prerm") -Value $prermContent -Encoding UTF8

    # Create postrm script
    $postrmContent = @'
#!/bin/bash
set -e

case "$1" in
    remove|purge)
        # Update icon cache
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
        fi

        # Update desktop database
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database -q /usr/share/applications || true
        fi
        ;;
esac

#DEBHELPER#

exit 0
'@

    Set-Content -Path (Join-Path $debianDir "postrm") -Value $postrmContent -Encoding UTF8

    Write-LogSuccess "DEBIAN control files created"
}

# Build package using WSL or Docker
function Build-Package {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDir
    )

    Write-LogInfo "Building Debian package using $($script:BuildMethod)..."

    $packageName = "cloudtolocalllm_${Version}_amd64.deb"
    $outputPath = Join-Path $DistDir $packageName

    New-DirectoryIfNotExists -Path $DistDir

    if ($script:BuildMethod -eq "Docker") {
        # Build using Docker
        docker run --rm `
            -v "${BuildDir}:/build" `
            -w /build `
            ubuntu:22.04 `
            bash -c "
                apt-get update && apt-get install -y dpkg-dev fakeroot
                fakeroot dpkg-deb --build package $packageName
            "

        $dockerOutputPath = Join-Path $BuildDir $packageName
        if (Test-Path $dockerOutputPath) {
            Move-Item $dockerOutputPath $outputPath
        }
    }
    else {
        # Build using WSL
        Invoke-WSLCommand -DistroName $script:DebianDistro -WorkingDirectory $BuildDir -Command "fakeroot dpkg-deb --build package $packageName"

        $wslOutputPath = Join-Path $BuildDir $packageName
        if (Test-Path $wslOutputPath) {
            Move-Item $wslOutputPath $outputPath
        }
    }

    if (Test-Path $outputPath) {
        Write-LogSuccess "Debian package created: $packageName"
        Write-LogInfo "Package location: $outputPath"

        # Display package info
        $size = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
        Write-Host ""
        Write-Host "📦 Package Information" -ForegroundColor Green
        Write-Host "======================" -ForegroundColor Green
        Write-Host "Package: $packageName"
        Write-Host "Size: $size MB"
        Write-Host "Location: $outputPath"
        Write-Host ""
        Write-Host "Installation:" -ForegroundColor Yellow
        Write-Host "  sudo dpkg -i $outputPath"
        Write-Host "  sudo apt-get install -f  # Fix dependencies if needed"
    }
    else {
        Write-LogError "Debian package creation failed"
        exit 1
    }
}

# Main execution function
function Invoke-Main {
    [CmdletBinding()]
    param()

    Write-Host "CloudToLocalLLM Debian Package Build Script (PowerShell)" -ForegroundColor Blue
    Write-Host "=========================================================" -ForegroundColor Blue
    Write-Host "Version: $Version"
    Write-Host "Build Method: $($script:BuildMethod)"
    Write-Host ""

    Test-Prerequisites

    # Create build directories
    New-DirectoryIfNotExists -Path $BuildDir
    New-DirectoryIfNotExists -Path $DistDir

    # Execute build steps
    if ($script:BuildMethod -eq "Docker") {
        New-DockerEnvironment
        Build-DockerImage
        Build-FlutterInDocker
    }
    else {
        Build-FlutterInWSL
    }

    $packageDir = New-PackageStructure
    Copy-ApplicationFiles -PackageDir $packageDir
    Copy-Icons -PackageDir $packageDir
    New-DesktopFile -PackageDir $packageDir
    New-ManPage -PackageDir $packageDir
    New-ControlFiles -PackageDir $packageDir
    Build-Package -PackageDir $packageDir

    Write-LogSuccess "Debian package build completed successfully!"
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
