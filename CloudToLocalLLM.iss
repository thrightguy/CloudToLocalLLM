; Inno Setup Script for CloudToLocalLLM
; This script creates a Windows installer for the CloudToLocalLLM application

#define MyAppName "CloudToLocalLLM"
#define MyAppPublisher "CloudToLocalLLM"
#define MyAppURL "https://github.com/thrightguy/CloudToLocalLLM"
#define MyAppExeName "CloudToLocalLLM-1.1.0.exe"

; Read version from pubspec.yaml
#define FindLine(str, filename) \
    Local[0] = FileOpen(filename), \
    Local[1] = "", \
    While (!FileEof(Local[0])) Do ( \
        Local[1] = FileRead(Local[0]), \
        If (Pos(str, Local[1]) > 0) Then \
            Break \
    ), \
    FileClose(Local[0]), \
    Local[1]

#define VersionLine FindLine("version:", "pubspec.yaml")
#define MyAppVersion Copy(VersionLine, Pos(":", VersionLine) + 2, 5)

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{8F6E7F9A-5E0A-4B7C-8D3A-9E7F8D5E0A9B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=releases
OutputBaseFilename={#MyAppName}-Windows-{#MyAppVersion}-Setup
Compression=lzma
SolidCompression=yes
; Set privileges to admin for installation
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main executable
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; DLLs
Source: "build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; Data directory and all files in it
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Docker setup files
Source: "docker-compose.yml"; DestDir: "{app}"; Flags: ignoreversion
Source: "setup_ollama.sh"; DestDir: "{app}"; Flags: ignoreversion
Source: "check_ollama.sh"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Create a PowerShell script for Docker and Ollama setup
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -Command ""Set-Content -Path '{app}\setup_docker_ollama.ps1' -Value @'
# Setup script for Docker Desktop and Ollama

# Function to check if Docker Desktop is installed
function Test-DockerInstalled {
    try {
        $dockerApp = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -like '*Docker Desktop*' }
        return ($dockerApp -ne $null)
    } catch {
        # Fallback method if CIM doesn't work
        $dockerPath = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
        return (Test-Path $dockerPath)
    }
}

# Function to check if NVIDIA GPU is available
function Test-NvidiaGPU {
    try {
        $gpuInfo = Get-CimInstance -ClassName Win32_VideoController
        foreach ($gpu in $gpuInfo) {
            if ($gpu.Name -like '*NVIDIA*') {
                Write-Host 'NVIDIA GPU detected: ' + $gpu.Name
                return $true
            }
        }
        Write-Host 'No NVIDIA GPU detected. Ollama will run without GPU acceleration.'
        return $false
    } catch {
        Write-Host 'Error detecting GPU: ' + $_.Exception.Message
        return $false
    }
}

# Function to install Docker Desktop
function Install-DockerDesktop {
    try {
        Write-Host 'Docker Desktop not found. Downloading...'
        $downloadUrl = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
        $installerPath = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'

        # Download Docker Desktop installer
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

        Write-Host 'Installing Docker Desktop...'
        Start-Process -FilePath $installerPath -ArgumentList 'install --quiet' -Wait

        # Clean up
        Remove-Item -Path $installerPath -Force

        Write-Host 'Docker Desktop installation completed.'

        # Wait for Docker to initialize
        Write-Host 'Waiting for Docker to initialize...'
        Start-Sleep -Seconds 30

        return $true
    } catch {
        Write-Host 'Error installing Docker Desktop: ' + $_.Exception.Message
        return $false
    }
}

# Function to set up Ollama in Docker
function Setup-Ollama {
    param (
        [bool]$hasNvidiaGPU
    )

    try {
        Write-Host 'Setting up Ollama in Docker...'

        # Modify docker-compose.yml if no NVIDIA GPU is available
        if (-not $hasNvidiaGPU) {
            $dockerComposeFile = Join-Path $PSScriptRoot 'docker-compose.yml'
            $dockerComposeContent = Get-Content -Path $dockerComposeFile -Raw

            # Remove GPU configuration if no NVIDIA GPU is available
            $dockerComposeContent = $dockerComposeContent -replace '(?s)deploy:\s+resources:.*?capabilities: \[gpu\]', ''

            Set-Content -Path $dockerComposeFile -Value $dockerComposeContent
            Write-Host 'Modified docker-compose.yml to run without GPU acceleration.'
        }

        # Start Ollama container
        $dockerComposeFile = Join-Path $PSScriptRoot 'docker-compose.yml'
        $process = Start-Process -FilePath 'docker' -ArgumentList "compose -f `"$dockerComposeFile`" up -d ollama" -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Host 'Ollama setup completed successfully.'
            return $true
        } else {
            Write-Host 'Error setting up Ollama. Exit code: ' + $process.ExitCode
            return $false
        }
    } catch {
        Write-Host 'Error setting up Ollama: ' + $_.Exception.Message
        return $false
    }
}

# Main script
Write-Host '=== CloudToLocalLLM Docker and Ollama Setup ==='

# Check for NVIDIA GPU
$hasNvidiaGPU = Test-NvidiaGPU

# Check if Docker Desktop is installed
$dockerInstalled = Test-DockerInstalled

if (-not $dockerInstalled) {
    $dockerInstalled = Install-DockerDesktop

    if (-not $dockerInstalled) {
        Write-Host 'Failed to install Docker Desktop. Please install it manually and then run this script again.'
        exit 1
    }
}

# Set up Ollama
$ollamaSetup = Setup-Ollama -hasNvidiaGPU $hasNvidiaGPU

if (-not $ollamaSetup) {
    Write-Host 'Failed to set up Ollama. Please check Docker Desktop is running and try again.'
    exit 1
}

Write-Host 'Setup completed successfully!'
'@"""; Description: "Create Docker and Ollama setup script"; Flags: runhidden

; Run the Docker and Ollama setup script
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\setup_docker_ollama.ps1"""; Description: "Set up Docker and Ollama"; Flags: runhidden waituntilterminated

; Launch the application
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
