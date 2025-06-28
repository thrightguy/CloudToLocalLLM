#Requires -PSEdition Core
# A PowerShell script to build the Debian package for CloudToLocalLLM.
# This script is designed to be run from the project root in a WSL environment with PowerShell Core.

# --- Configuration ---
$ErrorActionPreference = 'Stop'

# --- Helper Functions ---

# Function to check if a command exists in the WSL environment
function Test-CommandExists {
    param ([string]$command)
    $exists = (wsl -- bash -c "command -v $command")
    return $? -and ($null -ne $exists)
}

# Function to get version from pubspec.yaml
function Get-VersionFromPubspec {
    $versionLine = Get-Content -Path './pubspec.yaml' | Select-String -Pattern 'version:'
    return ($versionLine -split ':')[1].Trim()
}

# --- Dependency Checks ---

Write-Host "Checking dependencies..."
$requiredCommands = @("flutter", "dpkg-deb", "lintian")
foreach ($cmd in $requiredCommands) {
    if (-not (Test-CommandExists -command $cmd)) {
        Write-Error "Error: Required command '$cmd' is not installed in your WSL environment."
        Write-Error "Please install it and try again."
        exit 1
    }
}
Write-Host "All dependencies are satisfied."

# --- Build Steps ---

Write-Host "Starting Flutter build for Linux..."
wsl -- flutter build linux --release
Write-Host "Flutter build completed."

# --- Packaging ---

# Variables
$version = Get-VersionFromPubspec
$debVersion = $version.Split('+')[0]
$buildNumber = "1" # Debian revision
$packageName = "cloudtolocalllm_${debVersion}-${buildNumber}_amd64.deb"

# PowerShell does not have a direct equivalent of /tmp, so we use the temp directory in the user's profile.
# We use WSL path translation to ensure the path is correct inside WSL.
$buildDir = "/tmp/cloudtolocalllm-deb-build"
$outputDir = "dist/linux/deb"
$outputPath = "$outputDir/$packageName"

# Clean up previous builds
if (Test-Path -Path $buildDir) {
    wsl -- rm -rf $buildDir
}
wsl -- mkdir -p $buildDir
wsl -- mkdir -p $outputDir

Write-Host "Created build directory: $buildDir"

# Copy debian package structure
wsl -- cp -r packaging/deb/* "$buildDir/"
Write-Host "Copied Debian package structure."

# Create the required directory structure
wsl -- mkdir -p "$buildDir/usr/bin"
wsl -- mkdir -p "$buildDir/usr/lib/cloudtolocalllm"
wsl -- mkdir -p "$buildDir/usr/share/pixmaps"

# Copy the Flutter build artifacts
Write-Host "Copying Flutter build artifacts..."
wsl -- cp build/linux/x64/release/bundle/cloudtolocalllm "$buildDir/usr/lib/cloudtolocalllm/"
wsl -- cp -r build/linux/x64/release/bundle/data "$buildDir/usr/lib/cloudtolocalllm/"
wsl -- cp -r build/linux/x64/release/bundle/lib "$buildDir/usr/lib/cloudtolocalllm/"

# Create a wrapper script in /usr/bin
Write-Host "Creating wrapper script..."
$wrapperScript = @'
#!/bin/bash
# Wrapper script to run the application from the installation directory
cd /usr/lib/cloudtolocalllm
exec ./cloudtolocalllm "$@"
'@
wsl -- bash -c "echo '$wrapperScript' > '$buildDir/usr/bin/cloudtolocalllm'"

# Copy application icon
Write-Host "Copying application icon..."
if (Test-Path -Path "assets/icons/app_icon.png") {
    wsl -- cp assets/icons/app_icon.png "$buildDir/usr/share/pixmaps/cloudtolocalllm.png"
    Write-Host "Found and copied app_icon.png"
} elseif (Test-Path -Path "linux/cloudtolocalllm.png") {
    wsl -- cp linux/cloudtolocalllm.png "$buildDir/usr/share/pixmaps/cloudtolocalllm.png"
    Write-Host "Found and copied linux/cloudtolocalllm.png"
} else {
    Write-Warning "No application icon found."
}

# Update the control file
Write-Host "Updating DEBIAN/control file..."
$installedSize = (wsl -- du -sk "$buildDir" | awk '{print $1}')
wsl -- sed -i "s/^Version: .*/Version: $debVersion/" "$buildDir/DEBIAN/control"
wsl -- sed -i "s/^Installed-Size: .*/Installed-Size: $installedSize/" "$buildDir/DEBIAN/control"
Write-Host "Updated version to $debVersion and installed size to $installedSize KB."

# Set correct permissions
Write-Host "Setting file permissions..."
wsl -- chmod 755 "$buildDir/DEBIAN/postinst" "$buildDir/DEBIAN/postrm" "$buildDir/usr/bin/cloudtolocalllm" "$buildDir/usr/lib/cloudtolocalllm/cloudtolocalllm"
wsl -- find "$buildDir/usr/lib/cloudtolocalllm" -type d -exec chmod 755 {} +
wsl -- find "$buildDir/usr/lib/cloudtolocalllm" -type f -exec chmod 644 {} +
wsl -- chmod +x "$buildDir/usr/bin/cloudtolocalllm" "$buildDir/usr/lib/cloudtolocalllm/cloudtolocalllm"
Write-Host "Permissions set."

# Build the DEB package
Write-Host "Building the Debian package..."
wsl -- dpkg-deb --build "$buildDir" "$outputPath"

# --- Verification ---
if (Test-Path -Path $outputPath) {
    $fileSize = (Get-Item $outputPath).Length / 1KB
    Write-Host "--------------------------------------------------"
    Write-Host "DEB package created successfully!" -ForegroundColor Green
    Write-Host "  Name: $packageName"
    Write-Host "  Size: $($fileSize.ToString('F1')) KB"
    Write-Host "  Location: $outputPath"
    Write-Host "--------------------------------------------------"

    # Run lintian for package validation
    Write-Host "Running lintian validation..."
    $lintianResult = wsl -- lintian "$outputPath"
    if ($lintianResult) {
        Write-Warning "Lintian validation finished. Please review the output above for any warnings or errors."
        Write-Host $lintianResult
    } else {
        Write-Host "Lintian validation passed with no errors or warnings." -ForegroundColor Green
    }
} else {
    Write-Error "Failed to create DEB package."
    exit 1
}

# --- Cleanup ---
wsl -- rm -rf $buildDir
Write-Host "Build script finished. Temporary build directory removed."
