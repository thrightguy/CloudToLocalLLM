; Inno Setup Script for CloudToLocalLLM
; This script creates a Windows installer for the CloudToLocalLLM application

#define MyAppName "CloudToLocalLLM"
#define MyAppPublisher "CloudToLocalLLM"
#define MyAppURL "https://github.com/thrightguy/CloudToLocalLLM"
#define MyAppExeName "cloudtolocalllm_dev.exe"

#define MyAppVersion "1.2.0"
#define MyDateTime GetDateTimeString('yyyymmddhhnn', '', '')

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
OutputBaseFilename={#MyAppName}-Windows-{#MyAppVersion}-{#MyDateTime}-Setup
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
  OllamaPage := nil;
  CustomDataDirPage := nil;
  // Only create Ollama configuration page if the task is selected
  if WizardIsTaskSelected('ollamaservice') then
  begin
    OllamaPage := CreateInputQueryPage(wpSelectTasks,
      'Ollama Configuration',
      'Configure Ollama Windows Service settings',
      'Please specify the following optional settings for Ollama service setup, then click Next.');
    OllamaPage.Add('Ollama API Port (default: 11434):', False);
    OllamaPage.Values[0] := '11434';
  end;

  // Only create custom data directory page if the task is selected
  if WizardIsTaskSelected('customdatadir') then
  begin
    CustomDataDirPage := CreateInputDirPage(wpSelectTasks,
      'Custom Data Directory',
      'Select where to store LLM models and data',
      'Select the folder where you want to store LLM models and data:',
      False,
      '');
    CustomDataDirPage.Values[0] := ExpandConstant('{userappdata}\{#MyAppName}\models');
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;

  // Skip the Ollama configuration page if Ollama service setup is not selected
  if (Assigned(OllamaPage) and (PageID = OllamaPage.ID)) and (not WizardIsTaskSelected('ollamaservice')) then
    Result := True;

  // Skip the custom data directory page if custom data dir is not selected
  if (Assigned(CustomDataDirPage) and (PageID = CustomDataDirPage.ID)) and (not WizardIsTaskSelected('customdatadir')) then
    Result := True;
end;

function GetOllamaPort(Param: String): String;
begin
  try
    if Assigned(OllamaPage) and (OllamaPage.Values[0] <> '') then
      Result := OllamaPage.Values[0]
    else
      Result := '11434';
  except
    Result := '11434';
  end;
end;

function GetCustomDataDir(Param: String): String;
begin
  try
    if Assigned(CustomDataDirPage) and (CustomDataDirPage.Values[0] <> '') then
      Result := CustomDataDirPage.Values[0]
    else
      Result := ExpandConstant('{userappdata}\{#MyAppName}\models');
  except
    Result := ExpandConstant('{userappdata}\{#MyAppName}\models');
  end;
end;

function GetUseCustomDataDir(Param: String): String;
begin
  try
    if WizardIsTaskSelected('customdatadir') then
      Result := 'true'
    else
      Result := 'false';
  except
    Result := 'false';
  end;
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

function GetLogLevel(Param: String): String;
begin
  if WizardIsTaskSelected('enablelogging') then
    Result := 'DEBUG'
  else
    Result := 'INFO';
end;

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "ollamaservice"; Description: "Install Ollama as Windows service"; GroupDescription: "LLM Setup"; Flags: unchecked
Name: "customdatadir"; Description: "Use custom data directory for models"; GroupDescription: "Advanced Options"; Flags: unchecked
Name: "autostart"; Description: "Start application at Windows startup"; GroupDescription: "Advanced Options"; Flags: unchecked
Name: "gpuacceleration"; Description: "Enable GPU acceleration (NVIDIA only)"; GroupDescription: "Performance"; Flags: unchecked
Name: "selftest"; Description: "Run self-test after installation"; GroupDescription: "Diagnostics"; Flags: unchecked
Name: "enablelogging"; Description: "Enable detailed logging"; GroupDescription: "Diagnostics"; Flags: unchecked

[Files]
; Main executable
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; DLLs
Source: "build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
; Data directory and all files in it
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Ollama service files
Source: "scripts\install_ollama_service.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\uninstall_ollama_service.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\ollama_service_manager.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\logging.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\test_installation.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion

; Create tools directory
Source: "tools\*"; DestDir: "{app}\tools"; Flags: ignoreversion recursesubdirs createallsubdirs

; Update checker
Source: "check_for_updates.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Check for Updates"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\check_for_updates.ps1"""; WorkingDir: "{app}"
Name: "{group}\Run Self-Test"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\test_installation.ps1"""; WorkingDir: "{app}"
Name: "{group}\View Logs"; Filename: "explorer.exe"; Parameters: """{app}\logs"""; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Create registry entries for auto-update settings
Root: HKCU; Subkey: "Software\{#MyAppName}"; Flags: uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\{#MyAppName}\Updates"; Flags: uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\{#MyAppName}\Updates"; ValueType: dword; ValueName: "CheckForUpdatesAtStartup"; ValueData: "1"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\{#MyAppName}\Updates"; ValueType: dword; ValueName: "AutoInstallUpdates"; ValueData: "0"; Flags: uninsdeletevalue
; Add logging settings
Root: HKCU; Subkey: "Software\{#MyAppName}\Logging"; Flags: uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\{#MyAppName}\Logging"; ValueType: string; ValueName: "LogLevel"; ValueData: "{code:GetLogLevel}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\{#MyAppName}\Logging"; ValueType: string; ValueName: "LogPath"; ValueData: "{app}\logs\cloudtolocalllm.log"; Flags: uninsdeletevalue

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\test_installation.ps1"""; WorkingDir: "{app}"; Flags: runhidden; Tasks: selftest; Description: "Running self-test..."
