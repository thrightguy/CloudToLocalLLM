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
; Set privileges based on installation type
PrivilegesRequiredOverridesAllowed=dialog
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Code]
var
  OllamaPage: TInputQueryWizardPage;
  CustomDataDirPage: TInputDirWizardPage;

procedure InitializeWizard;
begin
  // Create the Ollama configuration page
  OllamaPage := CreateInputQueryPage(wpSelectTasks,
    'Ollama Configuration',
    'Configure Ollama Docker settings',
    'Please specify the following optional settings for Ollama Docker setup, then click Next.');

  OllamaPage.Add('Ollama API Port (default: 11434):', False);
  OllamaPage.Values[0] := '11434';

  // Create the custom data directory page
  CustomDataDirPage := CreateInputDirPage(wpSelectTasks,
    'Custom Data Directory',
    'Select where to store LLM models and data',
    'Select the folder where you want to store LLM models and data:',
    False,
    '');
  CustomDataDirPage.Values[0] := ExpandConstant('{userappdata}\{#MyAppName}\models');
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;

  // Skip the Ollama configuration page if Docker setup is not selected
  if (PageID = OllamaPage.ID) and (not WizardIsTaskSelected('dockersetup')) then
    Result := True;

  // Skip the custom data directory page if custom data dir is not selected
  if (PageID = CustomDataDirPage.ID) and (not WizardIsTaskSelected('customdatadir')) then
    Result := True;
end;

// Functions to get configuration values for the PowerShell script
function GetOllamaPort(Param: String): String;
begin
  Result := OllamaPage.Values[0];
  // Use default port if empty
  if Result = '' then
    Result := '11434';
end;

function GetCustomDataDir(Param: String): String;
begin
  Result := CustomDataDirPage.Values[0];
  // Use default directory if empty
  if Result = '' then
    Result := ExpandConstant('{userappdata}\{#MyAppName}\models');
end;

function GetUseCustomDataDir(Param: String): String;
begin
  if WizardIsTaskSelected('customdatadir') then
    Result := 'true'
  else
    Result := 'false';
end;

function GetEnableGPU(Param: String): String;
begin
  if WizardIsTaskSelected('gpuacceleration') then
    Result := 'true'
  else
    Result := 'false';
end;

function GetUseAutostart(Param: String): String;
begin
  if WizardIsTaskSelected('autostart') then
    Result := 'true'
  else
    Result := 'false';
end;

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "dockersetup"; Description: "Install Ollama Docker container"; GroupDescription: "Docker Setup"; Flags: unchecked
Name: "customdatadir"; Description: "Use custom data directory for models"; GroupDescription: "Advanced Options"; Flags: unchecked
Name: "autostart"; Description: "Start application at Windows startup"; GroupDescription: "Advanced Options"; Flags: unchecked
Name: "gpuacceleration"; Description: "Enable GPU acceleration (NVIDIA only)"; GroupDescription: "Performance"; Flags: unchecked

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

; Update checker
Source: "check_for_updates.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Check for Updates"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\check_for_updates.ps1"""; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Create registry entries for auto-update settings
Root: HKCU; Subkey: "Software\{#MyAppName}"; Flags: uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\{#MyAppName}\Updates"; Flags: uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\{#MyAppName}\Updates"; ValueType: dword; ValueName: "CheckForUpdatesAtStartup"; ValueData: "1"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\{#MyAppName}\Updates"; ValueType: dword; ValueName: "AutoInstallUpdates"; ValueData: "0"; Flags: uninsdeletevalue

[Run]
; Note: Release folder cleanup should be done before compilation, not during installation
; This is handled by the build.ps1 script

; Create version.txt file with the current version
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -Command ""Set-Content -Path '{app}\version.txt' -Value '{#MyAppVersion}'"""; Description: "Create version file"; Flags: runhidden

; Create a PowerShell script for Docker and Ollama setup
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -Command ""Set-Content -Path '{app}\setup_docker_ollama.ps1' -Value @'
# Setup script for Docker Desktop and Ollama
# Generated by CloudToLocalLLM installer

