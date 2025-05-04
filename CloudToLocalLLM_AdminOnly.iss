#define MyAppName "CloudToLocalLLM"
#define MyAppVersion "1.3.0"
#define MyAppPublisher "CloudToLocalLLM"
#define MyAppURL "https://cloudtolocalllm.online"
#define MyAppExeName "cloudtolocalllm_dev.exe"

[Setup]
AppId={{com.cloudtolocalllm.app}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; Require administrator privileges for installation
PrivilegesRequired=admin
; No privilege overrides allowed - must be admin
PrivilegesRequiredOverridesAllowed=dialog
; Force installation for all users
AlwaysRestart=no
OutputBaseFilename=CloudToLocalLLM-Windows-{#MyAppVersion}-AdminSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
; Administrative install message
SetupMutex=CloudToLocalLLMAdminInstaller

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
; Custom message to inform about admin requirements
AdminPrivilegesRequired=This installer requires administrator privileges to install CloudToLocalLLM for all users. Please run this installer with administrator rights.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Setup-Ollama.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Setup-Ollama.ps1"" -DownloadOnly -OllamaPort '{code:GetOllamaPort}' -DefaultModel '{code:GetDefaultModel}' -ExistingOllamaUrl '{code:GetExistingOllamaUrl}'"; Description: "Setup Ollama"; Flags: waituntilterminated shellexec runascurrentuser; Check: IsOllamaDownloadSelected
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent runascurrentuser

[Code]
var
  DownloadPage: TDownloadWizardPage;
  LLMProviderPage: TInputOptionWizardPage;
  OllamaConfigPage: TInputQueryWizardPage;
  LMStudioConfigPage: TInputQueryWizardPage;
  ExistingOllamaConfigPage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  // Show a message at the start of the installation to confirm admin installation
  if not WizardSilent then
    MsgBox('This installer will install CloudToLocalLLM for all users on this computer.' + #13#10 + 
           'Administrator privileges are required for installation.', mbInformation, MB_OK);

  // LLM Provider selection page
  LLMProviderPage := CreateInputOptionPage(wpSelectTasks,
    'LLM Provider Configuration',
    'Select your preferred LLM provider',
    'CloudToLocalLLM can work with different LLM providers. Please select your preferred option:',
    True, False);
  LLMProviderPage.Add('Download and install Ollama (recommended)');
  LLMProviderPage.Add('Use existing Ollama installation');
  LLMProviderPage.Add('Configure LM Studio');
  LLMProviderPage.SelectedValueIndex := 0;

  // Ollama configuration page
  OllamaConfigPage := CreateInputQueryPage(LLMProviderPage.ID,
    'Ollama Configuration',
    'Configure Ollama options',
    'Please specify the settings for Ollama:');
  OllamaConfigPage.Add('Ollama API Port (default: 11434):', False);
  OllamaConfigPage.Add('Default model to download (e.g., llama2, mistral):', False);
  OllamaConfigPage.Values[0] := '11434';
  OllamaConfigPage.Values[1] := 'llama2';

  // Existing Ollama configuration page
  ExistingOllamaConfigPage := CreateInputQueryPage(LLMProviderPage.ID,
    'Existing Ollama Configuration',
    'Configure your existing Ollama installation',
    'Please specify the settings for your existing Ollama:');
  ExistingOllamaConfigPage.Add('Ollama API URL (default: http://localhost:11434):', False);
  ExistingOllamaConfigPage.Values[0] := 'http://localhost:11434';

  // LM Studio configuration page
  LMStudioConfigPage := CreateInputQueryPage(LLMProviderPage.ID,
    'LM Studio Configuration',
    'Configure LM Studio options',
    'Please specify the settings for LM Studio:');
  LMStudioConfigPage.Add('LM Studio API URL (default: http://localhost:1234/v1):', False);
  LMStudioConfigPage.Values[0] := 'http://localhost:1234/v1';

  // Download page for additional files
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing),
    SetupMessage(msgPreparingDesc),
    nil);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  SelectedLLMProvider: Integer;
