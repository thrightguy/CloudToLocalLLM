# CloudToLocalLLM Complete Deployment Workflow

## 🚨 **STOP FUCKING AROUND WITH PARTIAL DEPLOYMENTS** 🚨

This is the **ONE AND ONLY** deployment document for CloudToLocalLLM. Follow this exactly or you'll end up with the same version mismatch bullshit that's been plaguing this project.

**📊 Estimated Total Time: 45-90 minutes** (First-time: 90 min, Updates: 45 min)

**📖 Related Documentation:**
- **Visual Workflow Diagrams**: [`DEPLOYMENT_WORKFLOW_DIAGRAM.md`](./DEPLOYMENT_WORKFLOW_DIAGRAM.md)
- **Versioning Strategy**: [`VERSIONING_STRATEGY.md`](./VERSIONING_STRATEGY.md)
- **Script-First Resolution**: [`SCRIPT_FIRST_RESOLUTION_GUIDE.md`](./SCRIPT_FIRST_RESOLUTION_GUIDE.md)
- **AUR Integration Details**: [`AUR_INTEGRATION_CHANGES.md`](./AUR_INTEGRATION_CHANGES.md)
- **Build-Time Injection**: [`SIX_PHASE_BUILD_TIME_INJECTION_INTEGRATION.md`](./SIX_PHASE_BUILD_TIME_INJECTION_INTEGRATION.md)

## 🏗️ **ARCHITECTURE UPDATE (v3.4.0+)**

**Unified Flutter Web Architecture**: CloudToLocalLLM now uses a single Flutter application for both marketing and application functionality:
- **cloudtolocalllm.online**: Flutter marketing homepage and download pages (was static site)
- **app.cloudtolocalllm.online**: Flutter chat interface (redirects / to /chat)
- **docs.cloudtolocalllm.online**: VitePress documentation (unchanged)

See [Unified Flutter Web Architecture](../ARCHITECTURE/UNIFIED_FLUTTER_WEB.md) for detailed information.

---

## 🔍 **PRE-FLIGHT CHECKS** (⏱️ 5 minutes)

**MANDATORY: Complete ALL checks before starting deployment**

### **Environment Verification**
```bash
# 1. Verify you're in the correct directory
pwd
# Expected: /path/to/CloudToLocalLLM

# 2. Check Git status
git status
# Expected: "working tree clean" or only untracked files

# 3. Verify Flutter installation
flutter --version
# Expected: Flutter 3.x.x or higher

# 4. Check version manager script
./scripts/version_manager.sh help
# Expected: Help output with commands listed

# 5. Verify current version
./scripts/version_manager.sh info
# Expected: Current version information display
```

### **Required Tools Checklist**
- [ ] Flutter SDK installed and in PATH
- [ ] Git configured with proper credentials
- [ ] SSH access to VPS (test: `ssh cloudllm@cloudtolocalllm.online "echo 'Connection OK'"`)
- [ ] AUR SSH key configured (if updating AUR)
- [ ] SourceForge access configured (if uploading binaries)

### **Deployment Type Selection**
Choose your deployment scenario:
- **🆕 First-Time Deployment**: Complete setup from scratch
- **🔄 Version Update**: Increment version and deploy changes
- **🐛 Hotfix Deployment**: Critical bug fix deployment
- **🔧 Configuration Update**: No version change, config only

---

## 📋 **Version Management - THE SINGLE SOURCE OF TRUTH**

### **pubspec.yaml is KING** 👑
- **ALL** version information comes from `pubspec.yaml`
- Format: `MAJOR.MINOR.PATCH+BUILD` (e.g., `3.1.3+001`)
- **NEVER** manually edit version numbers anywhere else

### **Version Increment Process** (⏱️ 2 minutes)
```bash
# Use the version manager script - ALWAYS
./scripts/version_manager.sh increment <type>

# Types:
# - major: Creates GitHub release (x.0.0) - significant changes
# - minor: Feature additions (x.y.0) - no GitHub release
# - patch: Bug fixes (x.y.z) - no GitHub release
# - build: Build increments (x.y.z+nnn) - no GitHub release
```

**Expected Output:**
```
✅ Version updated from 3.1.2+001 to 3.1.3+001
📋 Updated files:
  - pubspec.yaml
  - assets/version.json
```

### **Version Consistency Requirements**
Before ANY deployment, verify these files match pubspec.yaml version:
- `assets/version.json` ✅
- `aur-package/PKGBUILD` (pkgver field) ✅
- All build scripts and documentation ✅

### **Automated Version Synchronization**
```bash
# Synchronize all version references automatically
./scripts/deploy/sync_versions.sh

# Expected output:
# ✅ All versions synchronized to 3.1.3+001
```

---

## 🔄 **COMPLETE DEPLOYMENT PROCESS**

### **Phase 1: Local Development & Version Management** (⏱️ 10 minutes)

#### **Step 1.1: Increment Version** ✅
```bash
# Determine increment type based on changes
./scripts/version_manager.sh increment patch  # or minor/major/build

# Verify version updated correctly
./scripts/version_manager.sh info
```

**Expected Output:**
```
=== CloudToLocalLLM Version Information ===
Full Version:     3.1.3+001
Semantic Version: 3.1.3
Build Number:     001
Source File:      pubspec.yaml
```

