# Build script for CloudToLocalLLM Windows Installer
# This script cleans the release folder and builds the installer

Write-Host "=== CloudToLocalLLM Windows Installer Build Script ==="

# Check if Inno Setup is installed
$innoSetupPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $innoSetupPath)) {
    $innoSetupPath = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $innoSetupPath)) {
        Write-Host "Error: Inno Setup not found. Please install Inno Setup 6 from https://jrsoftware.org/isdl.php" -ForegroundColor Red
        exit 1
    }
}

# Clean release folder
$releasesFolder = Join-Path $PSScriptRoot "releases"
if (Test-Path $releasesFolder) {
    Write-Host "Cleaning releases folder..."
    Get-ChildItem -Path $releasesFolder -File | Remove-Item -Force
} else {
    Write-Host "Creating releases folder..."
    New-Item -Path $releasesFolder -ItemType Directory -Force | Out-Null
}

# Build the installer
Write-Host "Building installer..."
$issFile = Join-Path $PSScriptRoot "CloudToLocalLLM.iss"
& $innoSetupPath $issFile

# Check if build was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Build completed successfully!" -ForegroundColor Green
    
    # List the created installer file
    $installerFiles = Get-ChildItem -Path $releasesFolder -File
    Write-Host "Installer created:"
    foreach ($file in $installerFiles) {
        Write-Host "  $($file.Name) ($([math]::Round($file.Length / 1MB, 2)) MB)" -ForegroundColor Cyan
    }
} else {
    Write-Host "Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}

# Suggestions for future enhancements
Write-Host "`nSuggested future enhancements:" -ForegroundColor Yellow
Write-Host "1. Add support for LM Studio integration" -ForegroundColor Yellow
Write-Host "2. Add automatic updates for Ollama models" -ForegroundColor Yellow
Write-Host "3. Add GPU monitoring and performance optimization" -ForegroundColor Yellow
Write-Host "4. Add backup and restore functionality for models and configurations" -ForegroundColor Yellow
Write-Host "5. Add advanced logging and diagnostics" -ForegroundColor Yellow
Write-Host "6. Add multi-language support for the installer" -ForegroundColor Yellow
Write-Host "7. Add silent installation option for enterprise deployment" -ForegroundColor Yellow