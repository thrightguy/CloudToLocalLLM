# Script to set up Ollama and ngrok as part of CloudToLocalLLM
# This script installs Ollama and ngrok in the application's directory structure

param(
    [switch]$DownloadOnly,
    [string]$OllamaPort = "11434",
    [string]$DefaultModel = "llama2",
    [string]$ExistingOllamaUrl = ""
)

# Step 1: Define Variables
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
    Write-Output "Running in download-only mode..."
    
    # Look for downloaded Ollama ZIP from installer
    $installerDownloadedZip = Join-Path $env:TEMP "ollama.zip"
    if (Test-Path $installerDownloadedZip) {
        Write-Output "Using Ollama ZIP downloaded by installer..."
        $ollamaZipName = "ollama.zip"
        $zipPath = $installerDownloadedZip
    }
}

# Step 2: Create Installation and Model Directories
Write-Output "Creating Ollama installation directory at $ollamaInstallDir..."
if (Test-Path $ollamaInstallDir) {
    Write-Output "Cleaning existing installation..."
    Remove-Item -Path "$ollamaInstallDir\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path $ollamaInstallDir -ItemType Directory -Force | Out-Null
}

Write-Output "Creating ngrok installation directory at $ngrokInstallDir..."
if (Test-Path $ngrokInstallDir) {
    Write-Output "Cleaning existing installation..."
    Remove-Item -Path "$ngrokInstallDir\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path $ngrokInstallDir -ItemType Directory -Force | Out-Null
}

Write-Output "Creating model directory at $modelDir..."
if (-not (Test-Path $modelDir)) {
    New-Item -Path $modelDir -ItemType Directory -Force | Out-Null
}

# Step 3: Download and Extract Ollama ZIP
if (-not $DownloadOnly -or -not (Test-Path $installerDownloadedZip)) {
    Write-Output "Downloading Ollama ZIP from $ollamaDownloadUrl..."
    $zipPath = "$tempDownloadDir\$ollamaZipName"
    New-Item -Path $tempDownloadDir -ItemType Directory -Force | Out-Null
    Invoke-WebRequest -Uri $ollamaDownloadUrl -OutFile $zipPath
}

Write-Output "Extracting $zipPath to $ollamaInstallDir..."
Expand-Archive -Path $zipPath -DestinationPath $ollamaInstallDir -Force

# Step 4: Download and Extract ngrok
Write-Output "Downloading ngrok from $ngrokDownloadUrl..."
$ngrokZipPath = "$tempDownloadDir\$ngrokZipName"
Invoke-WebRequest -Uri $ngrokDownloadUrl -OutFile $ngrokZipPath

Write-Output "Extracting $ngrokZipPath to $ngrokInstallDir..."
Expand-Archive -Path $ngrokZipPath -DestinationPath $ngrokInstallDir -Force

# Step 5: Check for AMD GPU and Download ROCm Support if needed
$gpuInfo = Get-WmiObject Win32_VideoController
$hasAmdGpu = $gpuInfo | Where-Object { $_.Name -match "AMD|Radeon" }

if ($hasAmdGpu) {
    Write-Output "AMD GPU detected. Downloading ROCm support package..."
    $rocmZipPath = "$tempDownloadDir\$ollamaRocmZipName"
    Invoke-WebRequest -Uri $ollamaRocmDownloadUrl -OutFile $rocmZipPath
    
    Write-Output "Extracting ROCm support files..."
    Expand-Archive -Path $rocmZipPath -DestinationPath $ollamaInstallDir -Force
}

# Step 6: Set OLLAMA_MODELS environment variable
Write-Output "Setting OLLAMA_MODELS environment variable..."
[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $modelDir, "User")
$env:OLLAMA_MODELS = $modelDir

# Step 7: Create ngrok config
$ngrokConfig = @"
version: 2
tunnels:
  ollama:
    proto: http
    addr: $OllamaPort
    bind_tls: true
"@
Set-Content -Path "$ngrokInstallDir\ngrok.yml" -Value $ngrokConfig

# Step 8: Clean up
Write-Output "Cleaning up temporary files..."
if ($DownloadOnly -and (Test-Path $installerDownloadedZip)) {
    # Keep the installer-downloaded ZIP for later use
    Write-Output "Keeping installer-downloaded ZIP file for later use."
} else {
    Remove-Item -Path $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Only test Ollama if not in download-only mode
if (-not $DownloadOnly) {
    # Step 9: Test Ollama
    Write-Output "Testing Ollama installation..."
    try {
        $ollamaVersion = & $ollamaBinary --version
        Write-Output "Ollama version: $ollamaVersion"
        Write-Output "Ollama installation successful!"
    } catch {
        Write-Error "Failed to run Ollama. Error: $_"
        exit 1
    }

    # Step 10: Test ngrok
    Write-Output "Testing ngrok installation..."
    try {
        $ngrokVersion = & $ngrokBinary --version
        Write-Output "ngrok version: $ngrokVersion"
        Write-Output "ngrok installation successful!"
    } catch {
        Write-Error "Failed to run ngrok. Error: $_"
        exit 1
    }
} else {
    Write-Output "Skipping Ollama and ngrok tests in download-only mode."
    $ollamaVersion = "download-only"
    $ngrokVersion = "download-only"
}

# Create a JSON config file for the application to use
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

$configPath = Join-Path $appRoot "tools\config.json"
Set-Content -Path $configPath -Value $config
Write-Output "Configuration saved to $configPath"

# If in download-only mode, add a message about the next steps
if ($DownloadOnly) {
    Write-Output "Ollama has been downloaded and extracted. You can start it manually or run this script again without the -DownloadOnly parameter to complete setup."
    
    # Download the default model if specified
    if ($DefaultModel -ne "") {
        Write-Output "You can download the $DefaultModel model by running:"
        Write-Output "& '$ollamaBinary' pull $DefaultModel"
    }
}