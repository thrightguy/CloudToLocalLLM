# CloudToLocalLLM v3.2.1 Application Building Guide

## Overview

This document provides comprehensive procedures for building CloudToLocalLLM v3.2.1 with the corrected architecture that removes the incorrect external Python settings application and implements the unified Flutter settings interface.

## Prerequisites

### Required Software Versions
- **Flutter**: 3.24.0 or higher
- **Python**: 3.10+ with pip
- **PyInstaller**: 6.0+ 
- **Git**: 2.30+
- **Linux**: Ubuntu 20.04+ / Manjaro / Arch Linux

### Verification Commands
```bash
flutter --version  # Should show 3.24.0+
python3 --version  # Should show 3.10+
pip3 show pyinstaller  # Should show 6.0+
git --version  # Should show 2.30+
```

## Version Management

### 1. Version Increment (3.2.0 → 3.2.1)

**Update pubspec.yaml (Single Source of Truth):**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Backup current version
cp pubspec.yaml pubspec.yaml.backup

# Update version in pubspec.yaml
sed -i 's/version: 3\.2\.0+[0-9]*/version: 3.2.1+1/' pubspec.yaml

# Verify version change
grep "version:" pubspec.yaml
# Expected output: version: 3.2.1+1
```

**Verification Checkpoint ✅:**
- [ ] pubspec.yaml shows version: 3.2.1+1
- [ ] Backup file created successfully
- [ ] No other version references in codebase

### 2. Flutter Desktop Build Process

**Clean Previous Builds:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Clean Flutter cache and previous builds
flutter clean
rm -rf build/
rm -rf .dart_tool/

# Get dependencies
flutter pub get
```

**Configure Flutter for Linux Desktop:**
```bash
# Enable Linux desktop support
flutter config --enable-linux-desktop

# Verify desktop support enabled
flutter config
# Should show: enable-linux-desktop: true
```

**Build Release Version:**
```bash
# Build Linux desktop application
flutter build linux --release --verbose

# Verify build success
echo "Build exit code: $?"
# Expected: Build exit code: 0
```

**Build Artifact Verification:**
```bash
# Check build output structure
ls -la build/linux/x64/release/bundle/

# Verify main executable exists
test -f build/linux/x64/release/bundle/cloudtolocalllm && echo "✅ Main executable found" || echo "❌ Main executable missing"

# Verify Flutter assets
test -d build/linux/x64/release/bundle/data && echo "✅ Flutter data found" || echo "❌ Flutter data missing"

# Critical: Verify NO external settings app
test ! -f build/linux/x64/release/bundle/cloudtolocalllm-settings && echo "✅ No external settings app (correct)" || echo "❌ External settings app found (incorrect)"
```

**Verification Checkpoint ✅:**
- [ ] Flutter build completed without errors
- [ ] Main executable `cloudtolocalllm` exists
- [ ] Flutter data directory present
- [ ] **CRITICAL**: No `cloudtolocalllm-settings` executable found
- [ ] Build size approximately 19MB (Flutter app only)

## Python Tray Daemon Compilation

### 3. Tray Daemon Dependencies

**Install Required Python Packages:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM/tray_daemon

# Install dependencies in user space
pip3 install --user -r requirements.txt
pip3 install --user pyinstaller

# Verify installations
pip3 show pystray Pillow psutil aiohttp pyinstaller
```

**Dependency Verification:**
```bash
# Test Python imports
python3 -c "import pystray, PIL, psutil, aiohttp; print('✅ All dependencies available')"
```

### 4. Enhanced Tray Daemon Build

**Build Tray Daemon Only (No Settings App):**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM/tray_daemon

# Clean previous builds
rm -rf build/ dist/ *.spec

# Build enhanced tray daemon ONLY
pyinstaller --onefile \
    --name cloudtolocalllm-enhanced-tray \
    --hidden-import pystray._xorg \
    --console \
    enhanced_tray_daemon.py

# Verify build success
echo "PyInstaller exit code: $?"
# Expected: PyInstaller exit code: 0
```

**Tray Daemon Verification:**
```bash
# Check build output
ls -la dist/

# Verify tray daemon executable
test -f dist/cloudtolocalllm-enhanced-tray && echo "✅ Tray daemon built" || echo "❌ Tray daemon missing"

# Critical: Verify NO settings app built
test ! -f dist/cloudtolocalllm-settings && echo "✅ No settings app built (correct)" || echo "❌ Settings app built (incorrect)"

# Test tray daemon execution (quick test)
timeout 5s ./dist/cloudtolocalllm-enhanced-tray --help || echo "Tray daemon help test completed"
```

**Verification Checkpoint ✅:**
- [ ] PyInstaller completed without errors
- [ ] `cloudtolocalllm-enhanced-tray` executable exists
- [ ] **CRITICAL**: No `cloudtolocalllm-settings` executable built
- [ ] Tray daemon size approximately 15-20MB
- [ ] Help command executes without immediate crashes

### 5. Tray Daemon Scope Verification

**Verify Tray Daemon Functions (System Tray Only):**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM/tray_daemon

# Check tray daemon source for correct scope
grep -n "settings_app\|external.*settings\|launch.*settings" enhanced_tray_daemon.py || echo "✅ No external settings references found"

