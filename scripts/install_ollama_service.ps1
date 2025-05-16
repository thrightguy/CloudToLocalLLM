# Install Ollama as a Windows Service
# This script installs and configures Ollama as a Windows service

param (
    [string]$OllamaApiPort = "11434", # Default Ollama API port
    [string]$OllamaPath = "$env:ProgramFiles\Ollama", # Default installation directory
    [string]$ModelsDir = "$env:USERPROFILE\.ollama", # Default models directory
    [switch]$EnableGpu = $false # Enable GPU acceleration
)

Write-Host "CloudToLocalLLM - Ollama Service Installer" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Error: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please restart the script with administrative privileges" -ForegroundColor Yellow
    exit 1
}

# Check if NSSM (Non-Sucking Service Manager) is available
$nssmPath = "$PSScriptRoot\..\tools\nssm.exe"
if (-not (Test-Path $nssmPath)) {
    Write-Host "NSSM not found in tools directory. Attempting to download..." -ForegroundColor Yellow
    
    try {
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        $nssmZipPath = "$env:TEMP\nssm.zip"
        $nssmExtractPath = "$env:TEMP\nssm"
        
        # Create tools directory if it doesn't exist
        if (-not (Test-Path "$PSScriptRoot\..\tools")) {
            New-Item -ItemType Directory -Path "$PSScriptRoot\..\tools" -Force | Out-Null
        }
        
        # Download NSSM
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($nssmUrl, $nssmZipPath)
        
        # Extract NSSM
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($nssmZipPath, $nssmExtractPath)
        
        # Copy NSSM executable to tools directory
        Copy-Item -Path "$nssmExtractPath\nssm-2.24\win64\nssm.exe" -Destination $nssmPath -Force
        
        # Clean up
        Remove-Item -Path $nssmZipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $nssmExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "NSSM downloaded and installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Error downloading NSSM: $_" -ForegroundColor Red
        Write-Host "Please download NSSM manually from https://nssm.cc and place nssm.exe in the tools directory" -ForegroundColor Yellow
        exit 1
    }
}

# Check if Ollama is installed
$ollamaExePath = "$OllamaPath\ollama.exe"
if (-not (Test-Path $ollamaExePath)) {
    Write-Host "Ollama is not installed at $OllamaPath" -ForegroundColor Yellow
    Write-Host "Downloading Ollama..." -ForegroundColor Yellow
    
    # Download Ollama
    $ollamaUrl = "https://ollama.ai/download/ollama-windows.zip"
    $ollamaZipPath = "$env:TEMP\ollama.zip"
    $ollamaExtractPath = "$env:TEMP\ollama"
    
    # Create Ollama directory
    if (-not (Test-Path $OllamaPath)) {
        New-Item -ItemType Directory -Path $OllamaPath -Force | Out-Null
    }
    
    # Download Ollama
    Invoke-WebRequest -Uri $ollamaUrl -OutFile $ollamaZipPath
    
    # Extract Ollama
    Expand-Archive -Path $ollamaZipPath -DestinationPath $ollamaExtractPath -Force
    
    # Copy Ollama files to installation directory
    Copy-Item -Path "$ollamaExtractPath\*" -Destination $OllamaPath -Recurse -Force
    
    # Clean up
    Remove-Item -Path $ollamaZipPath -Force
    Remove-Item -Path $ollamaExtractPath -Recurse -Force
    
    Write-Host "Ollama installed successfully at $OllamaPath" -ForegroundColor Green
}

# Create models directory if it doesn't exist
if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
    Write-Host "Created models directory at $ModelsDir" -ForegroundColor Green
}

# Check if Ollama service already exists
$serviceExists = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue
if ($serviceExists) {
    Write-Host "Ollama service already exists. Removing existing service..." -ForegroundColor Yellow
    & $nssmPath remove Ollama confirm
    Start-Sleep -Seconds 2
}

# Create environment variables
$env:OLLAMA_HOST = "127.0.0.1:$OllamaApiPort"
$env:OLLAMA_MODELS = $ModelsDir

# Additional parameters for GPU acceleration
$extraParams = ""
if ($EnableGpu) {
    Write-Host "GPU acceleration was requested. Ollama typically auto-detects compatible GPUs."
    Write-Host "Ensure NVIDIA drivers are up to date for NVIDIA GPUs."
    Write-Host "Ollama server logs may provide more info on GPU detection."
    # If Ollama uses specific ENV VARS for GPU for 'serve', they could be added here to AppEnvironmentExtra later.
}

# Install Ollama as a service using NSSM
Write-Host "Installing Ollama as a Windows service..." -ForegroundColor Yellow
# Construct the arguments for ollama.exe serve. No explicit --gpu flag here.
$ollamaServeArguments = "serve"
& $nssmPath install Ollama $ollamaExePath $ollamaServeArguments
& $nssmPath set Ollama DisplayName "Ollama - Local LLM Server"
& $nssmPath set Ollama Description "Runs Ollama as a service for CloudToLocalLLM"
& $nssmPath set Ollama AppDirectory $OllamaPath
& $nssmPath set Ollama AppEnvironmentExtra "OLLAMA_HOST=127.0.0.1:$OllamaApiPort" "OLLAMA_MODELS=$ModelsDir"
& $nssmPath set Ollama Start SERVICE_AUTO_START
& $nssmPath set Ollama ObjectName LocalSystem
& $nssmPath set Ollama Type SERVICE_WIN32_OWN_PROCESS

# Start the service
Write-Host "Starting Ollama service..." -ForegroundColor Yellow
Start-Service -Name "Ollama"
Start-Sleep -Seconds 3

# Check if service is running
$service = Get-Service -Name "Ollama" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "Ollama service is now running on port $OllamaApiPort" -ForegroundColor Green
    Write-Host "Service installed successfully!" -ForegroundColor Green
} else {
    Write-Host "Warning: Ollama service is not running. Please check the Windows Services management console." -ForegroundColor Yellow
}

Write-Host "Installation complete!" -ForegroundColor Cyan 