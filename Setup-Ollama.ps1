# Script to set up Ollama and pull models
# Must be run with administrative privileges

# Step 1: Check for Administrative Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator and try again."
    exit 1
}

# Step 2: Define Variables
$ollamaInstallDir = "C:\Ollama"
$ollamaBinary = "$ollamaInstallDir\ollama.exe"
$ollamaInstallerName = "ollama-windows-amd64.exe"
$ollamaZipName = "ollama-windows-amd64.zip"
$ollamaDownloadUrl = "https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip"
$nssmDownloadUrl = "https://nssm.cc/release/nssm-2.24.zip"
$models = @("gemma2:9b", "codegemma:2b", "nomic-embed-text")
$commonDownloadFolders = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents")
$tempDownloadDir = "$env:TEMP\OllamaDownload"

# Step 3: Clean the Ollama Installation Directory
Write-Output "Cleaning Ollama installation directory at $ollamaInstallDir..."
if (Test-Path $ollamaInstallDir) {
    Remove-Item -Path "$ollamaInstallDir\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path $ollamaInstallDir -ItemType Directory -Force | Out-Null
}

# Step 4: Check if Ollama Binary Exists or Download ollama-windows-amd64.exe
if (Test-Path $ollamaBinary) {
    Write-Output "Ollama binary already exists at $ollamaBinary."
} else {
    $installerPath = $null
    foreach ($folder in $commonDownloadFolders) {
        $potentialPath = Join-Path -Path $folder -ChildPath $ollamaInstallerName
        if (Test-Path $potentialPath) {
            $installerPath = $potentialPath
            Write-Output "Found Ollama binary at $installerPath."
            break
        }
    }

    if ($installerPath) {
        Write-Output "Copying Ollama binary from $installerPath to $ollamaBinary..."
        Copy-Item -Path $installerPath -Destination $ollamaBinary -Force
    } else {
        Write-Output "Ollama binary not found in common download folders ($($commonDownloadFolders -join ', '))."
        $response = Read-Host "Download it now? (y/n)"
        if ($response -eq "y") {
            Write-Output "Downloading Ollama binary from $ollamaDownloadUrl..."
            $zipPath = "$tempDownloadDir\$ollamaZipName"
            New-Item -Path $tempDownloadDir -ItemType Directory -Force | Out-Null
            Invoke-WebRequest -Uri $ollamaDownloadUrl -OutFile $zipPath

            Write-Output "Extracting $zipPath to $tempDownloadDir..."
            Expand-Archive -Path $zipPath -DestinationPath $tempDownloadDir -Force

            # Search for ollama.exe in the extracted files
            $extractedBinary = Get-ChildItem -Path $tempDownloadDir -Filter "ollama.exe" -Recurse -File | Select-Object -First 1
            if ($extractedBinary) {
                Write-Output "Found ollama.exe in extracted files. Copying to $ollamaBinary..."
                Copy-Item -Path $extractedBinary.FullName -Destination $ollamaBinary -Force
            } else {
                Write-Error "Could not find ollama.exe in the downloaded zip."
                Write-Output "Please ensure the download from $ollamaDownloadUrl is correct and re-run the script."
                Remove-Item -Path $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
                exit 1
            }

            # Clean up temporary download directory
            Remove-Item -Path $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Error "Ollama binary is required to proceed. Please download it from $ollamaDownloadUrl and re-run the script."
            exit 1
        }
    }
}

# Step 5: Unblock the Ollama Binary
Write-Output "Unblocking Ollama binary if necessary..."
Unblock-File -Path $ollamaBinary -ErrorAction SilentlyContinue

# Step 6: Set Permissions on Ollama Directory and Binary
Write-Output "Setting permissions on $ollamaInstallDir..."
icacls "$ollamaInstallDir" /grant:r "$env:USERNAME:F" /T
icacls "$ollamaBinary" /grant:r "$env:USERNAME:F"