#### **Step 1.2: Synchronize All Version References** ✅
```bash
# Automated synchronization (RECOMMENDED)
./scripts/deploy/sync_versions.sh

# Manual verification (if sync script fails)
grep "version:" pubspec.yaml
grep "version" assets/version.json
grep "pkgver=" aur-package/PKGBUILD
```

**Expected Output:**
```
🔄 Synchronizing all version references...
📋 Current version: 3.1.3+001
📝 Updating assets/version.json...
✅ Updated assets/version.json
📝 Updating AUR PKGBUILD...
✅ Updated AUR PKGBUILD pkgver to 3.1.3
🎉 All versions synchronized to 3.1.3+001
```

#### **Step 1.3: Commit Version Changes** ✅
```bash
# Add all version-related files
git add pubspec.yaml assets/version.json aur-package/PKGBUILD

# Commit with standardized message
git commit -m "Version bump to $(./scripts/version_manager.sh get)"

# Verify commit
git log --oneline -1
```

#### **Step 1.4: Push to Git Repository** ✅
```bash
# Push to GitHub (primary for development)
git push origin master

# Alternative: Push to SourceForge (if configured)
# git push sourceforge master

# Verify push succeeded
git log --oneline -5
```

**⚠️ CHECKPOINT:** All version references must be synchronized before proceeding!

### **Phase 2: Build & Package Creation** (⏱️ 15-25 minutes)

#### **Step 2.1: Clean Build Environment** ✅
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Verify no dependency issues
flutter doctor
```

**Expected Output:**
```
Deleting build...                                                    7ms
Deleting .dart_tool...                                               5ms
Deleting ephemeral...                                                3ms
Running "flutter pub get" in CloudToLocalLLM...
Got dependencies!
```

#### **Step 2.2: Build Flutter Applications** ✅

**⚠️ CRITICAL: Unified Flutter-Native Architecture Build Requirements**

CloudToLocalLLM v3.4.0+ uses a unified Flutter-native architecture with a single application that includes integrated system tray functionality. All required dependencies are managed through the main pubspec.yaml.

**Required Dependencies for System Tray and Window Management:**
- `tray_manager: ^0.2.3` (provides native system tray functionality)
- `window_manager: ^0.5.0` (provides window management and screen retrieval)
- `flutter_secure_storage: ^9.2.2` (provides secure local storage)

These dependencies are automatically included in the unified Flutter application to provide:
- Native system tray integration across all platforms
- Window management and hiding to tray functionality
- Secure storage for authentication tokens and settings

**Unified Single-App Build Process:**
```bash
# Use the unified package creation script (REQUIRED for AUR packages)
./scripts/create_unified_aur_package.sh

# This script automatically:
# 1. Builds the unified Flutter application (main directory)
# 2. Collects ALL required Flutter plugin libraries
# 3. Creates unified package with proper library dependencies
# 4. Generates AUR package metadata and checksums

# For web deployment only (VPS)
flutter build web --release --no-tree-shake-icons
```

**Expected Output:**
```
CloudToLocalLLM Unified AUR Binary Package Creator
===================================================
Version: 3.4.0

[INFO] Building unified Flutter application...
[INFO] Building Flutter application with integrated system tray...
✓ Built build/linux/x64/release/bundle/cloudtolocalllm
[INFO] Collecting Flutter plugin libraries...
✓ Collected tray_manager, window_manager, and secure_storage plugins
✅ Unified Flutter application built successfully

✅ Unified AUR binary package created successfully!
📦 Ready for GitHub release and AUR deployment
```

**Build Verification:**
```bash
# Verify unified package contains all required libraries
tar -tf dist/cloudtolocalllm-*-x86_64.tar.gz | grep "\.so$"
# Expected: libtray_manager_plugin.so, libwindow_manager_plugin.so,
#           libscreen_retriever_linux_plugin.so, libflutter_secure_storage_linux_plugin.so,
#           liburl_launcher_linux_plugin.so

# Verify web build (for VPS deployment)
ls -la build/web/
# Expected: index.html, main.dart.js, assets/, etc.
```

#### **Step 2.3: Create Binary Package** ✅

**⚠️ IMPORTANT: Use Unified Package Creation Script**

The unified package creation script (./scripts/create_unified_aur_package.sh) automatically handles the unified Flutter application building and packaging. DO NOT use manual build/package commands.

```bash
# The unified script already created the package in Step 2.2
# Verify the package was created successfully
ls -la dist/cloudtolocalllm-*-x86_64.tar.gz*

# Check package contents for required libraries
tar -tf dist/cloudtolocalllm-*-x86_64.tar.gz | grep -E "(bin/|lib/.*\.so$)"
# Expected: Single executable in bin/ and all Flutter plugin libraries in lib/

# Verify AUR info file was generated
cat dist/cloudtolocalllm-*-aur-info.txt
# Expected: pkgver, sha256sums, and GitHub release URLs
```

**Expected Output:**
```
-rw-r--r-- 1 user user 19000000 Jun  7 21:32 cloudtolocalllm-3.4.0-x86_64.tar.gz
-rw-r--r-- 1 user user       102 Jun  7 21:32 cloudtolocalllm-3.4.0-x86_64.tar.gz.sha256
-rw-r--r-- 1 user user      1024 Jun  7 21:32 cloudtolocalllm-3.4.0-x86_64-aur-info.txt

