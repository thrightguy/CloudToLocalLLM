# Windows App Improvement Script

# Function to find Inno Setup Compiler (ISCC.exe)
function Find-InnoSetupCompiler {
    $commonPaths = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup\ISCC.exe",
        "C:\Program Files\Inno Setup\ISCC.exe"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Host "Found Inno Setup Compiler at: $path" -ForegroundColor Green
            return $path
        }
    }

    # Try PATH
    $isccInPath = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($isccInPath) {
        Write-Host "Found Inno Setup Compiler in PATH: $($isccInPath.Source)" -ForegroundColor Green
        return $isccInPath.Source
    }

    Write-Host "ERROR: Inno Setup Compiler (ISCC.exe) not found in common locations or PATH." -ForegroundColor Red
    Write-Host "Please install Inno Setup 6 from https://jrsoftware.org/isinfo.php and ensure ISCC.exe is accessible."
    return $null
}

# Function to get version from pubspec.yaml
function Get-AppVersion {
    param (
        [string]$PubspecPath = "pubspec.yaml"
    )
    try {
        if (-not (Test-Path $PubspecPath)) {
            Write-Host "WARNING: $PubspecPath not found. Using default version." -ForegroundColor Yellow
            return "1.0.0" # Default version if pubspec is not found
        }
        $pubspecContent = Get-Content $PubspecPath -Raw
        $versionLine = $pubspecContent | Select-String -Pattern "^version:\s*([^\s+]+)"
        if ($versionLine -and $versionLine.Matches[0].Groups[1].Value) {
            $appVersion = $versionLine.Matches[0].Groups[1].Value
            Write-Host "Found version $appVersion in $PubspecPath" -ForegroundColor Green
            return $appVersion
        } else {
            Write-Host "WARNING: Could not parse version from $PubspecPath. Using default version." -ForegroundColor Yellow
            return "1.0.0"
        }
    } catch {
        Write-Host "ERROR reading or parsing $PubspecPath: $_. Using default version." -ForegroundColor Red
        return "1.0.0"
    }
}

# Function to create Windows installer
function New-WindowsInstaller {
    param (
        [string]$OutputPath,
        [string]$AppName,
        [string]$Version,
        [string]$AppExeName
    )
    
    $isccPath = Find-InnoSetupCompiler
    if (-not $isccPath) {
        exit 1
    }

    Write-Host "Creating Windows installer for $AppName version $Version..."
    
    # Build the Windows app
    Write-Host "Building Windows app..."
    flutter build windows
    
    # Create installer directory
    $installerDir = "installer"
    if (-not (Test-Path $installerDir)) {
        New-Item -ItemType Directory -Force -Path $installerDir
    }
    
    # Create Inno Setup script
    $issAppId = [guid]::NewGuid().ToString()
    $issContent = @"
#define MyAppName "$AppName"
#define MyAppVersion "$Version"
#define MyAppPublisher "CloudToLocalLLM Inc."
#define MyAppURL "https://cloudtolocalllm.online"
#define MyAppExeName "$AppExeName"

[Setup]
AppId={$issAppId}
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
    Write-Host "Building installer using $isccPath..."
    & $isccPath "$installerDir\CloudToLocalLLM.iss"
    
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
# $version = "1.2.0"  # Update this version number as needed - Now read from pubspec
$appVersion = Get-AppVersion
$appName = "CloudToLocalLLM"
$appExeName = "cloudtolocalllm.exe" # Assumes this is the executable name

Write-Host "Starting Windows app improvements..."
New-WindowsInstaller -OutputPath $appVersion -AppName $appName -Version $appVersion -AppExeName $appExeName
Add-WindowsFeatures

Write-Host "Windows app improvements completed!"
Write-Host "Next steps:"
Write-Host "1. Update pubspec.yaml with new dependencies"
Write-Host "2. Test the new features"
Write-Host "3. Create a new release on GitHub" 