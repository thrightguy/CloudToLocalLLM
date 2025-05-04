# Build Windows App with Admin-Only Installation
# This script builds the Windows version of CloudToLocalLLM with admin-only installation script

# Stop on any error
$ErrorActionPreference = "Stop"

Write-Host "Building CloudToLocalLLM for Windows with Admin-Only Installer..." -ForegroundColor Cyan

# Ensure we have all dependencies
Write-Host "Checking and installing Flutter dependencies..." -ForegroundColor Green
flutter pub get

# Run flutter doctor to check setup
flutter doctor -v

# Build the Windows app
Write-Host "Building Windows application..." -ForegroundColor Green
flutter build windows --release

# Check if build was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Create releases directory if it doesn't exist
New-Item -ItemType Directory -Path "releases" -Force | Out-Null

# Get current timestamp for the release filename
$timestamp = Get-Date -Format "yyyyMMddHHmm"

# Check if InnoSetup is installed
$innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $innoSetupPath) {
    # Build the installer
    Write-Host "Building admin-only installer..." -ForegroundColor Green
    & $innoSetupPath "CloudToLocalLLM_AdminOnly.iss"
    
    # Move the installer to the releases directory with timestamp
    Move-Item -Path "Output\CloudToLocalLLM-Windows-1.3.0-AdminSetup.exe" -Destination "releases\CloudToLocalLLM-Admin-$timestamp.exe" -Force
} else {
    Write-Host "InnoSetup not found. Please install InnoSetup to build the installer." -ForegroundColor Yellow
    Write-Host "Skipping installer creation..." -ForegroundColor Yellow
}

# Create a ZIP release package
Write-Host "Creating ZIP release package..." -ForegroundColor Green
$zipFileName = "CloudToLocalLLM-Windows-Admin-$timestamp.zip"
$sourcePath = "build/windows/x64/runner/Release/*"

# Create the ZIP file
Compress-Archive -Path $sourcePath -DestinationPath "releases/$zipFileName" -Force

Write-Host "Windows build with admin-only installer completed successfully!" -ForegroundColor Green
Write-Host "Release files available at:" -ForegroundColor Cyan
Write-Host " - Admin Installer: releases/CloudToLocalLLM-Admin-$timestamp.exe (if InnoSetup was available)" -ForegroundColor White
Write-Host " - ZIP Package: releases/$zipFileName" -ForegroundColor White

# Add a note to differentiate this installer
Write-Host "NOTE: This installer requires administrator privileges and will install for all users only." -ForegroundColor Yellow
Write-Host "It will not allow installation for the current user only." -ForegroundColor Yellow 