Package contents:
cloudtolocalllm-3.4.0-x86_64/bin/cloudtolocalllm
cloudtolocalllm-3.4.0-x86_64/lib/libtray_manager_plugin.so
cloudtolocalllm-3.4.0-x86_64/lib/libscreen_retriever_linux_plugin.so
cloudtolocalllm-3.4.0-x86_64/lib/libwindow_manager_plugin.so
cloudtolocalllm-3.4.0-x86_64/lib/libflutter_secure_storage_linux_plugin.so
cloudtolocalllm-3.4.0-x86_64/lib/liburl_launcher_linux_plugin.so
```

#### **Step 2.4: Upload to SourceForge File Hosting** (Optional) ⚠️
```bash
# Upload binary package to SourceForge (if using SourceForge distribution)
sftp imrightguy@frs.sourceforge.net
# Commands in SFTP session:
# cd /home/frs/project/cloudtolocalllm/releases/
# put cloudtolocalllm-3.1.3-x86_64.tar.gz
# put cloudtolocalllm-3.1.3-x86_64.tar.gz.sha256
# quit
```

**⚠️ CHECKPOINT:** Verify both Linux and web builds completed successfully!

**📖 For build-time timestamp injection integration, see:** [`docs/DEPLOYMENT/SIX_PHASE_BUILD_TIME_INJECTION_INTEGRATION.md`](./SIX_PHASE_BUILD_TIME_INJECTION_INTEGRATION.md)

### **Phase 3: AUR Package Deployment** (⏱️ 15-20 minutes)

#### **Step 3.1: Update AUR PKGBUILD** ✅
```bash
cd aur-package/

# Verify current PKGBUILD version
grep "pkgver=" PKGBUILD

# Update checksums if using new binaries
NEW_CHECKSUM=$(sha256sum ../dist/v*/cloudtolocalllm-*-x86_64.tar.gz | cut -d' ' -f1)
echo "New checksum: $NEW_CHECKSUM"

# Update PKGBUILD manually or verify sync_versions.sh updated it
# The version should already be updated by sync_versions.sh
```

**Manual PKGBUILD Updates (if needed):**
```bash
# Update version
sed -i "s/^pkgver=.*/pkgver=$(./scripts/version_manager.sh get-semantic)/" PKGBUILD

# Update checksum (if using new binaries)
sed -i "s/^sha256sums=.*/sha256sums=('$NEW_CHECKSUM' 'SKIP')/" PKGBUILD
```

#### **Step 3.2: Test AUR Package Locally** ✅ **CRITICAL**
```bash
# Clean previous builds
rm -rf src/ pkg/ *.pkg.tar.zst

# Build package
makepkg -si --noconfirm

# Expected output:
# ==> Making package: cloudtolocalllm 3.1.3-1
# ==> Checking runtime dependencies...
# ==> Checking buildtime dependencies...
# ==> Retrieving sources...
# ==> Validating source files with sha256sums...
# ==> Extracting sources...
# ==> Starting build()...
# ==> Entering fakeroot environment...
# ==> Starting package()...
# ==> Finished making: cloudtolocalllm 3.1.3-1
```

**Package Verification:**
```bash
# Test installation with yay (if available)
yay -U cloudtolocalllm-*.pkg.tar.zst --noconfirm

# Test the installed package
cloudtolocalllm --version
# Expected: Version 3.1.3 or similar

# Test basic functionality
cloudtolocalllm --help
```

#### **Step 3.3: Generate .SRCINFO** ✅
```bash
# Generate updated .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Verify .SRCINFO content
head -10 .SRCINFO
# Expected: pkgver = 3.1.3
```

#### **Step 3.4: Submit to AUR** ✅
```bash
# Add updated files
git add PKGBUILD .SRCINFO

# Commit with version info
git commit -m "Update to version $(./scripts/version_manager.sh get-semantic)"

# Push to AUR (requires SSH key setup)
git push origin master
```

**Expected Output:**
```
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Writing objects: 100% (3/3), 1.05 KiB | 1.05 MiB/s, done.
Total 3 (delta 2), reused 0 (delta 0)
To ssh://aur.archlinux.org/cloudtolocalllm.git
   abc1234..def5678  master -> master
```

**⚠️ CHECKPOINT:** AUR package must build and install successfully before proceeding!

### **Phase 4: VPS Deployment** (⏱️ 10-15 minutes)

#### **Step 4.1: Deploy to VPS** ✅
```bash
# SSH to VPS as cloudllm user
ssh cloudllm@cloudtolocalllm.online

# Navigate to project directory
cd /opt/cloudtolocalllm

# Pull latest changes
git pull origin master

# Run deployment script
./scripts/deploy/update_and_deploy.sh
```

**Expected Output:**
```
Updating CloudToLocalLLM portal...
Pulling latest changes from GitHub...
From https://github.com/imrightguy/CloudToLocalLLM
 * branch            master     -> FETCH_HEAD
Already up to date.
Building Flutter web application...
✓ Built build/web
Stopping existing containers...
SSL certificates already exist. Starting services...
✅ Web app is accessible at https://app.cloudtolocalllm.online
Deployment complete!
```

#### **Step 4.2: Verify VPS Deployment** ✅
```bash
# Check container status
docker compose ps
# Alternative for older systems: docker-compose ps

