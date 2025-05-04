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
PrivilegesRequiredOverridesAllowed=dialog
OutputBaseFilename=CloudToLocalLLM-Windows-{#MyAppVersion}-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "downloadollama"; Description: "Download and install Ollama"; GroupDescription: "LLM Providers"; Flags: unchecked
Name: "existingollama"; Description: "Configure existing Ollama installation"; GroupDescription: "LLM Providers"; Flags: unchecked
Name: "lmstudio"; Description: "Configure LM Studio"; GroupDescription: "LLM Providers"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Setup-Ollama.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Setup-Ollama.ps1"" -DownloadOnly -OllamaPort '{code:GetOllamaPort}' -DefaultModel '{code:GetDefaultModel}' -ExistingOllamaUrl '{code:GetExistingOllamaUrl}'"; Description: "Setup Ollama"; Flags: runhidden; Tasks: downloadollama
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DownloadPage: TDownloadWizardPage;
  LLMProviderPage: TInputOptionWizardPage;
  OllamaConfigPage: TInputQueryWizardPage;
  LMStudioConfigPage: TInputQueryWizardPage;
  ExistingOllamaConfigPage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
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
begin
  Result := True;

  // Set tasks based on LLM provider selection
  if CurPageID = LLMProviderPage.ID then
  begin
    WizardSelectTasks('!downloadollama,!existingollama,!lmstudio');

    case LLMProviderPage.SelectedValueIndex of
      0: WizardSelectTasks('downloadollama');
      1: WizardSelectTasks('existingollama');
      2: WizardSelectTasks('lmstudio');
    end;
  end;

  // Handle downloading Ollama if selected
  if (CurPageID = wpReady) and WizardIsTaskSelected('downloadollama') then
  begin
    DownloadPage.Clear;
    DownloadPage.Add('https://ollama.com/download/ollama-windows-amd64-v0.1.30.zip', 'ollama.zip', '');
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
  if (PageID = OllamaConfigPage.ID) and not WizardIsTaskSelected('downloadollama') then
    Result := True;

  // Skip existing Ollama config page if not selected
  if (PageID = ExistingOllamaConfigPage.ID) and not WizardIsTaskSelected('existingollama') then
    Result := True;

  // Skip LM Studio config page if not selected
  if (PageID = LMStudioConfigPage.ID) and not WizardIsTaskSelected('lmstudio') then
    Result := True;
end;

// Store configuration in registry for the app to use
procedure RegisterPaths;
begin
  // Register LLM provider configuration
  case LLMProviderPage.SelectedValueIndex of
    0: begin
         // Ollama (new installation)
         RegWriteStringValue(HKCU, 'Software\{#MyAppName}\Config', 'LLMProvider', 'ollama');
         RegWriteStringValue(HKCU, 'Software\{#MyAppName}\Config', 'OllamaAPIPort', OllamaConfigPage.Values[0]);
         RegWriteStringValue(HKCU, 'Software\{#MyAppName}\Config', 'DefaultModel', OllamaConfigPage.Values[1]);
       end;
    1: begin
         // Existing Ollama
         RegWriteStringValue(HKCU, 'Software\{#MyAppName}\Config', 'LLMProvider', 'ollama');
         RegWriteStringValue(HKCU, 'Software\{#MyAppName}\Config', 'OllamaAPIURL', ExistingOllamaConfigPage.Values[0]);
       end;
    2: begin
         // LM Studio
         RegWriteStringValue(HKCU, 'Software\{#MyAppName}\Config', 'LLMProvider', 'lmstudio');
         RegWriteStringValue(HKCU, 'Software\{#MyAppName}\Config', 'LMStudioAPIURL', LMStudioConfigPage.Values[0]);
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
