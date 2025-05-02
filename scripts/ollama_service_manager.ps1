# Ollama Service Manager
# This script provides functions to manage the Ollama Windows service

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('start', 'stop', 'restart', 'status')]
    [string]$Action
)

Write-Host "CloudToLocalLLM - Ollama Service Manager" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Check if running as administrator for actions that require it
if ($Action -in @('start', 'stop', 'restart')) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Error: This action requires administrator privileges" -ForegroundColor Red
        Write-Host "Please restart the script with administrative privileges" -ForegroundColor Yellow
        exit 1
    }
}

# Check if Ollama service exists
$serviceExists = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue
if (-not $serviceExists) {
    Write-Host "Error: Ollama service is not installed" -ForegroundColor Red
    Write-Host "Please run the install_ollama_service.ps1 script first" -ForegroundColor Yellow
    exit 1
}

# Perform the requested action
switch ($Action) {
    'start' {
        Write-Host "Starting Ollama service..." -ForegroundColor Yellow
        Start-Service -Name "Ollama"
        Start-Sleep -Seconds 3
        
        # Check if service started successfully
        $service = Get-Service -Name "Ollama"
        if ($service.Status -eq "Running") {
            Write-Host "Ollama service started successfully" -ForegroundColor Green
        } else {
            Write-Host "Error: Failed to start Ollama service" -ForegroundColor Red
            Write-Host "Current status: $($service.Status)" -ForegroundColor Yellow
        }
    }
    
    'stop' {
        Write-Host "Stopping Ollama service..." -ForegroundColor Yellow
        Stop-Service -Name "Ollama" -Force
        Start-Sleep -Seconds 3
        
        # Check if service stopped successfully
        $service = Get-Service -Name "Ollama"
        if ($service.Status -eq "Stopped") {
            Write-Host "Ollama service stopped successfully" -ForegroundColor Green
        } else {
            Write-Host "Error: Failed to stop Ollama service" -ForegroundColor Red
            Write-Host "Current status: $($service.Status)" -ForegroundColor Yellow
        }
    }
    
    'restart' {
        Write-Host "Restarting Ollama service..." -ForegroundColor Yellow
        Restart-Service -Name "Ollama" -Force
        Start-Sleep -Seconds 3
        
        # Check if service restarted successfully
        $service = Get-Service -Name "Ollama"
        if ($service.Status -eq "Running") {
            Write-Host "Ollama service restarted successfully" -ForegroundColor Green
        } else {
            Write-Host "Error: Failed to restart Ollama service" -ForegroundColor Red
            Write-Host "Current status: $($service.Status)" -ForegroundColor Yellow
        }
    }
    
    'status' {
        $service = Get-Service -Name "Ollama"
        $statusColor = if ($service.Status -eq "Running") { "Green" } else { "Yellow" }
        
        Write-Host "Ollama Service Status:" -ForegroundColor Cyan
        Write-Host "--------------------" -ForegroundColor Cyan
        Write-Host "Service Name: Ollama" -ForegroundColor White
        Write-Host "Display Name: $($service.DisplayName)" -ForegroundColor White
        Write-Host "Status: $($service.Status)" -ForegroundColor $statusColor
        Write-Host "Service Type: $($service.ServiceType)" -ForegroundColor White
        Write-Host "Start Type: $($service.StartType)" -ForegroundColor White
        
        # Try to get the port from the registry or service configuration
        try {
            $servicePath = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Ollama" -ErrorAction SilentlyContinue
            if ($servicePath) {
                Write-Host "Binary Path: $($servicePath.ImagePath)" -ForegroundColor White
            }
        } catch {
            # Registry key not found
        }
        
        # Check if we can connect to the API
        if ($service.Status -eq "Running") {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:11434/api/version" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    Write-Host "API Status: Accessible (Port 11434)" -ForegroundColor Green
                    Write-Host "API Version: $($response.Content)" -ForegroundColor White
                } else {
                    Write-Host "API Status: Not accessible (Port 11434)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "API Status: Not accessible (Port 11434)" -ForegroundColor Yellow
            }
        }
    }
}

exit 0 