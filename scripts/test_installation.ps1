# CloudToLocalLLM Installation Test Script
# This script performs comprehensive testing of the CloudToLocalLLM installation

# Import logging module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptPath "logging.ps1")

function Test-SystemRequirements {
    Write-Info "Testing system requirements..."
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Debug "PowerShell Version: $psVersion"
    if ($psVersion.Major -lt 5) {
        Write-Error "PowerShell 5.0 or higher is required"
        return $false
    }
    
    # Check available memory
    $memory = Get-CimInstance Win32_OperatingSystem
    $availableMemoryGB = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
    Write-Debug "Available Memory: $availableMemoryGB GB"
    if ($availableMemoryGB -lt 4) {
        Write-Warning "Low memory available: $availableMemoryGB GB (Recommended: 4GB+)"
    }
    
    # Check available disk space
    $drive = Get-PSDrive -Name ($PSScriptRoot.Substring(0,1))
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    Write-Debug "Available Disk Space: $freeSpaceGB GB"
    if ($freeSpaceGB -lt 10) {
        Write-Warning "Low disk space available: $freeSpaceGB GB (Recommended: 10GB+)"
    }
    
    # Check for NVIDIA GPU
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }
    if ($gpu) {
        Write-Info "NVIDIA GPU detected: $($gpu.Name)"
    } else {
        Write-Warning "No NVIDIA GPU detected - GPU acceleration will not be available"
    }
    
    return $true
}

function Test-ServiceInstallation {
    Write-Info "Testing Ollama service installation..."
    
    # Check if NSSM is available
    $nssmPath = Join-Path $PSScriptRoot "..\tools\nssm.exe"
    if (-not (Test-Path $nssmPath)) {
        Write-Error "NSSM not found at: $nssmPath"
        return $false
    }
    Write-Debug "NSSM found at: $nssmPath"
    
    # Check Ollama service
    $service = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Error "Ollama service not installed"
        return $false
    }
    
    Write-Info "Service Status: $($service.Status)"
    Write-Info "Start Type: $($service.StartType)"
    
    return $true
}

function Test-OllamaAPI {
    Write-Info "Testing Ollama API..."

    $apiHost = "localhost"
    $apiPort = "11434" # Default port

    # Try to get the configured port from Ollama service parameters
    try {
        $serviceParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Ollama\Parameters"
        if (Test-Path $serviceParamsPath) {
            $params = Get-ItemProperty -Path $serviceParamsPath -ErrorAction SilentlyContinue
            if ($params.AppEnvironmentExtra) {
                $envVars = $params.AppEnvironmentExtra
                foreach ($envVarLine in $envVars) {
                    if ($envVarLine -match "OLLAMA_HOST=(.+)") {
                        $ollamaHostSetting = $matches[1]
                        Write-Debug "Found OLLAMA_HOST setting: $ollamaHostSetting"
                        $hostParts = $ollamaHostSetting.Split(':')
                        if ($hostParts.Count -eq 2) {
                            $apiHost = $hostParts[0]
                            $apiPort = $hostParts[1]
                        } elseif ($hostParts.Count -eq 1) {
                            $apiPort = $hostParts[0]
                            # Assuming localhost if only port is specified in OLLAMA_HOST
                            $apiHost = "localhost" 
                        }
                        break
                    }
                }
            }
        }
    } catch {
        Write-Warning "Could not read Ollama service parameters from registry to determine API port: $($_.Exception.Message)"
        Write-Info "Proceeding with default API port: $apiPort"
    }
    
    Write-Info "Targeting Ollama API at http://$apiHost:$apiPort"

    $apiEndpointsToTest = @(
        @{
            "Endpoint" = "http://$apiHost:$apiPort/api/version"
            "Method" = "GET"
            "Description" = "Version API"
        },
        @{
            "Endpoint" = "http://$apiHost:$apiPort/api/tags"
            "Method" = "GET"
            "Description" = "Models List API"
        }
    )
    
    $allSuccess = $true
    
    foreach ($api in $apiEndpointsToTest) {
        try {
            $response = Invoke-WebRequest -Uri $api.Endpoint -Method $api.Method -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Info "$($api.Description): OK"
                Write-Debug "Response: $($response.Content)"
            } else {
                Write-Warning "$($api.Description): Unexpected status code $($response.StatusCode)"
                $allSuccess = $false
            }
        } catch {
            Write-Error "$($api.Description): Failed - $_"
            $allSuccess = $false
        }
    }
    
    return $allSuccess
}

function Test-ModelDirectory {
    Write-Info "Testing model directory..."
    
    # Check default model directory
    $modelDir = "$env:USERPROFILE\.ollama"
    if (Test-Path $modelDir) {
        Write-Info "Model directory exists: $modelDir"
        
        # Check write permissions
        try {
            $testFile = Join-Path $modelDir "test.tmp"
            New-Item -ItemType File -Path $testFile -Force | Out-Null
            Remove-Item $testFile -Force
            Write-Info "Model directory is writable"
            return $true
        } catch {
            Write-Error "Model directory is not writable: $_"
            return $false
        }
    } else {
        Write-Warning "Model directory does not exist: $modelDir"
        return $false
    }
}

function Test-AppConfiguration {
    Write-Info "Testing application configuration..."
    
    # Check registry settings
    $regPath = "HKCU:\Software\CloudToLocalLLM"
    if (Test-Path $regPath) {
        Write-Info "Registry configuration found"
        Get-ItemProperty $regPath | ForEach-Object {
            $_.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                Write-Debug "Config: $($_.Name) = $($_.Value)"
            }
        }
    } else {
        Write-Warning "No registry configuration found"
    }
    
    # Check app data directory
    $appDataPath = Join-Path $env:LOCALAPPDATA "CloudToLocalLLM"
    if (Test-Path $appDataPath) {
        Write-Info "Application data directory exists: $appDataPath"
    } else {
        Write-Warning "Application data directory not found: $appDataPath"
    }
}

function Start-SelfTest {
    Write-Info "Starting CloudToLocalLLM self-test..."
    Write-Info "----------------------------------------"
    
    $testResults = @()
    
    # Run all tests
    $testResults += @{
        "Name" = "System Requirements"
        "Result" = Test-SystemRequirements
    }
    
    $testResults += @{
        "Name" = "Service Installation"
        "Result" = Test-ServiceInstallation
    }
    
    $testResults += @{
        "Name" = "Ollama API"
        "Result" = Test-OllamaAPI
    }
    
    $testResults += @{
        "Name" = "Model Directory"
        "Result" = Test-ModelDirectory
    }
    
    Test-AppConfiguration
    
    Write-Info "----------------------------------------"
    Write-Info "Test Results Summary:"
    
    $allPassed = $true
    foreach ($test in $testResults) {
        $status = if ($test.Result) { "PASSED" } else { "FAILED"; $allPassed = $false }
        $color = if ($test.Result) { "Green" } else { "Red" }
        Write-Host "$($test.Name): $status" -ForegroundColor $color
    }
    
    Write-Info "----------------------------------------"
    if ($allPassed) {
        Write-Info "All tests completed successfully!"
        exit 0 # Explicitly exit with 0 for success
    } else {
        Write-Error "Some tests failed. Please check the log file for details."
        Write-Info "Log file location: $(Get-LogFile)"
        exit 1 # Explicitly exit with 1 for failure
    }
}

# Run the self-test
Start-SelfTest 