# Expected output:
# NAME                     IMAGE               COMMAND             STATUS
# cloudtolocalllm-webapp   nginx:alpine        "/entrypoint.sh"    Up (healthy)
```

**Web Accessibility Tests:**
```bash
# Test main application
curl -I https://app.cloudtolocalllm.online
# Expected: HTTP/1.1 200 OK

# Test homepage
curl -I https://cloudtolocalllm.online
# Expected: HTTP/1.1 200 OK

# Check version endpoint
curl -s https://app.cloudtolocalllm.online/version.json
# Expected: {"app_name":"cloudtolocalllm","version":"3.1.3","build_number":"001",...}
```

**Container Health Check:**
```bash
# Check container logs for errors
docker compose logs webapp --tail 20

# Verify nginx is serving files
docker compose exec webapp ls -la /usr/share/nginx/html/
```

#### **Step 4.3: VPS Deployment Verification** ✅
```bash
# Exit VPS SSH session
exit

# Test from local machine
curl -s https://app.cloudtolocalllm.online/version.json | grep version
# Expected: "version":"3.1.3"

# Test full application load
curl -s https://app.cloudtolocalllm.online | grep -o "<title>.*</title>"
# Expected: <title>CloudToLocalLLM</title>
```

**⚠️ CHECKPOINT:** VPS must be accessible and serving the correct version!

---

## ✅ **COMPREHENSIVE VERIFICATION** (⏱️ 10 minutes)

### **Automated Verification Script** 🤖
```bash
# Run comprehensive verification
./scripts/deploy/verify_deployment.sh
```

**Expected Output:**
```
🔍 CloudToLocalLLM Deployment Verification
===========================================
📋 Expected version: 3.1.3+001

📂 Checking Git repository...
✅ Git repository version: 3.1.3+001
✅ All changes committed
✅ Latest changes pushed to remote

📄 Checking assets/version.json...
✅ assets/version.json: 3.1.3+001

📦 Checking AUR package...
✅ AUR package version: 3.1.3
✅ AUR PKGBUILD is valid

🌐 Checking VPS deployment...
✅ VPS web app accessible
✅ VPS deployment version: 3.1.3
✅ VPS main site accessible

🎯 Verification Summary
======================
🎉 DEPLOYMENT VERIFICATION PASSED!
All components are synchronized with version 3.1.3+001
✅ Deployment is complete and ready for production use.
```

### **Manual Cross-Component Verification**

#### **1. Git Repository Status** ✅
```bash
# Check current version
./scripts/version_manager.sh get
# Expected: 3.1.3+001

# Verify latest commit pushed
git log --oneline -1
# Expected: Latest commit with version bump message

# Check working directory status
git status
# Expected: "working tree clean"
```

#### **2. VPS Deployment Status** ✅
```bash
# Check deployed version
curl -s https://app.cloudtolocalllm.online/version.json | jq '.version'
# Expected: "3.1.3"

# Verify container health
ssh cloudllm@cloudtolocalllm.online "docker compose ps"
# Expected: All containers "Up" and "healthy"

# Test application functionality
curl -s https://app.cloudtolocalllm.online | grep -q "CloudToLocalLLM"
echo $?
# Expected: 0 (success)
```

#### **3. AUR Package Status** ✅
```bash
# Check AUR package version (online)
curl -s "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=cloudtolocalllm" | grep "pkgver="
# Expected: pkgver=3.1.3

# Verify local package builds
cd aur-package && makepkg --printsrcinfo | grep "pkgver ="
# Expected: pkgver = 3.1.3

