# Build Windows App with License Verification
# This script builds the Windows version of CloudToLocalLLM with licensing support

# Stop on any error
$ErrorActionPreference = "Stop"

# Parameters for building
param(
    [Parameter(Mandatory=$false)]
    [switch]$KeepAllReleases,
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanupDryRun
)

Write-Host "Building CloudToLocalLLM for Windows with License Verification..." -ForegroundColor Cyan

# Ensure we have all dependencies
Write-Host "Checking and installing Flutter dependencies..." -ForegroundColor Green
flutter pub get

# Run flutter doctor to check setup
flutter doctor -v

# Update pubspec.yaml with necessary licensing dependencies
Write-Host "Ensuring license dependencies are available..." -ForegroundColor Green
$pubspecContent = Get-Content -Path 'pubspec.yaml' -Raw
if (-not ($pubspecContent -match "device_info_plus")) {
    Write-Host "Adding device_info_plus dependency..." -ForegroundColor Yellow
    flutter pub add device_info_plus
}
if (-not ($pubspecContent -match "package_info_plus")) {
    Write-Host "Adding package_info_plus dependency..." -ForegroundColor Yellow
    flutter pub add package_info_plus
}
if (-not ($pubspecContent -match "flutter_secure_storage")) {
    Write-Host "Adding flutter_secure_storage dependency..." -ForegroundColor Yellow
    flutter pub add flutter_secure_storage
}
if (-not ($pubspecContent -match "crypto")) {
    Write-Host "Adding crypto dependency..." -ForegroundColor Yellow
    flutter pub add crypto
}

# Create necessary directories for the build
New-Item -ItemType Directory -Path 'build/windows' -Force | Out-Null

# Build the Windows app
Write-Host "Building Windows application..." -ForegroundColor Green
flutter build windows --release

# Check if build was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Copy license server files to build for development testing
Write-Host "Copying license server mock for testing..." -ForegroundColor Green
$licenseServerDir = "build/windows/runner/Release/license_server"
New-Item -ItemType Directory -Path $licenseServerDir -Force | Out-Null
Copy-Item -Path "cloud/license_server/mock_api.js" -Destination "$licenseServerDir/mock_api.js"
Copy-Item -Path "cloud/license_server/package.json" -Destination "$licenseServerDir/package.json"

