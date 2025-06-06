# CloudToLocalLLM v3.2.1 Release Management Guide

## Overview

This document provides comprehensive procedures for managing the release of CloudToLocalLLM v3.2.1, focusing on the architecture correction deployment through GitHub primary distribution and VPS deployment verification.

## Prerequisites

### Required Access and Tools
- **GitHub Account**: imrightguy with repository access
- **VPS Access**: cloudllm@cloudtolocalllm.online SSH access
- **Git Configuration**: Proper SSH keys for GitHub
- **GitHub CLI**: gh command-line tool for releases

### Verification Commands
```bash
# Verify GitHub SSH access
ssh -T git@github.com
# Expected: Hi imrightguy! You've successfully authenticated

# Verify VPS access
ssh cloudllm@cloudtolocalllm.online "echo 'VPS access confirmed'"
# Expected: VPS access confirmed

# Verify Git configuration
git config --global user.name
git config --global user.email

# Verify GitHub CLI
gh auth status
# Expected: Logged in to github.com as imrightguy
```

## Git Workflow

### 1. Branch Creation and Preparation

**Create Release Branch:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Ensure we're on master and up to date
git checkout master
git pull origin master

# Create release branch
git checkout -b release/v3.2.1

# Verify branch creation
git branch --show-current
# Expected: release/v3.2.1
```

**Commit Architecture Corrections:**
```bash
# Stage all architecture correction changes
git add lib/screens/settings_screen.dart
git add packaging/aur/PKGBUILD
git add pubspec.yaml

# Verify staged changes
git status
# Should show modified files related to architecture corrections

# Commit with descriptive message
git commit -m "fix: Remove external Python settings app, implement unified Flutter settings

- Remove _launchTraySettings() function from Flutter settings screen
- Eliminate external cloudtolocalllm-settings application building
- Update AUR PKGBUILD to remove settings app compilation
- Implement in-app system tray settings (Start Minimized, Close to Tray)
- Clean up unused imports and functions
- Maintain universal settings interface for desktop and web

Fixes: Architecture confusion between external and integrated settings
Version: 3.2.1 (patch release for critical architecture bugfix)"
```

**Verification Checkpoint ✅:**
- [ ] Release branch created successfully
- [ ] All architecture correction files staged
- [ ] Commit message follows conventional commit format
- [ ] Changes focused on architecture corrections only

### 2. Tag Creation

**Create Release Tag:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Create annotated tag for v3.2.1
git tag -a v3.2.1 -m "CloudToLocalLLM v3.2.1 - Architecture Correction Release

Critical Bugfixes:
- Removed incorrect external Python settings application
- Implemented unified Flutter settings interface
- Corrected system tray daemon scope (tray functions only)
- Updated build scripts to reflect correct architecture

Architecture Changes:
- Flutter settings screen: Integrated all settings management
- Python tray daemon: System tray functionality only (show/hide/quit)
- Build process: No external settings app compilation
- Package distribution: Simplified unified architecture

This patch release resolves architecture confusion and provides
a clean, maintainable settings interface within the Flutter application."

# Verify tag creation
git tag -l v3.2.1
# Expected: v3.2.1

# Show tag details
git show v3.2.1 --stat
```

**Verification Checkpoint ✅:**
- [ ] Tag v3.2.1 created with detailed message
- [ ] Tag points to correct commit with architecture fixes
- [ ] Tag message explains architecture corrections clearly

## GitHub Primary Distribution

### 3. GitHub Repository Management

**Push to GitHub (Primary):**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Verify GitHub remote exists
git remote -v
# Should show origin pointing to GitHub

# Push release branch to GitHub
git push origin release/v3.2.1

# Push tag to GitHub
git push origin v3.2.1

# Push to master (after merge)
git checkout master
git merge release/v3.2.1 --no-ff -m "Merge release/v3.2.1: Architecture correction deployment"
git push origin master
```

**Verification Checkpoint ✅:**
- [ ] Release branch pushed to GitHub successfully
- [ ] Tag v3.2.1 pushed to GitHub
- [ ] Master branch updated with architecture corrections
- [ ] GitHub repository is primary source of truth

### 4. Binary Distribution via GitHub Releases

**Create Distribution Archive:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

# Create distribution directory
mkdir -p dist/v3.2.1

# Copy Flutter bundle
cp -r build/linux/x64/release/bundle dist/v3.2.1/cloudtolocalllm-bundle

# Copy tray daemon
cp tray_daemon/dist/cloudtolocalllm-enhanced-tray dist/v3.2.1/

# Copy essential files
cp README.md CHANGELOG.md LICENSE dist/v3.2.1/

# Create unified archive
cd dist/v3.2.1
tar -czf cloudtolocalllm-3.2.1-x86_64.tar.gz *
cd ../..

# Verify archive contents
tar -tzf dist/v3.2.1/cloudtolocalllm-3.2.1-x86_64.tar.gz | head -10

# Check archive size
ls -lh dist/v3.2.1/cloudtolocalllm-3.2.1-x86_64.tar.gz
# Expected: ~125MB
```