# Test package installation (if on Arch Linux)
# yay -Si cloudtolocalllm | grep Version
# Expected: Version: 3.1.3-1
```

### **Functional Testing Checklist** 📋

#### **Desktop Application Testing**
- [ ] Desktop application launches without errors
- [ ] Version displayed correctly in UI: `cloudtolocalllm --version`
- [ ] System tray functionality works (if applicable)
- [ ] Application connects to local Ollama (if running)

#### **Web Application Testing**
- [ ] Web application loads at https://app.cloudtolocalllm.online
- [ ] Version displayed correctly in browser
- [ ] Authentication flow completes successfully
- [ ] No console errors in browser developer tools

#### **Package Distribution Testing**
- [ ] AUR package installs without errors: `yay -S cloudtolocalllm`
- [ ] Installed package shows correct version
- [ ] Desktop entry appears in application menu
- [ ] Uninstall works cleanly: `yay -R cloudtolocalllm`

---

## 🚫 **DEPLOYMENT COMPLETION CRITERIA**

### **🎯 DEPLOYMENT IS NOT COMPLETE UNTIL ALL CRITERIA ARE MET:**

#### **1. Version Consistency Verified** ✅
- [ ] `pubspec.yaml` version matches target version
- [ ] `assets/version.json` version matches target version
- [ ] `aur-package/PKGBUILD` pkgver matches target version
- [ ] Git repository shows latest version committed and pushed
- [ ] VPS deployment shows correct version in `/version.json` endpoint
- [ ] AUR package shows correct version and builds successfully

**Verification Command:**
```bash
./scripts/deploy/verify_deployment.sh
# Must show: "🎉 DEPLOYMENT VERIFICATION PASSED!"
```

#### **2. All Components Deployed** ✅
- [ ] Git repository updated with version changes
- [ ] Binary packages created and available (if applicable)
- [ ] AUR package submitted and building successfully
- [ ] VPS deployment completed and accessible
- [ ] All services responding correctly

#### **3. Comprehensive Testing Completed** ✅
- [ ] Local testing of all packages passed
- [ ] VPS accessibility verified from external network
- [ ] AUR package installation tested (if on Arch Linux)
- [ ] Functional testing completed without critical issues
- [ ] No version-related errors in logs

#### **4. Documentation and Confirmation** ✅
- [ ] Deployment process documented (this checklist completed)
- [ ] All verification steps completed successfully
- [ ] No outstanding issues or version mismatches
- [ ] User has explicitly confirmed deployment completion

### **🚨 CRITICAL FAILURE CONDITIONS**

**DEPLOYMENT FAILS IMMEDIATELY IF:**

#### **Version Mismatch Scenarios** ❌
- Any component shows different version numbers
- Git repository version ≠ VPS version ≠ AUR version
- `pubspec.yaml` version ≠ `assets/version.json` version
- Build artifacts contain wrong version information

#### **Accessibility Failures** ❌
- VPS deployment is inaccessible (HTTP 5xx errors)
- Web application fails to load or shows errors
- API endpoints return incorrect responses
- SSL certificate issues preventing HTTPS access

#### **Package Build Failures** ❌
- AUR package fails to build with `makepkg`
- Binary packages are corrupted or incomplete
- Dependencies are missing or incompatible
- Installation process fails on target systems

#### **Functional Failures** ❌
- Desktop application crashes on startup
- Authentication system is broken
- Core functionality is non-operational
- Data loss or corruption detected

### **🔄 ROLLBACK PROCEDURES**

#### **Git Rollback** 🔙
```bash
# Rollback to previous version
git log --oneline -10  # Find previous good commit
git reset --hard <previous-commit-hash>
git push --force-with-lease origin master
```

#### **VPS Rollback** 🔙
```bash
# SSH to VPS and rollback
ssh cloudllm@cloudtolocalllm.online
cd /opt/cloudtolocalllm
git reset --hard <previous-commit-hash>
./scripts/deploy/update_and_deploy.sh
```

#### **AUR Rollback** 🔙
```bash
# Rollback AUR package
cd aur-package/
git reset --hard <previous-commit-hash>
git push --force-with-lease origin master
```

---

## 🔧 **TROUBLESHOOTING GUIDE**

### **🔄 Version Mismatch Issues**

#### **Symptom:** Different versions across components
```bash
# Diagnosis
./scripts/version_manager.sh info
grep "version" assets/version.json
grep "pkgver=" aur-package/PKGBUILD
curl -s https://app.cloudtolocalllm.online/version.json | jq '.version'
```

#### **Solution:** Automated synchronization
```bash
# Reset all versions to pubspec.yaml
./scripts/version_manager.sh validate
./scripts/deploy/sync_versions.sh

# Manual fix if automation fails
CORRECT_VERSION=$(./scripts/version_manager.sh get-semantic)
sed -i "s/\"version\": \".*\"/\"version\": \"$CORRECT_VERSION\"/" assets/version.json
sed -i "s/^pkgver=.*/pkgver=$CORRECT_VERSION/" aur-package/PKGBUILD
```

### **📦 AUR Package Issues**

#### **Symptom:** `makepkg` fails with checksum errors
```bash
# Diagnosis
makepkg -si --noconfirm 2>&1 | grep -i "failed\|error"
```

#### **Solution:** Update checksums
```bash
# Clean build environment
rm -rf src/ pkg/ *.pkg.tar.zst

# Update checksums
NEW_CHECKSUM=$(sha256sum ../dist/v*/cloudtolocalllm-*-x86_64.tar.gz | cut -d' ' -f1)
sed -i "s/sha256sums=.*/sha256sums=('$NEW_CHECKSUM' 'SKIP')/" PKGBUILD

# Rebuild from scratch
makepkg -si --noconfirm
```

#### **Symptom:** Package builds but installation fails
```bash
# Diagnosis
pacman -Qi cloudtolocalllm  # Check if already installed
ldd /usr/share/cloudtolocalllm/cloudtolocalllm  # Check dependencies
```

#### **Solution:** Dependency and conflict resolution
```bash
# Remove conflicting packages
yay -R cloudtolocalllm-git  # Remove git version if exists

# Install missing dependencies
yay -S libayatana-appindicator gtk3 glib2

# Reinstall package
yay -U cloudtolocalllm-*.pkg.tar.zst --overwrite '*'
```

### **🌐 VPS Deployment Issues**

#### **Symptom:** Containers fail to start
```bash
# Diagnosis
ssh cloudllm@cloudtolocalllm.online
cd /opt/cloudtolocalllm
docker compose ps
docker compose logs webapp --tail 50
```

#### **Solution:** Container troubleshooting
```bash
# Check disk space
df -h

# Check container logs for specific errors
docker compose logs webapp | grep -i "error\|failed\|exception"

# Restart services with fresh build
docker compose down
flutter clean && flutter pub get && flutter build web --release
docker compose up -d