# Create InnoSetup installer script
Write-Host "Generating installer script..." -ForegroundColor Green
$innoSetupScript = @"
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
PrivilegesRequired=lowest
OutputBaseFilename=CloudToLocalLLM-Windows-{#MyAppVersion}-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "scripts\utils\Setup-Ollama.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\utils\Setup-Ollama.ps1"" -DownloadOnly -OllamaPort '{code:GetOllamaPort}' -DefaultModel '{code:GetDefaultModel}' -ExistingOllamaUrl '{code:GetExistingOllamaUrl}'"; Description: "Setup Ollama"; Flags: waituntilterminated shellexec; Check: IsOllamaDownloadSelected
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
    
  // If installing for current user only, change the default directory
  if (Pos('/CURRENTUSER', UpperCase(GetCmdTail)) > 0) or not IsAdminLoggedOn then
  begin
    WizardForm.DirEdit.Text := ExpandConstant('{localappdata}\{#MyAppName}');
  end;
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
        // The actual extraction will be handled by scripts\utils\Setup-Ollama.ps1
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

function InitializeSetup(): Boolean;
var
  ErrorCode: Integer;
  IsCurrentUserRequested: Boolean;
begin
  Result := True;
  
  // Check if /CURRENTUSER parameter was passed
  IsCurrentUserRequested := Pos('/CURRENTUSER', UpperCase(GetCmdTail)) > 0;
  
  // Default to user installation if requested via command line
  if IsCurrentUserRequested then
  begin
    // Will be initialized in InitializeWizard
    Exit;
  end;
  
  // If we're not running as admin, let's ask the user if they want to install
  // for all users or just for the current user
  if not IsAdminLoggedOn then
  begin
    case SuppressibleMsgBox(
      'This application can be installed for all users or just for the current user.' + #13#10 + 
      #13#10 +
      'Installing for all users requires administrator privileges.' + #13#10 +
      'Installing for the current user only does not require administrator privileges.' + #13#10 +
      #13#10 +
      'Would you like to install for all users (Yes) or just for yourself (No)?',
      mbConfirmation, MB_YESNOCANCEL, IDNO) of
      IDYES:
        begin
          // Try to elevate with UAC prompt
          if ShellExecute('', 'open', ExpandConstant('{srcexe}'), '/ALLUSERS', '',
             SW_SHOWNORMAL, ewNoWait, ErrorCode) then
          begin
            // Successfully launched elevated instance, terminate this instance
            Result := False;
            Exit;
          end
          else begin
            // Failed to elevate
            SuppressibleMsgBox('Failed to launch elevated installer. ' +
              'You may try running this installer as an administrator.', mbError, MB_OK, IDOK);
            Result := False;
            Exit;
          end;
        end;
      IDNO:
        begin
          // Install for current user only - will be initialized in InitializeWizard
        end;
      IDCANCEL:
        begin
          Result := False;
        end;
    end;
  end;
end;
"@

# Save the InnoSetup script
$innoSetupScript | Out-File -FilePath "CloudToLocalLLM.iss" -Encoding UTF8

# Check if InnoSetup is installed
$innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $innoSetupPath) {
    # Create the release directory if it doesn't exist
    $releasesDir = Join-Path $PSScriptRoot "releases"
    New-Item -ItemType Directory -Path $releasesDir -Force | Out-Null

    # Generate a timestamp for the installer
    $timestamp = Get-Date -Format "yyyyMMddHHmm"
    $outputFile = "CloudToLocalLLM-Windows-$MyAppVersion-$timestamp-Setup.exe"
    $outputPath = Join-Path $releasesDir $outputFile

    # Build the installer
    Write-Host "Building installer..." -ForegroundColor Green
    & iscc /O"$releasesDir" /F"CloudToLocalLLM-Windows-$MyAppVersion-$timestamp-Setup" CloudToLocalLLM.iss

    # Create ZIP archive of the built app
    Write-Host "Creating ZIP archive..." -ForegroundColor Green
    $zipFile = Join-Path $releasesDir "CloudToLocalLLM-Windows-$MyAppVersion.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile -Force
    }
    Compress-Archive -Path "build/windows/x64/runner/Release/*" -DestinationPath $zipFile

    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "Installer: $outputPath" -ForegroundColor Cyan
    Write-Host "ZIP archive: $zipFile" -ForegroundColor Cyan

    # Clean up old releases if not keeping all
    if (-not $KeepAllReleases) {
        Write-Host "Cleaning up old releases..." -ForegroundColor Yellow
        
        $cleanupParams = @{
            PreserveRegular = $true
            KeepLatestBuild = $true
        }
        
        if ($CleanupDryRun) {
            $cleanupParams.Add("DryRun", $true)
        }
        
        & "$PSScriptRoot\scripts\release\clean_releases.ps1" @cleanupParams
    }
} else {
    Write-Host "InnoSetup not found. Please install InnoSetup to build the installer." -ForegroundColor Yellow
    Write-Host "Skipping installer creation..." -ForegroundColor Yellow
}

# Update release documentation
$releaseNotes = @"
# CloudToLocalLLM Windows Release v1.3.0

## What's New
- Added dual licensing system
- AGPLv3 open source license for free version
- Commercial licensing options for enhanced features
- Secure license verification with phone-home system
- Free 30-day trial available

## Features by License Tier
- **Trial**: 30-day access to all features
- **Free**: Basic features, single container
- **Developer**: Multiple containers, enhanced models
- **Professional**: Team collaboration, API access
- **Enterprise**: Custom domains, unlimited containers, SSO

## System Requirements
- Windows 10/11 (64-bit)
- 8GB RAM minimum (16GB recommended)
- 1GB free disk space for application
- Internet connection for license verification

## Installation
Run the installer and follow the prompts.
"@

$releaseNotes | Out-File -FilePath "WINDOWS_RELEASE_NOTES.md" -Encoding UTF8

Write-Host "Release notes generated at WINDOWS_RELEASE_NOTES.md" -ForegroundColor White 