**Create GitHub Release:**
```bash
# Create GitHub release with binary
gh release create v3.2.1 \
  --title "CloudToLocalLLM v3.2.1 - Architecture Correction Release" \
  --notes-file RELEASE_NOTES_v3.2.1.md \
  --target master \
  dist/v3.2.1/cloudtolocalllm-3.2.1-x86_64.tar.gz

# Verify release creation
gh release view v3.2.1
# Should show release details and attached binary
```

**Verification Checkpoint ✅:**
- [ ] Distribution archive created successfully
- [ ] Archive size approximately 125MB
- [ ] Archive contains Flutter bundle and tray daemon only
- [ ] **CRITICAL**: No cloudtolocalllm-settings in archive
- [ ] GitHub release created with binary attachment

### 5. GitHub Release Verification

**Verify GitHub Release:**
```bash
# Check GitHub repository status
curl -s https://api.github.com/repos/imrightguy/CloudToLocalLLM/tags | jq -r '.[0].name'
# Expected: v3.2.1

# Verify GitHub has latest commits
curl -s https://api.github.com/repos/imrightguy/CloudToLocalLLM/commits/master | jq -r '.commit.message' | head -1
# Should show recent architecture correction commit

# Verify release assets
gh release view v3.2.1 --json assets --jq '.assets[].name'
# Expected: cloudtolocalllm-3.2.1-x86_64.tar.gz
```

**Download and Verify Release:**
```bash
# Test download from GitHub release
curl -L -o /tmp/test-download.tar.gz \
  "https://github.com/imrightguy/CloudToLocalLLM/releases/download/v3.2.1/cloudtolocalllm-3.2.1-x86_64.tar.gz"

# Verify download integrity
ls -lh /tmp/test-download.tar.gz
# Should match original archive size

# Clean up test download
rm /tmp/test-download.tar.gz
```

**Verification Checkpoint ✅:**
- [ ] GitHub repository contains v3.2.1 tag
- [ ] Latest commits reflect architecture corrections
- [ ] GitHub release created with binary assets
- [ ] Release download works correctly

## Release Notes Template

### 6. Release Notes Creation

**Create Release Notes:**
```bash
cd /home/rightguy/Dev/CloudToLocalLLM

cat > RELEASE_NOTES_v3.2.1.md << 'EOF'
# CloudToLocalLLM v3.2.1 - Architecture Correction Release

## 🔧 Critical Architecture Bugfixes

### Settings Interface Unification
- **Removed incorrect external Python settings application**
- **Implemented unified Flutter settings interface**
- All settings now accessible within the main application
- Eliminated confusion between external and integrated settings

### System Tray Daemon Scope Correction
- Python tray daemon now provides **only system tray functionality**
- Removed settings management from tray daemon
- Simplified tray operations: show/hide/quit application
- Improved crash isolation between components

### Build Process Corrections
- Eliminated building of external `cloudtolocalllm-settings` executable
- Updated AUR PKGBUILD to remove settings app compilation
- Removed unnecessary launcher scripts
- Streamlined package distribution

## 🎯 User Impact

### For Existing Users
- **Settings location changed**: All settings now in main app Settings screen
- **No external settings app**: Remove any shortcuts to `cloudtolocalllm-settings`
- **Simplified workflow**: Single application for all configuration needs
- **Improved reliability**: Reduced component complexity

### For New Users
- **Intuitive settings access**: Settings available in main application menu
- **Unified experience**: Same settings interface on desktop and web
- **Simplified installation**: Fewer components to manage

## 📦 Distribution Changes

### Package Contents
- Flutter desktop application with integrated settings
- Python system tray daemon (tray functions only)
- **Removed**: External settings application and launchers
- **Maintained**: ~125MB unified package size

### Installation Notes
- AUR package updated to reflect architecture corrections
- VPS deployment verified with server-only components
- All Docker containers maintain non-root security standards

## 🔄 Migration Guide

### From v3.2.0 to v3.2.1
1. **Uninstall previous version** (if using AUR package)
2. **Install v3.2.1** via preferred method (AUR/AppImage/DEB)
3. **Access settings** through main application Settings screen
4. **Remove shortcuts** to external settings application (if any)
5. **Verify tray daemon** starts automatically with system

### Settings Location
- **Old**: External `cloudtolocalllm-settings` application
- **New**: Main app → Settings screen (integrated)

## 🛡️ Security & Stability

- All components run as non-root users
- Improved crash isolation between tray daemon and main app
- Reduced attack surface through component simplification
- Maintained security standards across all deployment channels

## 📋 Verification Steps

After installation, verify:
- [ ] Settings accessible through main application
- [ ] No external settings application installed
- [ ] System tray icon appears and functions correctly
- [ ] All settings persist between application restarts

## 🔗 Download Links

- **GitHub Releases**: [Primary Distribution](https://github.com/imrightguy/CloudToLocalLLM/releases)
- **AUR Package**: `yay -S cloudtolocalllm-desktop`
- **Direct Download**: [Latest Release](https://github.com/imrightguy/CloudToLocalLLM/releases/latest)

---

**Release Type**: Patch (Bugfix)  
**Version**: 3.2.1  
**Release Date**: $(date +%Y-%m-%d)  
**Architecture**: Corrected unified settings interface
EOF
```

