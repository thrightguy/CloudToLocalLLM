# CloudToLocalLLM Flutter Development Setup Script
# This script sets up the environment for Flutter development on Windows

Write-Host "🚀 CloudToLocalLLM Flutter Development Setup" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Set Flutter path for current session
$env:PATH = "C:\tools\flutter_new\flutter\bin;$env:PATH"

Write-Host "✅ Flutter path added to current session" -ForegroundColor Green

# Check Flutter version
Write-Host "`n📋 Flutter Version:" -ForegroundColor Cyan
& flutter --version

# Check if Developer Mode is enabled
Write-Host "`n🔧 Checking Developer Mode..." -ForegroundColor Cyan
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if ($devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
    Write-Host "✅ Developer Mode is enabled" -ForegroundColor Green
} else {
    Write-Host "⚠️  Developer Mode is not enabled. Please enable it in Settings > Update & Security > For developers" -ForegroundColor Yellow
    Write-Host "   You can open the settings with: start ms-settings:developers" -ForegroundColor Yellow
}

# Run Flutter doctor
Write-Host "`n🏥 Flutter Doctor:" -ForegroundColor Cyan
& flutter doctor

Write-Host "`n📝 Setup Summary:" -ForegroundColor Cyan
Write-Host "- Flutter 3.34.0-beta with Dart 3.9.0 installed" -ForegroundColor White
Write-Host "- Location: C:\tools\flutter_new\flutter" -ForegroundColor White
Write-Host "- Chrome available for web development" -ForegroundColor White
Write-Host "- VS Code available for development" -ForegroundColor White

Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Enable Developer Mode if not already enabled" -ForegroundColor White
Write-Host "2. Install Visual Studio C++ components for Windows development (optional)" -ForegroundColor White
Write-Host "3. Run 'flutter pub get' in the CloudToLocalLLM project directory" -ForegroundColor White
Write-Host "4. Run 'flutter run -d chrome' to start web development" -ForegroundColor White

Write-Host "`n🔧 Useful Commands:" -ForegroundColor Cyan
Write-Host "- flutter pub get          # Install dependencies" -ForegroundColor White
Write-Host "- flutter run -d chrome    # Run on Chrome (web)" -ForegroundColor White
Write-Host "- flutter run -d windows   # Run on Windows (desktop)" -ForegroundColor White
Write-Host "- flutter build web        # Build for web deployment" -ForegroundColor White
Write-Host "- flutter doctor -v        # Detailed system check" -ForegroundColor White

Write-Host "`n✨ Flutter setup complete! Happy coding! ✨" -ForegroundColor Green