begin
  Result := True;

  // Store the selected LLM provider
  if CurPageID = LLMProviderPage.ID then
  begin
    SelectedLLMProvider := LLMProviderPage.SelectedValueIndex;
  end;

  // Handle downloading Ollama if selected
  if (CurPageID = wpReady) and (LLMProviderPage.SelectedValueIndex = 0) then
  begin
    DownloadPage.Clear;
    DownloadPage.Add('https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip', 'ollama.zip', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
        // The actual extraction will be handled by Setup-Ollama.ps1
        Result := True;
      except
        if DownloadPage.AbortedByUser then
          Log('Download aborted by user.')
        else
          SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbCriticalError, MB_OK, IDOK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;

  // Skip Ollama download/config page if not selected
  if (PageID = OllamaConfigPage.ID) and (LLMProviderPage.SelectedValueIndex <> 0) then
    Result := True;

  // Skip existing Ollama config page if not selected
  if (PageID = ExistingOllamaConfigPage.ID) and (LLMProviderPage.SelectedValueIndex <> 1) then
    Result := True;

  // Skip LM Studio config page if not selected
  if (PageID = LMStudioConfigPage.ID) and (LLMProviderPage.SelectedValueIndex <> 2) then
    Result := True;
end;

function IsOllamaDownloadSelected: Boolean;
begin
  Result := (LLMProviderPage.SelectedValueIndex = 0);
end;

// Store configuration in registry for the app to use
procedure RegisterPaths;
begin
  // Register LLM provider configuration in HKLM (machine-wide) instead of HKCU (user-specific)
  case LLMProviderPage.SelectedValueIndex of
    0: begin
         // Ollama (new installation)
         RegWriteStringValue(HKLM, 'Software\{#MyAppName}\Config', 'LLMProvider', 'ollama');
         RegWriteStringValue(HKLM, 'Software\{#MyAppName}\Config', 'OllamaAPIPort', OllamaConfigPage.Values[0]);
         RegWriteStringValue(HKLM, 'Software\{#MyAppName}\Config', 'DefaultModel', OllamaConfigPage.Values[1]);
       end;
    1: begin
         // Existing Ollama
         RegWriteStringValue(HKLM, 'Software\{#MyAppName}\Config', 'LLMProvider', 'ollama');
         RegWriteStringValue(HKLM, 'Software\{#MyAppName}\Config', 'OllamaAPIURL', ExistingOllamaConfigPage.Values[0]);
       end;
    2: begin
         // LM Studio
         RegWriteStringValue(HKLM, 'Software\{#MyAppName}\Config', 'LLMProvider', 'lmstudio');
         RegWriteStringValue(HKLM, 'Software\{#MyAppName}\Config', 'LMStudioAPIURL', LMStudioConfigPage.Values[0]);
       end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RegisterPaths;
  end;
end;

function GetOllamaPort(Param: String): String;
begin
  Result := OllamaConfigPage.Values[0];
end;

function GetDefaultModel(Param: String): String;
begin
  Result := OllamaConfigPage.Values[1];
end;

function GetExistingOllamaUrl(Param: String): String;
begin
  Result := ExistingOllamaConfigPage.Values[0];
end;

function GetLMStudioUrl(Param: String): String;
begin
  Result := LMStudioConfigPage.Values[0];
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Check if we're running as admin
  if not IsAdminLoggedOn then
  begin
    MsgBox('This installer requires administrator privileges to install CloudToLocalLLM for all users.' + #13#10 + 
           'Please right-click the installer and select "Run as administrator".', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // Check for /CURRENTUSER parameter and inform it's not supported
  if Pos('/CURRENTUSER', UpperCase(GetCmdTail)) > 0 then
  begin
    MsgBox('This installer only supports installation for all users.' + #13#10 + 
           'The /CURRENTUSER parameter is not supported.', mbInformation, MB_OK);
  end;
end; 