**Verification Checkpoint ✅:**
- [ ] Release notes emphasize architecture corrections
- [ ] User migration guidance provided
- [ ] Security and stability improvements highlighted
- [ ] Download links point to SourceForge primary distribution

## VPS Deployment Verification

### 7. VPS Component Verification

**Verify VPS Contains Only Server Components:**
```bash
# Connect to VPS and verify deployment
ssh cloudllm@cloudtolocalllm.online << 'EOF'
cd /opt/cloudtolocalllm

echo "🔍 VPS Component Verification:"

# 1. Verify Flutter web build present
if [ -d "build/web" ]; then
    echo "✅ Flutter web build present"
    ls -la build/web/ | head -5
else
    echo "❌ Flutter web build missing"
fi

# 2. Verify Node.js API backend
if [ -f "api-backend/server.js" ]; then
    echo "✅ Node.js API backend present"
else
    echo "❌ Node.js API backend missing"
fi

# 3. Critical: Verify NO Python tray daemon on VPS
if [ ! -f "tray_daemon/dist/cloudtolocalllm-enhanced-tray" ]; then
    echo "✅ No Python tray daemon on VPS (correct)"
else
    echo "❌ Python tray daemon found on VPS (incorrect)"
fi

# 4. Verify Docker containers running
docker ps --format "table {{.Names}}\t{{.Status}}" | grep cloudtolocalllm

# 5. Verify non-root container execution
docker exec cloudtolocalllm-webapp id
# Should show uid=1001(cloudllm)

echo "VPS verification complete"
EOF
```

**Verification Checkpoint ✅:**
- [ ] Flutter web build present and accessible
- [ ] Node.js API backend operational
- [ ] **CRITICAL**: No Python tray daemon on VPS
- [ ] Docker containers running as cloudllm:1001 (non-root)
- [ ] All server components healthy

### 8. Security Validation

**Docker Container Security Check:**
```bash
ssh cloudllm@cloudtolocalllm.online << 'EOF'
echo "🛡️ Security Validation:"

# Check all containers run as non-root
for container in $(docker ps --format "{{.Names}}" | grep cloudtolocalllm); do
    echo "Container: $container"
    docker exec $container id
    echo "---"
done

# Verify file permissions
ls -la /opt/cloudtolocalllm/ | head -5

# Check process ownership
ps aux | grep cloudtolocalllm | grep -v grep || echo "No cloudtolocalllm processes (expected on VPS)"

echo "Security validation complete"
EOF
```

**Verification Checkpoint ✅:**
- [ ] All Docker containers run as cloudllm:1001
- [ ] File permissions properly set
- [ ] No unauthorized processes running
- [ ] Security standards maintained

## Rollback Procedures

### 9. Emergency Rollback Steps

**If Deployment Issues Occur:**
```bash
# 1. Rollback Git changes
cd /home/rightguy/Dev/CloudToLocalLLM
git checkout master
git reset --hard HEAD~1  # Only if needed

# 2. Rollback GitHub release
gh release delete v3.2.1 --yes  # Remove problematic release
git push origin --delete v3.2.1  # Remove tag from GitHub

# 3. Rollback VPS (if needed)
ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git checkout HEAD~1"

# 4. Rollback AUR package (manual process)
# Contact AUR maintainers or revert PKGBUILD changes

# 5. Force push corrected version (if needed)
git push origin master --force  # Use with extreme caution
```

**Verification Checkpoint ✅:**
- [ ] Rollback procedures documented and tested
- [ ] Emergency contacts identified
- [ ] Rollback verification steps defined

## Final Release Verification

### 10. Complete Release Verification

**Final Verification Checklist:**
```bash
echo "🎯 Final Release Verification v3.2.1:"

# 1. GitHub Repository
echo "GitHub Repository: $(git ls-remote origin v3.2.1 && echo "✅" || echo "❌")"

# 2. GitHub Release
echo "GitHub Release: $(gh release view v3.2.1 >/dev/null 2>&1 && echo "✅" || echo "❌")"

# 3. GitHub Assets
echo "GitHub Assets: $(gh release view v3.2.1 --json assets --jq '.assets[].name' | grep -q "cloudtolocalllm-3.2.1" && echo "✅" || echo "❌")"

# 4. VPS Status
echo "VPS Status: $(ssh cloudllm@cloudtolocalllm.online "docker ps | grep -q cloudtolocalllm-webapp" && echo "✅" || echo "❌")"

# 5. Architecture Corrections
echo "Architecture: $(test ! -f tray_daemon/dist/cloudtolocalllm-settings && echo "✅ Corrected" || echo "❌ Issues remain")"

echo "Release verification complete"
```

**Final Verification Checkpoint ✅:**
- [ ] All distribution channels updated
- [ ] VPS deployment stable
- [ ] Architecture corrections verified
- [ ] Security standards maintained
- [ ] Release ready for AUR publication

## Next Steps

After completing release management:
1. Proceed to [AUR Publication](03-aur-publication.md)
2. Monitor deployment success across all channels
3. Prepare user communication about architecture changes
4. Document lessons learned for future releases
