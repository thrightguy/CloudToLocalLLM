# Build Windows App with License Verification
# This script builds the Windows version of CloudToLocalLLM with licensing support

# Stop on any error
$ErrorActionPreference = "Stop"

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
#define MyAppExeName "cloudtolocalllm.exe"

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

[Files]
Source: "build\windows\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "setup_ollama.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  DownloadPage: TDownloadWizardPage;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
end;
"@

# Save the InnoSetup script
$innoSetupScript | Out-File -FilePath "CloudToLocalLLM.iss" -Encoding UTF8

# Check if InnoSetup is installed
$innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $innoSetupPath) {
    # Build the installer
    Write-Host "Building installer..." -ForegroundColor Green
    & $innoSetupPath "CloudToLocalLLM.iss"
} else {
    Write-Host "InnoSetup not found. Please install InnoSetup to build the installer." -ForegroundColor Yellow
    Write-Host "Skipping installer creation..." -ForegroundColor Yellow
}

# Create a ZIP release package
Write-Host "Creating ZIP release package..." -ForegroundColor Green
$releaseFileName = "CloudToLocalLLM-Windows-1.3.0.zip"
$sourcePath = "build/windows/runner/Release/*"
$destinationPath = $releaseFileName

# Create release directory if it doesn't exist
New-Item -ItemType Directory -Path "releases" -Force | Out-Null

# Create the ZIP file
Compress-Archive -Path $sourcePath -DestinationPath "releases/$releaseFileName" -Force

Write-Host "Windows build completed successfully!" -ForegroundColor Green
Write-Host "Release files available at:" -ForegroundColor Cyan
Write-Host " - Installer: CloudToLocalLLM-Windows-1.3.0-Setup.exe (if InnoSetup was available)" -ForegroundColor White
Write-Host " - ZIP Package: releases/$releaseFileName" -ForegroundColor White

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