# Build Android App with License Verification
# This script builds the Android version of CloudToLocalLLM with licensing support

# Stop on any error
$ErrorActionPreference = "Stop"

Write-Host "Building CloudToLocalLLM for Android with License Verification..." -ForegroundColor Cyan

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

# Check if keystore exists, if not create one
$keystorePath = "android/app/keystore.jks"
if (-not (Test-Path $keystorePath)) {
    Write-Host "Keystore not found. Creating new keystore..." -ForegroundColor Yellow
    
    # Generate keystore password
    $keystorePassword = -join ((65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})
    $keyPassword = $keystorePassword
    
    # Create keystore directory if it doesn't exist
    New-Item -ItemType Directory -Path "android/app" -Force | Out-Null
    
    # Generate keystore using keytool
    $keytoolArgs = @(
        "-genkey",
        "-v",
        "-keystore", $keystorePath,
        "-alias", "upload",
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", "10000",
        "-storepass", $keystorePassword,
        "-keypass", $keyPassword,
        "-dname", "CN=CloudToLocalLLM, OU=Development, O=CloudToLocalLLM, L=Unknown, S=Unknown, C=US"
    )
    
    & keytool $keytoolArgs
    
    # Create key.properties file
    $keyPropertiesContent = @"
storePassword=$keystorePassword
keyPassword=$keyPassword
keyAlias=upload
storeFile=keystore.jks
"@
    
    $keyPropertiesContent | Out-File -FilePath "android/key.properties" -Encoding UTF8
    
    Write-Host "Keystore created at $keystorePath" -ForegroundColor Green
    Write-Host "Key properties file created at android/key.properties" -ForegroundColor Green
    Write-Host "IMPORTANT: Keep your keystore password safe: $keystorePassword" -ForegroundColor Yellow
}

# Update build.gradle to use signing config
$buildGradlePath = "android/app/build.gradle"
$buildGradleContent = Get-Content -Path $buildGradlePath -Raw

if (-not ($buildGradleContent -match "signingConfigs")) {
    Write-Host "Updating build.gradle with signing configuration..." -ForegroundColor Green
    
    $signingConfigSection = @"
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
"@
    
    $signingConfigSection2 = @"
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
"@
    
    $buildGradleContent = $buildGradleContent -replace "android {", $signingConfigSection
    $buildGradleContent = $buildGradleContent -replace "buildTypes {(\s+)release {", $signingConfigSection2
    
    $buildGradleContent | Out-File -FilePath $buildGradlePath -Encoding UTF8
}

# Update app icon with the proper branding
Write-Host "Ensuring app has proper branding..." -ForegroundColor Green

# Update app name in strings.xml
$stringsXmlPath = "android/app/src/main/res/values/strings.xml"
if (-not (Test-Path $stringsXmlPath)) {
    New-Item -ItemType Directory -Path "android/app/src/main/res/values" -Force | Out-Null
    @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">CloudToLocalLLM</string>
</resources>
"@ | Out-File -FilePath $stringsXmlPath -Encoding UTF8
}

# Build APK
Write-Host "Building APK..." -ForegroundColor Green
flutter build apk --release

# Check if build was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build APK failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Build App Bundle (for Google Play submission)
Write-Host "Building App Bundle..." -ForegroundColor Green
flutter build appbundle --release

# Check if build was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build AppBundle failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Create release directory if it doesn't exist
New-Item -ItemType Directory -Path "releases" -Force | Out-Null

# Copy APK to releases directory
Copy-Item -Path "build/app/outputs/flutter-apk/app-release.apk" -Destination "releases/CloudToLocalLLM-1.3.0.apk"

# Copy AAB to releases directory
Copy-Item -Path "build/app/outputs/bundle/release/app-release.aab" -Destination "releases/CloudToLocalLLM-1.3.0.aab"

Write-Host "Android build completed successfully!" -ForegroundColor Green
Write-Host "Release files available at:" -ForegroundColor Cyan
Write-Host " - APK: releases/CloudToLocalLLM-1.3.0.apk" -ForegroundColor White
Write-Host " - App Bundle: releases/CloudToLocalLLM-1.3.0.aab" -ForegroundColor White

# Update release documentation
$releaseNotes = @"
# CloudToLocalLLM Android Release v1.3.0

## What's New
- First Android release of CloudToLocalLLM
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
- Android 6.0 (API level 23) or higher
- 4GB RAM minimum (8GB recommended)
- 500MB free storage space
- Internet connection for license verification

## Installation
1. Enable installation from unknown sources in your device settings
2. Download and install the APK
3. Launch the app and follow the onboarding process
"@

$releaseNotes | Out-File -FilePath "ANDROID_RELEASE_NOTES.md" -Encoding UTF8

Write-Host "Release notes generated at ANDROID_RELEASE_NOTES.md" -ForegroundColor White 