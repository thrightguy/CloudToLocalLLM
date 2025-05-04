# Script to set up Ollama and ngrok as part of CloudToLocalLLM
# This script installs Ollama and ngrok in the application's directory structure

param(
    [switch]$DownloadOnly,
    [string]$OllamaPort = "11434",
    [string]$DefaultModel = "llama2",
    [string]$ExistingOllamaUrl = ""
)

# Enable error handling
$ErrorActionPreference = "Stop"

# Add more visible progress output
function Write-Progress-Step {
    param(
        [string]$Message,
        [int]$PercentComplete
    )
    Write-Host "PROGRESS: $PercentComplete% - $Message" -ForegroundColor Green
    # Also output to console window if running interactively
    if ([Environment]::UserInteractive) {
        Write-Progress -Activity "Setting up Ollama" -Status $Message -PercentComplete $PercentComplete
    }
}

# Step 1: Define Variables
Write-Progress-Step -Message "Initializing variables..." -PercentComplete 5
$appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ollamaInstallDir = Join-Path $appRoot "tools\ollama"
$ngrokInstallDir = Join-Path $appRoot "tools\ngrok"
$ollamaBinary = "$ollamaInstallDir\ollama.exe"
$ngrokBinary = "$ngrokInstallDir\ngrok.exe"
$ollamaZipName = "ollama-windows-amd64.zip"
$ollamaRocmZipName = "ollama-windows-amd64-rocm.zip"
$ngrokZipName = "ngrok-v3-stable-windows-amd64.zip"
$ollamaDownloadUrl = "https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip"
$ollamaRocmDownloadUrl = "https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64-rocm.zip"
$ngrokDownloadUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
$tempDownloadDir = "$env:TEMP\OllamaDownload"
$modelDir = "$env:USERPROFILE\.ollama\models"

# Check if we're in download only mode
if ($DownloadOnly) {
    Write-Progress-Step -Message "Running in download-only mode..." -PercentComplete 10
    
    # Look for downloaded Ollama ZIP from installer
    $installerDownloadedZip = Join-Path $env:TEMP "ollama.zip"
    if (Test-Path $installerDownloadedZip) {
        Write-Progress-Step -Message "Using Ollama ZIP downloaded by installer..." -PercentComplete 15
        $ollamaZipName = "ollama.zip"
        $zipPath = $installerDownloadedZip
    }
}

# Step 2: Create Installation and Model Directories
Write-Progress-Step -Message "Creating installation directories..." -PercentComplete 20
try {
    if (Test-Path $ollamaInstallDir) {
        Write-Host "Cleaning existing installation..."
        Remove-Item -Path "$ollamaInstallDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -Path $ollamaInstallDir -ItemType Directory -Force | Out-Null
    }

    if (Test-Path $ngrokInstallDir) {
        Write-Host "Cleaning existing installation..."
        Remove-Item -Path "$ngrokInstallDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -Path $ngrokInstallDir -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path $modelDir)) {
        New-Item -Path $modelDir -ItemType Directory -Force | Out-Null
    }
} catch {
    Write-Error "Failed to create directories: $_"
    exit 1
}

# Step 3: Download and Extract Ollama ZIP
Write-Progress-Step -Message "Downloading Ollama..." -PercentComplete 30
try {
    if (-not $DownloadOnly -or -not (Test-Path $installerDownloadedZip)) {
        Write-Host "Downloading Ollama ZIP from $ollamaDownloadUrl..."
        $zipPath = "$tempDownloadDir\$ollamaZipName"
        New-Item -Path $tempDownloadDir -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $ollamaDownloadUrl -OutFile $zipPath -TimeoutSec 60
    }
    
    Write-Progress-Step -Message "Extracting Ollama..." -PercentComplete 40
    Expand-Archive -Path $zipPath -DestinationPath $ollamaInstallDir -Force
} catch {
    Write-Error "Failed to download or extract Ollama: $_"
    exit 1
}

# Step 4: Download and Extract ngrok
Write-Progress-Step -Message "Downloading ngrok..." -PercentComplete 50
try {
    Write-Host "Downloading ngrok from $ngrokDownloadUrl..."
    $ngrokZipPath = "$tempDownloadDir\$ngrokZipName"
    Invoke-WebRequest -Uri $ngrokDownloadUrl -OutFile $ngrokZipPath -TimeoutSec 60
    
    Write-Progress-Step -Message "Extracting ngrok..." -PercentComplete 60
    Expand-Archive -Path $ngrokZipPath -DestinationPath $ngrokInstallDir -Force
} catch {
    Write-Error "Failed to download or extract ngrok: $_"
    exit 1
}