# Verify container health
docker compose ps
curl -I https://app.cloudtolocalllm.online
```

#### **Symptom:** Web application shows wrong version
```bash
# Diagnosis
curl -s https://app.cloudtolocalllm.online/version.json
ls -la build/web/version.json
```

#### **Solution:** Force rebuild and redeploy
```bash
# On VPS
cd /opt/cloudtolocalllm
git pull origin master
rm -rf build/web
flutter build web --release --no-tree-shake-icons
docker compose restart webapp
```

### **🔐 SSH and Access Issues**

#### **Symptom:** Cannot SSH to VPS
```bash
# Diagnosis
ssh -v cloudllm@cloudtolocalllm.online
```

#### **Solution:** SSH troubleshooting
```bash
# Check SSH key
ssh-add -l

# Test with password authentication
ssh -o PreferredAuthentications=password cloudllm@cloudtolocalllm.online

# Check VPS status from hosting provider
```

#### **Symptom:** Cannot push to AUR
```bash
# Diagnosis
ssh -T aur@aur.archlinux.org
```

#### **Solution:** AUR SSH setup
```bash
# Add AUR SSH key
ssh-keyscan aur.archlinux.org >> ~/.ssh/known_hosts
# Upload your public key to AUR account settings
```

### **🚨 Emergency Recovery Procedures**

#### **Complete Deployment Failure**
```bash
# 1. Stop all deployment processes
# 2. Rollback to last known good state
git log --oneline -10
git reset --hard <last-good-commit>

# 3. Verify rollback
./scripts/deploy/verify_deployment.sh

# 4. Document the failure
echo "Deployment failed at $(date): <reason>" >> deployment_failures.log
```

#### **VPS Complete Outage**
```bash
# 1. Check VPS provider status
# 2. Access VPS console if available
# 3. Restart VPS if necessary
# 4. Verify services after restart
ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && ./scripts/deploy/update_and_deploy.sh"
```

---

## 📋 **QUICK REFERENCE CHECKLIST**

### **🚀 First-Time Deployment Checklist**
```
□ Pre-flight checks completed
□ Environment verified (Flutter, Git, SSH)
□ Version incremented and synchronized
□ Git changes committed and pushed
□ Flutter builds completed (Linux + Web)
□ Binary packages created
□ AUR package tested locally
□ AUR package submitted
□ VPS deployment completed
□ Comprehensive verification passed
□ All functional tests passed
□ Deployment completion confirmed
```

### **🔄 Update Deployment Checklist**
```
□ Pre-flight checks completed
□ Version incremented appropriately
□ Version synchronization completed
□ Git changes committed and pushed
□ Flutter web build completed
□ AUR package updated and tested
□ VPS deployment completed
□ Verification script passed
□ Deployment completion confirmed
```

### **⚡ Quick Commands Reference**

#### **Version Management**
```bash
# CloudToLocalLLM Semantic Versioning Strategy:
# PATCH (0.0.X) - Urgent fixes: hotfixes, security updates, critical bugs
# MINOR (0.X.0) - Planned features: new functionality, UI enhancements
# MAJOR (X.0.0) - Breaking changes: architectural overhauls, API changes

# Show current version
./scripts/version_manager.sh info

# Increment version based on change type
./scripts/version_manager.sh increment patch    # For urgent fixes
./scripts/version_manager.sh increment minor    # For planned features
./scripts/version_manager.sh increment major    # For breaking changes

# Synchronize versions
./scripts/deploy/sync_versions.sh

# Verify deployment
./scripts/deploy/verify_deployment.sh
```

#### **Build Commands**
```bash
# Clean and build
flutter clean && flutter pub get
flutter build linux --release
flutter build web --release --no-tree-shake-icons
```

#### **AUR Commands**
```bash
# Test package (local testing only - does NOT validate real AUR experience)
cd aur-package && makepkg -si --noconfirm

# Submit to AUR (USE AUTOMATION SCRIPT - NOT MANUAL GIT COMMANDS)
./scripts/deploy/submit_aur_package.sh --force --verbose

# MANDATORY: Test real AUR installation (deployment gate)
yay -Sc --noconfirm  # Clear cache if needed
yay -S cloudtolocalllm --noconfirm
cloudtolocalllm --version  # Verify correct version
```

**📖 For detailed AUR integration guidance, see:** [`docs/DEPLOYMENT/AUR_INTEGRATION_CHANGES.md`](./AUR_INTEGRATION_CHANGES.md)
**📖 For script-first resolution principles, see:** [`docs/DEPLOYMENT/SCRIPT_FIRST_RESOLUTION_GUIDE.md`](./SCRIPT_FIRST_RESOLUTION_GUIDE.md)

#### **VPS Commands**
```bash
# Deploy to VPS
ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git pull origin master && ./scripts/deploy/update_and_deploy.sh"

