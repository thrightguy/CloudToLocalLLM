# Windows App Improvement Script

# Function to create Windows installer
function New-WindowsInstaller {
    param (
        [string]$OutputPath,
        [string]$AppName,
        [string]$Version
    )
    
    Write-Host "Creating Windows installer for version $Version..."
    
    # Build the Windows app
    Write-Host "Building Windows app..."
    flutter build windows
    
    # Create installer directory
    $installerDir = "installer"
    if (-not (Test-Path $installerDir)) {
        New-Item -ItemType Directory -Force -Path $installerDir
    }
    
    # Create Inno Setup script
    $issContent = @"
#define MyAppName "CloudToLocalLLM"
#define MyAppVersion "$Version"
#define MyAppPublisher "Your Company"
#define MyAppURL "https://yourwebsite.com"
#define MyAppExeName "cloudtolocalllm.exe"

[Setup]
AppId={{YOUR-APP-ID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=LICENSE
OutputDir=installer
OutputBaseFilename=CloudToLocalLLM-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
"@
    
    $issContent | Out-File -FilePath "$installerDir\CloudToLocalLLM.iss" -Encoding UTF8
    
    # Build the installer
    Write-Host "Building installer..."
    & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "$installerDir\CloudToLocalLLM.iss"
    
    Write-Host "Installer created successfully!"
}

# Function to add Windows-specific features
function Add-WindowsFeatures {
    Write-Host "Adding Windows-specific features..."
    
    # Add system tray support
    $trayCode = @"
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayManager {
  static final SystemTray _systemTray = SystemTray();
  static final AppWindow _appWindow = AppWindow();

  static Future<void> initialize() async {
    await _systemTray.initSystemTray(
      title: "CloudToLocalLLM",
      iconPath: "assets/images/app_icon.ico",
    );

    final menu = [
      MenuItem(
        label: 'Show',
        onClicked: () => _appWindow.show(),
      ),
      MenuItem(
        label: 'Hide',
        onClicked: () => _appWindow.hide(),
      ),
      MenuSeparator(),
      MenuItem(
        label: 'Exit',
        onClicked: () => _appWindow.close(),
      ),
    ];

    await _systemTray.setContextMenu(menu);
  }
}
"@
    
    # Create the system tray manager file
    $trayCode | Out-File -FilePath "lib/windows/system_tray_manager.dart" -Encoding UTF8
    
    # Add Windows notifications support
    $notificationsCode = @"
import 'package:win32/win32.dart';

class WindowsNotifications {
  static void showNotification(String title, String message) {
    final notification = ToastNotificationManager.createToastNotifier();
    final template = ToastNotificationManager.getTemplateContent(
      ToastTemplateType.toastText02,
    );
    
    template.getElementsByTagName('text')[0].appendChild(
      template.createTextNode(title),
    );
    template.getElementsByTagName('text')[1].appendChild(
      template.createTextNode(message),
    );
    
    notification.show(template);
  }
}
"@
    
    # Create the notifications file
    $notificationsCode | Out-File -FilePath "lib/windows/windows_notifications.dart" -Encoding UTF8
    
    Write-Host "Windows features added successfully!"
}

# Main script execution
$version = "1.2.0"  # Update this version number as needed

Write-Host "Starting Windows app improvements..."
New-WindowsInstaller -OutputPath $version -AppName CloudToLocalLLM -Version $version
Add-WindowsFeatures

Write-Host "Windows app improvements completed!"
Write-Host "Next steps:"
Write-Host "1. Update pubspec.yaml with new dependencies"
Write-Host "2. Test the new features"
Write-Host "3. Create a new release on GitHub" 