# Step 5: Check for AMD GPU and Download ROCm Support if needed
Write-Progress-Step -Message "Checking for AMD GPU..." -PercentComplete 70
try {
    $gpuInfo = Get-WmiObject Win32_VideoController
    $hasAmdGpu = $gpuInfo | Where-Object { $_.Name -match "AMD|Radeon" }

    if ($hasAmdGpu) {
        Write-Host "AMD GPU detected. Downloading ROCm support package..."
        $rocmZipPath = "$tempDownloadDir\$ollamaRocmZipName"
        Invoke-WebRequest -Uri $ollamaRocmDownloadUrl -OutFile $rocmZipPath -TimeoutSec 60
        
        Write-Host "Extracting ROCm support files..."
        Expand-Archive -Path $rocmZipPath -DestinationPath $ollamaInstallDir -Force
    }
} catch {
    Write-Warning "Failed to check for or setup AMD GPU support: $_"
    # Non-critical error, continue with setup
}

# Step 6: Set OLLAMA_MODELS environment variable
Write-Progress-Step -Message "Setting environment variables..." -PercentComplete 80
try {
    [Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $modelDir, "User")
    $env:OLLAMA_MODELS = $modelDir
} catch {
    Write-Warning "Failed to set environment variables: $_"
    # Non-critical error, continue with setup
}

# Step 7: Create ngrok config
Write-Progress-Step -Message "Creating configuration files..." -PercentComplete 85
try {
    $ngrokConfig = @"
version: 2
tunnels:
  ollama:
    proto: http
    addr: $OllamaPort
    bind_tls: true
"@
    Set-Content -Path "$ngrokInstallDir\ngrok.yml" -Value $ngrokConfig
} catch {
    Write-Warning "Failed to create ngrok config: $_"
    # Non-critical error, continue with setup
}

# Step 8: Clean up
Write-Progress-Step -Message "Cleaning up temporary files..." -PercentComplete 90
try {
    if ($DownloadOnly -and (Test-Path $installerDownloadedZip)) {
        Write-Host "Keeping installer-downloaded ZIP file for later use."
    } else {
        Remove-Item -Path $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Warning "Failed to clean up temporary files: $_"
    # Non-critical error, continue with setup
}

# Only test Ollama if not in download-only mode
if (-not $DownloadOnly) {
    # Step 9: Test Ollama
    Write-Progress-Step -Message "Testing Ollama installation..." -PercentComplete 95
    try {
        $ollamaVersion = & $ollamaBinary --version
        Write-Host "Ollama version: $ollamaVersion"
        Write-Host "Ollama installation successful!"
    } catch {
        Write-Error "Failed to run Ollama. Error: $_"
        exit 1
    }

    # Step 10: Test ngrok
    try {
        $ngrokVersion = & $ngrokBinary --version
        Write-Host "ngrok version: $ngrokVersion"
        Write-Host "ngrok installation successful!"
    } catch {
        Write-Error "Failed to run ngrok. Error: $_"
        exit 1
    }
} else {
    Write-Host "Skipping Ollama and ngrok tests in download-only mode."
    $ollamaVersion = "download-only"
    $ngrokVersion = "download-only"
}

# Create a JSON config file for the application to use
Write-Progress-Step -Message "Creating final configuration..." -PercentComplete 98
try {
    $config = @{
        "ollama_path" = $ollamaBinary
        "ngrok_path" = $ngrokBinary
        "models_dir" = $modelDir
        "version" = $ollamaVersion
        "ngrok_config" = "$ngrokInstallDir\ngrok.yml"
        "default_model" = $DefaultModel
        "ollama_port" = $OllamaPort
        "existing_ollama_url" = $ExistingOllamaUrl
    } | ConvertTo-Json

    # Make sure the tools directory exists
    New-Item -Path (Join-Path $appRoot "tools") -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    $configPath = Join-Path $appRoot "tools\config.json"
    Set-Content -Path $configPath -Value $config
    Write-Host "Configuration saved to $configPath"
} catch {
    Write-Error "Failed to create configuration file: $_"
    exit 1
}

# If in download-only mode, add a message about the next steps
if ($DownloadOnly) {
    Write-Host "Ollama has been downloaded and extracted. You can start it manually or run this script again without the -DownloadOnly parameter to complete setup."
    
    # Download the default model if specified
    if ($DefaultModel -ne "") {
        Write-Host "You can download the $DefaultModel model by running:"
        Write-Host "& '$ollamaBinary' pull $DefaultModel"
    }
}

Write-Progress-Step -Message "Setup completed successfully!" -PercentComplete 100
exit 0