# Check VPS status
curl -s https://app.cloudtolocalllm.online/version.json | jq '.version'
```

---

## 📋 **Versioning Decision Guide**

### **Choose the Right Version Increment**

Before starting deployment, determine the appropriate version increment:

| Question | Answer | Version Type | Example |
|----------|--------|--------------|---------|
| Does this break existing functionality? | Yes | **MAJOR** | API v2 migration, Flutter upgrade |
| Is this an urgent fix that can't wait? | Yes | **PATCH** | Security vulnerability, crash fix |
| Does this add new features/functionality? | Yes | **MINOR** | New UI features, tunnel enhancements |
| Is this just a build/timestamp update? | Yes | **BUILD** | CI/CD builds, testing iterations |

**📖 For detailed versioning strategy, see:** [`docs/DEPLOYMENT/VERSIONING_STRATEGY.md`](./VERSIONING_STRATEGY.md)

### **Deployment Urgency by Version Type**

**PATCH Releases (🚨 URGENT):**
- Deploy immediately during business hours
- Fast-track all 6 phases with minimal testing
- Focus on fix verification only
- Enhanced monitoring post-deployment

**MINOR Releases (📅 PLANNED):**
- Deploy during scheduled maintenance windows
- Standard 6-phase deployment with full testing
- Complete AUR verification required
- Standard monitoring and validation

**MAJOR Releases (⚠️ COORDINATED):**
- Deploy during planned major release windows
- Extended 6-phase deployment with comprehensive testing
- Migration testing and rollback preparation
- Extended monitoring and user communication

---

## 🔧 **Troubleshooting Common Issues**

### **AUR Installation Failures**

#### Problem: `yay -S cloudtolocalllm` fails with 404 errors
```bash
# Solution: Clear yay cache and force fresh download
yay -Sc --noconfirm
rm -rf ~/.cache/yay/cloudtolocalllm
yay -S cloudtolocalllm --noconfirm
```

#### Problem: SHA256 checksum mismatch
```bash
# Check if GitHub raw URLs are accessible
curl -I https://raw.githubusercontent.com/imrightguy/CloudToLocalLLM/master/dist/cloudtolocalllm-X.X.X-x86_64.tar.gz

# Verify checksums match between dist/ and AUR PKGBUILD
cat dist/cloudtolocalllm-X.X.X-x86_64.tar.gz.sha256
grep sha256sums aur-package/PKGBUILD
```

#### Problem: Package extraction fails
```bash
# Check archive structure
tar -tzf dist/cloudtolocalllm-X.X.X-x86_64.tar.gz | head -10
# Should show: cloudtolocalllm-X.X.X-x86_64/ directory structure
```

### **Script Failures**

#### Problem: `create_aur_binary_package.sh` fails with "File not found"
**Solution**: Binary file management is permanently disabled in v3.5.14+. If you see this error, ensure you're using the updated script.

#### Problem: Manual operations temptation
**Solution**: Always fix the automation script instead of bypassing it. Follow script-first resolution principle.

### **Version Verification Issues**

#### Problem: Application reports wrong version after installation
```bash
# Check package info
pacman -Qi cloudtolocalllm

# Verify application logs show correct version
cloudtolocalllm --version 2>&1 | grep "VersionService"
```

---

## 📞 **Support & Escalation**

### **🆘 When Deployment Fails**

1. **🛑 STOP** - Do not continue with partial deployment
2. **📝 Document** the exact error and current state
3. **🔙 Rollback** if necessary to last known good state
4. **🔧 Fix** the root cause before proceeding
5. **🔄 Restart** the deployment process from Phase 1

### **📋 Failure Documentation Template**
```
Deployment Failure Report
========================
Date: $(date)
Version Attempted: $(./scripts/version_manager.sh get)
Phase Failed: [1-4]
Error Message: [exact error]
Current State: [describe current state]
Rollback Required: [yes/no]
Resolution: [steps taken]
```

### **🚨 Emergency Contacts**
- **Repository Issues**: Check GitHub Issues
- **VPS Issues**: Contact hosting provider
- **AUR Issues**: Check AUR package comments

**Remember: A partial deployment with version mismatches is worse than no deployment at all.**

---

## 🤖 **AUTOMATION SCRIPTS REFERENCE**

### **📁 Available Scripts**
- `scripts/version_manager.sh` - Version management operations
- `scripts/deploy/sync_versions.sh` - Synchronize version references
- `scripts/deploy/verify_deployment.sh` - Comprehensive verification
- `scripts/deploy/complete_deployment.sh` - Guided deployment workflow
- `scripts/deploy/cleanup_docs.sh` - Documentation cleanup

### **🔧 Script Usage Examples**

#### **Version Management**
```bash
# Show detailed version information
./scripts/version_manager.sh info

# Increment version types
./scripts/version_manager.sh increment build    # 3.1.3+001 → 3.1.3+002
./scripts/version_manager.sh increment patch    # 3.1.3+001 → 3.1.4+001
./scripts/version_manager.sh increment minor    # 3.1.3+001 → 3.2.0+001
./scripts/version_manager.sh increment major    # 3.1.3+001 → 4.0.0+001

# Set specific version
./scripts/version_manager.sh set 3.2.0

# Validate version format
./scripts/version_manager.sh validate
```

#### **Deployment Automation**
```bash
# Automated version synchronization
./scripts/deploy/sync_versions.sh
# Output: ✅ All versions synchronized to 3.1.3+001

# Comprehensive deployment verification
./scripts/deploy/verify_deployment.sh
# Output: 🎉 DEPLOYMENT VERIFICATION PASSED!

# Guided deployment workflow
./scripts/deploy/complete_deployment.sh
# Interactive script with prompts and automation
```

### **🔄 Custom Automation Examples**

#### **One-Command Update Deployment**
```bash
#!/bin/bash
# Custom script: quick_update.sh
set -e