# Step 7: Check for Port Conflicts on 11434
Write-Output "Checking for port conflicts on 11434..."
$portCheck = netstat -ano | Select-String "11434"
if ($portCheck) {
    Write-Warning "Port 11434 is in use. This may prevent Ollama from starting."
    Write-Output "Processes using port 11434:"
    Write-Output $portCheck
    $response = Read-Host "Terminate these processes? (y/n)"
    if ($response -eq "y") {
        $portCheck | ForEach-Object {
            if ($_ -match "LISTENING\s+(\d+)$") {
                $pid = $matches[1]
                Write-Output "Terminating process with PID $pid..."
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Error "Port 11434 is in use. Please free the port and re-run the script."
        exit 1
    }
}

# Step 8: Prompt for Antivirus Exclusion
Write-Output "Antivirus software may block Ollama from running."
Write-Output "Please add an exclusion for $ollamaInstallDir in your antivirus software (e.g., Windows Defender)."
Write-Output "For Windows Defender, you can do this by:"
Write-Output "1. Open Windows Security -> Virus & threat protection -> Manage settings -> Exclusions -> Add or remove exclusions."
Write-Output "2. Add $ollamaInstallDir as an exclusion."
$continue = Read-Host "Press Enter to continue after adding the exclusion (or to skip)"

# Step 9: Install Ollama as a Service
Write-Output "Checking if Ollama is already installed as a service..."
$serviceExists = Get-Service -Name "OllamaService" -ErrorAction SilentlyContinue

$installService = $true
if ($serviceExists) {
    Write-Output "Ollama service is already installed."
    $reinstall = Read-Host "Do you want to reinstall the service? (y/n)"
    if ($reinstall -ne "y") {
        Write-Output "Skipping service installation. Using existing Ollama service."
        $installService = $false
    } else {
        Write-Output "Removing existing Ollama service..."
        Stop-Service -Name "OllamaService" -Force -ErrorAction SilentlyContinue
        # We'll use NSSM to properly remove the service
    }
}

if ($installService) {
    Write-Output "Installing Ollama as a Windows service to start automatically on boot..."

    # Download NSSM if not present
    $nssmPath = "$ollamaInstallDir\nssm.exe"
    if (-not (Test-Path $nssmPath)) {
        Write-Output "Downloading NSSM to manage the service..."
        $nssmZipPath = "$tempDownloadDir\nssm-2.24.zip"
        New-Item -Path $tempDownloadDir -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Uri $nssmDownloadUrl -OutFile $nssmZipPath

        Write-Output "Extracting NSSM..."
        Expand-Archive -Path $nssmZipPath -DestinationPath $tempDownloadDir -Force
        $nssmExtracted = "$tempDownloadDir\nssm-2.24\win64\nssm.exe"
        if (Test-Path $nssmExtracted) {
            Copy-Item -Path $nssmExtracted -Destination $nssmPath -Force
        } else {
            Write-Error "Failed to extract NSSM."
            Remove-Item -Path $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
            exit 1
        }
        Remove-Item -Path $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # If we're reinstalling, remove the existing service first
    if ($serviceExists) {
        Write-Output "Removing existing Ollama service..."
        & $nssmPath remove OllamaService confirm
    }

    # Install Ollama as a service using NSSM
    Write-Output "Installing Ollama as a Windows service..."
& $nssmPath install OllamaService $ollamaBinary
& $nssmPath set OllamaService AppParameters serve
& $nssmPath set OllamaService AppDirectory $ollamaInstallDir
& $nssmPath set OllamaService Description "Ollama Server for Local LLM"
& $nssmPath set OllamaService Start SERVICE_AUTO_START

# Redirect service output to logs
& $nssmPath set OllamaService AppStdout "$ollamaInstallDir\ollama-serve.log"
& $nssmPath set OllamaService AppStderr "$ollamaInstallDir\ollama-serve-error.log"

# Start the service
Write-Output "Starting Ollama service..."
& $nssmPath start OllamaService
}
else {
    # If we're using an existing service, make sure it's running
    $serviceStatus = Get-Service -Name "OllamaService" -ErrorAction SilentlyContinue
    if ($serviceStatus.Status -ne "Running") {
        Write-Output "Starting existing Ollama service..."
        Start-Service -Name "OllamaService" -ErrorAction SilentlyContinue
    } else {
        Write-Output "Ollama service is already running."
    }
}

# Wait for the server to start (increased wait time for stability)
Start-Sleep -Seconds 10

# Verify Ollama server is running
Write-Output "Verifying Ollama server..."
try {
    $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get
    Write-Output "Ollama server is running: $response"
} catch {
    Write-Error "Failed to start Ollama server. Check logs at $ollamaInstallDir\ollama-serve-error.log"
    if ($response -eq "y") {
        Write-Output "You can stop the service by running: $nssmPath stop OllamaService"
    } else {
        Write-Output "As a fallback, please open a new command prompt, navigate to $ollamaInstallDir, and run: ollama serve"
    }
    Write-Output "Then re-run this script to continue the setup."
    exit 1
}

# Step 10: Pull Models
foreach ($model in $models) {
    Write-Output "Pulling model $model..."
    & $ollamaBinary pull $model
}

# Step 11: Pre-load Models
foreach ($model in $models) {
    Write-Output "Pre-loading model $model..."
    & $ollamaBinary run $model "Hello"
}

# Step 12: Verify Models
Write-Output "Listing installed models..."
& $ollamaBinary list

# Step 13: Verify VRAM Usage
Write-Output "Checking VRAM usage..."
nvidia-smi

Write-Output "Setup complete! Ollama is installed at $ollamaInstallDir and models are loaded."
Write-Output "Ollama is running as a service. To stop it, run: $nssmPath stop OllamaService"
Write-Output "To remove the service, run: $nssmPath remove OllamaService"