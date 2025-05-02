# Uninstall Ollama Windows Service
# This script removes the Ollama Windows service

Write-Host "CloudToLocalLLM - Ollama Service Uninstaller" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Error: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please restart the script with administrative privileges" -ForegroundColor Yellow
    exit 1
}

# Check if NSSM is available
$nssmPath = "$PSScriptRoot\..\tools\nssm.exe"
if (-not (Test-Path $nssmPath)) {
    Write-Host "Error: NSSM tool not found at $nssmPath" -ForegroundColor Red
    Write-Host "Cannot uninstall service without NSSM" -ForegroundColor Yellow
    exit 1
}

# Check if Ollama service exists
$serviceExists = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue
if (-not $serviceExists) {
    Write-Host "Ollama service does not exist. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Stop the service if it's running
if ($serviceExists.Status -eq "Running") {
    Write-Host "Stopping Ollama service..." -ForegroundColor Yellow
    Stop-Service -Name "Ollama" -Force
    Start-Sleep -Seconds 2
}

# Remove the service
Write-Host "Removing Ollama service..." -ForegroundColor Yellow
& $nssmPath remove Ollama confirm
Start-Sleep -Seconds 2

# Verify service was removed
$serviceExists = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue
if (-not $serviceExists) {
    Write-Host "Ollama service successfully removed" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to remove Ollama service. Please check the Windows Services management console." -ForegroundColor Red
}

Write-Host "Uninstallation complete!" -ForegroundColor Cyan 