echo "🚀 Quick Update Deployment"
./scripts/version_manager.sh increment patch
./scripts/deploy/sync_versions.sh
git add -A && git commit -m "Quick update to $(./scripts/version_manager.sh get)"
git push origin master
flutter build web --release
ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git pull && ./scripts/deploy/update_and_deploy.sh"
./scripts/deploy/verify_deployment.sh
echo "✅ Quick update completed!"
```

#### **AUR-Only Update**
```bash
#!/bin/bash
# Custom script: aur_update.sh
set -e

echo "📦 AUR Package Update"
# USE AUTOMATION SCRIPT - NOT MANUAL GIT COMMANDS
./scripts/deploy/submit_aur_package.sh --force --verbose

# MANDATORY: Test real AUR installation
echo "🧪 Testing real AUR installation..."
yay -Sc --noconfirm  # Clear cache
yay -S cloudtolocalllm --noconfirm
cloudtolocalllm --version  # Verify version
yay -R cloudtolocalllm --noconfirm  # Clean up
echo "✅ AUR package updated and verified!"
```

#### **VPS-Only Deployment**
```bash
#!/bin/bash
# Custom script: vps_deploy.sh
set -e

echo "🌐 VPS Deployment Only"
flutter build web --release --no-tree-shake-icons
ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git pull origin master && ./scripts/deploy/update_and_deploy.sh"
curl -s https://app.cloudtolocalllm.online/version.json | jq '.version'
echo "✅ VPS deployment completed!"
```

---

## 📚 **DOCUMENTATION HIERARCHY**

### **🎯 Primary Documentation (ACTIVE)**
- **THIS DOCUMENT** (`docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md`) - **THE ONLY DEPLOYMENT GUIDE**
- `docs/DEPLOYMENT/VERSIONING_STRATEGY.md` - Version format reference and strategy
- `scripts/version_manager.sh` - Version management tool documentation

### **🗂️ Supporting Documentation**
- `scripts/deploy/README.md` - Deployment scripts overview
- `aur-package/README.md` - AUR package specific instructions
- `docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md` - System architecture and tray implementation

### **🗄️ Archived Documentation (OBSOLETE)**
Located in `docs/archive/obsolete-*/`:
- `DEPLOYMENT.md` (generic, outdated)
- `DEPLOYMENT_CHECKLIST_ENHANCED.md` (too complex, outdated)
- `DEPLOYMENT_INSTRUCTIONS.md` (incomplete)
- `DEPLOYMENT_SUMMARY.md` (partial information)
- `VPS_DEPLOYMENT.md` (VPS-only, incomplete)

**⚠️ DO NOT USE ARCHIVED DOCUMENTS - They contain outdated information that will cause version mismatches!**

---

## 🎯 **SUCCESS METRICS & KPIs**

### **✅ Deployment Success Indicators**
- **Version Consistency**: All components show identical version numbers
- **Accessibility**: VPS responds with correct version in API endpoints
- **Package Quality**: AUR package builds without errors on clean systems
- **Functionality**: Desktop application launches with correct version display
- **User Experience**: No version-related support tickets or confusion
- **Automation**: Verification script passes without manual intervention

### **📊 Performance Metrics**
- **Deployment Time**: Complete deployment in under 90 minutes
- **Error Rate**: Less than 5% deployment failures
- **Rollback Time**: Ability to rollback within 15 minutes
- **Verification Coverage**: 100% automated verification of critical components

### **❌ Failure Indicators**
- **Version Mismatches**: Any component showing different version numbers
- **Accessibility Issues**: VPS deployment shows wrong version or is inaccessible
- **Build Failures**: AUR package fails to build on target systems
- **User Confusion**: Reports of version confusion or installation issues
- **Multiple Attempts**: Requiring multiple deployment attempts for success

### **🔍 Monitoring Commands**
```bash
# Quick health check
./scripts/deploy/verify_deployment.sh

# Detailed status check
echo "Git: $(./scripts/version_manager.sh get)"
echo "VPS: $(curl -s https://app.cloudtolocalllm.online/version.json | jq -r '.version')"
echo "AUR: $(curl -s 'https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=cloudtolocalllm' | grep 'pkgver=' | cut -d'=' -f2)"
```

### **📈 Continuous Improvement**
- **Documentation Updates**: Keep this guide updated with lessons learned
- **Script Enhancement**: Improve automation scripts based on failure patterns
- **Process Optimization**: Reduce deployment time and complexity
- **Error Prevention**: Add more pre-flight checks and validations

---

## 🏆 **DEPLOYMENT COMPLETION CERTIFICATE**

```
╔══════════════════════════════════════════════════════════════╗
║                    DEPLOYMENT COMPLETED                     ║
║                                                              ║
║  Project: CloudToLocalLLM                                    ║
║  Version: $(./scripts/version_manager.sh get)               ║
║  Date: $(date)                                               ║
║  Deployer: [Your Name]                                       ║
║                                                              ║
║  ✅ All verification checks passed                           ║
║  ✅ Cross-platform synchronization confirmed                ║
║  ✅ No version mismatches detected                           ║
║                                                              ║
║  Status: DEPLOYMENT SUCCESSFUL                               ║
╚══════════════════════════════════════════════════════════════╝
```

**🎉 Congratulations! You have successfully completed a CloudToLocalLLM deployment without falling into the version mismatch hell that plagued this project before.**

---

*This enhanced documentation eliminates confusion, prevents version mismatches, and ensures consistent, complete deployments across all platforms. Follow it exactly and deployment will be smooth, predictable, and successful every time.*
