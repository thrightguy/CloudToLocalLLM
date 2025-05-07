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
PrivilegesRequiredOverridesAllowed=dialog commandline
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
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\utils\Setup-Ollama.ps1"" -AutoSetup"; Description: "Setup Ollama"; Flags: waituntilterminated shellexec 
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  ErrorCode: Integer;
begin
  Result := True;
  
  // If we're not running as admin and not explicitly asked for current user, ask user what they want
  if not IsAdminLoggedOn and (Pos('/CURRENTUSER', UpperCase(GetCmdTail)) = 0) then
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

procedure InitializeWizard;
begin
  // If installing for current user only, change the default directory
  if (Pos('/CURRENTUSER', UpperCase(GetCmdTail)) > 0) or not IsAdminLoggedOn then
  begin
    WizardForm.DirEdit.Text := ExpandConstant('{localappdata}\{#MyAppName}');
  end;
end; 
