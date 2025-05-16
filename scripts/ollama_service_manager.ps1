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
        
        $apiHost = "localhost"
        $apiPort = "11434" # Default port
        $apiUrl = "http://$apiHost:$apiPort/api/version"

        try {
            $serviceParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Ollama\Parameters"
            if (Test-Path $serviceParamsPath) {
                $params = Get-ItemProperty -Path $serviceParamsPath -ErrorAction SilentlyContinue
                if ($params.ImagePath) { # This is from the parent key, but good to show
                     Write-Host "Binary Path: $($params.ImagePath)" -ForegroundColor White
                }
                if ($params.AppDirectory) {
                    Write-Host "Application Directory: $($params.AppDirectory)" -ForegroundColor White
                }
                if ($params.AppEnvironmentExtra) {
                    $envVars = $params.AppEnvironmentExtra
                    foreach ($envVarLine in $envVars) {
                        if ($envVarLine -match "OLLAMA_HOST=(.+)") {
                            $ollamaHostSetting = $matches[1]
                            Write-Host "Configured OLLAMA_HOST: $ollamaHostSetting" -ForegroundColor White
                            $hostParts = $ollamaHostSetting.Split(':')
                            if ($hostParts.Count -eq 2) {
                                $apiHost = $hostParts[0]
                                $apiPort = $hostParts[1]
                                $apiUrl = "http://$apiHost:$apiPort/api/version"
                            } elseif ($hostParts.Count -eq 1) { # Could be just port, host defaults to 0.0.0.0 or 127.0.0.1
                                $apiPort = $hostParts[0]
                                $apiHost = "localhost" # Assume localhost if only port is in OLLAMA_HOST
                                $apiUrl = "http://$apiHost:$apiPort/api/version"
                            }
                            break
                        }
                    }
                }
            } else {
                 # If Parameters subkey doesn't exist, try to get ImagePath from service key directly
                 $servicePath = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Ollama" -ErrorAction SilentlyContinue
                 if ($servicePath.ImagePath) {
                     Write-Host "Binary Path: $($servicePath.ImagePath)" -ForegroundColor White
                 }
            }
        } catch {
            Write-Host "Could not read service parameters from registry: $_" -ForegroundColor Yellow
        }
        
        Write-Host "Attempting to contact API at: $apiUrl" -ForegroundColor Gray

        # Check if we can connect to the API
        if ($service.Status -eq "Running") {
            try {
                $response = Invoke-WebRequest -Uri $apiUrl -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
                if ($response -and $response.StatusCode -eq 200) {
                    Write-Host "API Status: Accessible (Host: $apiHost, Port: $apiPort)" -ForegroundColor Green
                    # Attempt to parse JSON content if it is JSON
                    try {
                        $jsonResponse = $response.Content | ConvertFrom-Json
                        Write-Host "API Version: $($jsonResponse.version)" -ForegroundColor White
                    } catch {
                        Write-Host "API Response (raw): $($response.Content)" -ForegroundColor White
                    }
                } else {
                    Write-Host "API Status: Not accessible (Host: $apiHost, Port: $apiPort)" -ForegroundColor Yellow
                    if ($response) { Write-Host "  Status Code: $($response.StatusCode)" -ForegroundColor Yellow }
                }
            } catch {
                Write-Host "API Status: Not accessible (Host: $apiHost, Port: $apiPort) - Error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

exit 0 