# Verify tray daemon only handles tray functions
grep -n "show\|hide\|quit\|tray\|icon" enhanced_tray_daemon.py | head -5
# Should show tray-related functions only
```

**Verification Checkpoint ✅:**
- [ ] No references to external settings applications in tray daemon
- [ ] Tray daemon contains only system tray functions (show/hide/quit)
- [ ] No settings management code in tray daemon

## Cross-Platform Testing

### 6. Flutter Settings Screen Functionality

**Test Flutter Settings Screen:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Launch application for testing
./build/linux/x64/release/bundle/cloudtolocalllm &
APP_PID=$!

# Wait for app to start
sleep 3

# Test settings screen accessibility (manual verification required)
echo "🧪 Manual Test Required:"
echo "1. Navigate to Settings screen in the app"
echo "2. Verify all settings sections are present:"
echo "   - Appearance (Theme, Notifications)"
echo "   - LLM Provider (Provider selection, Configure & Test Connection)"
echo "   - System Tray (Status indicator, Start Minimized, Close to Tray)"
echo "   - Cloud & Sync (Basic sync info, Premium features)"
echo "   - Application Information (Version, Build date)"
echo "3. Verify NO 'Advanced Settings' or 'Launch Settings App' buttons"
echo "4. Test all switches and dropdowns work correctly"

# Kill test app
kill $APP_PID 2>/dev/null || true
```

**Verification Checkpoint ✅:**
- [ ] Settings screen accessible from main app
- [ ] All settings sections present and functional
- [ ] **CRITICAL**: No external settings app launch buttons
- [ ] All controls (switches, dropdowns) work correctly
- [ ] Settings persist between app restarts

### 7. Binary Size Validation

**Unified Package Size Check:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Calculate total package size
FLUTTER_SIZE=$(du -sm build/linux/x64/release/bundle | cut -f1)
TRAY_SIZE=$(du -sm tray_daemon/dist/cloudtolocalllm-enhanced-tray | cut -f1)
TOTAL_SIZE=$((FLUTTER_SIZE + TRAY_SIZE))

echo "📦 Package Size Analysis:"
echo "Flutter Bundle: ${FLUTTER_SIZE}MB"
echo "Tray Daemon: ${TRAY_SIZE}MB"
echo "Total Package: ${TOTAL_SIZE}MB"

# Verify size is within expected range (120-130MB)
if [ $TOTAL_SIZE -ge 120 ] && [ $TOTAL_SIZE -le 130 ]; then
    echo "✅ Package size within expected range (120-130MB)"
else
    echo "⚠️ Package size outside expected range: ${TOTAL_SIZE}MB"
fi
```

**Verification Checkpoint ✅:**
- [ ] Total package size between 120-130MB
- [ ] Flutter bundle approximately 19MB
- [ ] Tray daemon approximately 15-20MB
- [ ] No unexpected large files included

## Final Build Verification

### 8. Complete Architecture Verification

**Final Architecture Check:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

echo "🔍 Final Architecture Verification:"

# 1. Flutter app contains integrated settings
grep -r "_launchTraySettings\|cloudtolocalllm-settings" lib/ && echo "❌ External settings references found" || echo "✅ No external settings references"

# 2. No external settings executables
find . -name "*settings*" -type f -executable | grep -v ".git" && echo "❌ Settings executables found" || echo "✅ No settings executables found"

# 3. Tray daemon scope correct
grep -c "def.*settings\|settings.*def" tray_daemon/enhanced_tray_daemon.py && echo "❌ Settings functions in tray daemon" || echo "✅ Tray daemon scope correct"

# 4. Build artifacts correct
echo "Build artifacts:"
echo "  Flutter: $(test -f build/linux/x64/release/bundle/cloudtolocalllm && echo "✅" || echo "❌")"
echo "  Tray: $(test -f tray_daemon/dist/cloudtolocalllm-enhanced-tray && echo "✅" || echo "❌")"
echo "  No Settings App: $(test ! -f tray_daemon/dist/cloudtolocalllm-settings && echo "✅" || echo "❌")"
```

**Final Verification Checkpoint ✅:**
- [ ] No external settings references in Flutter code
- [ ] No settings executables in build artifacts
- [ ] Tray daemon contains only tray functions
- [ ] All required build artifacts present
- [ ] Architecture corrections successfully implemented

## Troubleshooting

### Common Issues During Architecture Transition

**Issue 1: Flutter build fails with settings references**
```bash
# Solution: Clean and rebuild
flutter clean
flutter pub get
flutter build linux --release
```

**Issue 2: PyInstaller fails with missing dependencies**
```bash
# Solution: Reinstall dependencies
pip3 install --user --force-reinstall pystray Pillow psutil aiohttp pyinstaller
```

**Issue 3: Tray daemon includes settings functions**
```bash
# Solution: Verify correct source file
cd tray_daemon
grep -n "settings" enhanced_tray_daemon.py
# Should only show configuration loading, not settings management
```

**Issue 4: Package size too large**
```bash
# Solution: Check for unnecessary files
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} +
```

## Next Steps

After completing this build process:
1. Proceed to [Release Management](02-release-management.md)
2. Follow [AUR Publication](03-aur-publication.md)
3. Verify deployment success across GitHub and AUR channels

## Security Notes

- All builds run as non-root user
- No elevated permissions required
- Build artifacts contain no sensitive information
- Tray daemon runs with minimal system access