# Configuration
$OllamaPort = '{code:GetOllamaPort}'
$CustomDataDir = '{code:GetCustomDataDir}'
$UseCustomDataDir = '{code:GetUseCustomDataDir}'
$EnableGPU = '{code:GetEnableGPU}'
$UseAutostart = '{code:GetUseAutostart}'

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
        [bool]$hasNvidiaGPU,
        [string]$ollamaPort,
        [string]$customDataDir,
        [bool]$useCustomDataDir
    )

    try {
        Write-Host 'Setting up Ollama in Docker...'

        # Modify docker-compose.yml based on configuration
        $dockerComposeFile = Join-Path $PSScriptRoot 'docker-compose.yml'
        $dockerComposeContent = Get-Content -Path $dockerComposeFile -Raw

        # Remove GPU configuration if no NVIDIA GPU is available or GPU is not enabled
        if (-not $hasNvidiaGPU -or -not $EnableGPU -eq 'true') {
            $dockerComposeContent = $dockerComposeContent -replace '(?s)deploy:\s+resources:.*?capabilities: \[gpu\]', ''
            Write-Host 'Modified docker-compose.yml to run without GPU acceleration.'
        }

        # Update Ollama port if custom port is specified
        if ($ollamaPort -ne '11434') {
            $dockerComposeContent = $dockerComposeContent -replace 'http://localhost:11434', "http://localhost:$ollamaPort"
            $dockerComposeContent = $dockerComposeContent + "`n    ports:`n      - `"$ollamaPort:11434`""
            Write-Host "Modified docker-compose.yml to use custom port: $ollamaPort"
        }

        # Add volume mount for custom data directory if specified
        if ($useCustomDataDir -eq 'true' -and $customDataDir -ne '') {
            # Ensure the custom data directory exists
            if (-not (Test-Path -Path $customDataDir)) {
                New-Item -Path $customDataDir -ItemType Directory -Force | Out-Null
                Write-Host "Created custom data directory: $customDataDir"
            }

            # Add volume mount for custom data directory
            $volumeMount = "      - `"$($customDataDir.Replace('\', '/'))`:/root/.ollama`""
            $dockerComposeContent = $dockerComposeContent -replace '(\s+volumes:\s+.*?)(\s+deploy:|\s+healthcheck:)', "`$1`n$volumeMount`$2"
            Write-Host "Modified docker-compose.yml to use custom data directory: $customDataDir"
        }

        # Save modified docker-compose.yml
        Set-Content -Path $dockerComposeFile -Value $dockerComposeContent

        # Start Ollama container
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

# Create registry entries for Ollama configuration
Write-Host 'Creating registry entries for Ollama configuration...'
$registryPath = 'HKCU:\Software\CloudToLocalLLM\Ollama'
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
New-ItemProperty -Path $registryPath -Name 'Port' -Value $OllamaPort -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'DataDirectory' -Value $CustomDataDir -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'UseCustomDataDir' -Value $UseCustomDataDir -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'EnableGPU' -Value $EnableGPU -PropertyType String -Force | Out-Null

# Set up Ollama
$ollamaSetup = Setup-Ollama -hasNvidiaGPU $hasNvidiaGPU -ollamaPort $OllamaPort -customDataDir $CustomDataDir -useCustomDataDir $UseCustomDataDir

if (-not $ollamaSetup) {
    Write-Host 'Failed to set up Ollama. Please check Docker Desktop is running and try again.'
    exit 1
}

# Create autostart entry if selected
if ($UseAutostart -eq 'true') {
    Write-Host 'Creating autostart entry...'
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupFolder 'CloudToLocalLLM.lnk'
    $targetPath = Join-Path $PSScriptRoot 'CloudToLocalLLM-1.1.0.exe'

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $targetPath
    $Shortcut.Save()

    Write-Host 'Autostart entry created successfully.'
}

Write-Host 'Setup completed successfully!'
'@"""; Description: "Create Docker and Ollama setup script"; Flags: runhidden

; Run the Docker and Ollama setup script if the user selected the dockersetup task
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\setup_docker_ollama.ps1"""; Description: "Set up Docker and Ollama"; Flags: runhidden waituntilterminated; Tasks: dockersetup

; Create a scheduled task to check for updates at startup
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -Command ""$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ExecutionPolicy Bypass -WindowStyle Hidden -File \""$($PWD.Path)\check_for_updates.ps1\"" -Silent'; $trigger = New-ScheduledTaskTrigger -AtLogon; $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable; $task = Register-ScheduledTask -TaskName 'CloudToLocalLLM Update Check' -Action $action -Trigger $trigger -Settings $settings -Description 'Checks for updates to CloudToLocalLLM at logon' -Force"""; Description: "Create update check scheduled task"; Flags: runhidden

; Launch the application
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
