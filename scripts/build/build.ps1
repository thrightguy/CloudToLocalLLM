# Build script for CloudToLocalLLM
param(
    [switch]$WindowsOnly,
    [switch]$WebOnly,
    [switch]$Release
)

$ErrorActionPreference = "Stop"
$BuildMode = if ($Release) { "Release" } else { "Debug" }

function Write-Step {
    param($Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Build-WindowsApp {
    Write-Step "Building Windows Application"
    
    # Check if Flutter is installed
    if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Error "Flutter is not installed or not in PATH. Please install Flutter first."
        exit 1
    }
    
    # Run Flutter build
    Write-Host "Running Flutter build for Windows ($BuildMode)..."
    flutter clean
    flutter pub get
    
    if ($BuildMode -eq "Release") {
        flutter build windows --release
        $outputPath = "build\windows\x64\runner\Release"
    } else {
        flutter build windows --debug
        $outputPath = "build\windows\x64\runner\Debug"
    }
    
    # Copy Ollama setup script
    Copy-Item "scripts\utils\Setup-Ollama.ps1" -Destination $outputPath
    
    Write-Host "Windows build completed successfully!" -ForegroundColor Green
    Write-Host "Output location: $outputPath"
}

function Build-WebApp {
    Write-Step "Building Web Application"
    
    # Check if Docker is installed
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is not installed or not running. Please install Docker first."
        exit 1
    }
    
    # Build Docker image
    Write-Host "Building Docker image..."
    docker-compose build webapp
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed!"
        exit 1
    }
    
    Write-Host "Web app Docker image built successfully!" -ForegroundColor Green
}

# Main build process
if (!$WindowsOnly -and !$WebOnly) {
    Build-WindowsApp
    Build-WebApp
} elseif ($WindowsOnly) {
    Build-WindowsApp
} elseif ($WebOnly) {
    Build-WebApp
}

Write-Host "`nBuild process completed!" -ForegroundColor Green
