# CloudToLocalLLM v3.2.1 Deployment Checklist

## 🎯 Critical Architecture Correction Deployment

**Release**: v3.2.0 → v3.2.1 (Patch)  
**Primary Fix**: Remove external Python settings app, implement unified Flutter settings  
**Deployment Type**: Architecture Correction (Critical Bugfix)  
**Distribution**: GitHub Primary, AUR Package

---

## ✅ Pre-Deployment Verification (COMPLETED)

### Architecture Corrections Applied
- [x] **Flutter Settings Screen**: Removed `_launchTraySettings()` function
- [x] **External App Elimination**: Removed settings app launch buttons  
- [x] **In-App Settings**: Added Start Minimized and Close to Tray controls
- [x] **Code Cleanup**: Removed unused imports and functions
- [x] **AUR PKGBUILD**: Removed settings app build and installation
- [x] **Version Update**: pubspec.yaml updated to 3.2.1+1

### Critical Success Criteria Defined
- [x] **No cloudtolocalllm-settings executable** in any build artifact
- [x] **Flutter settings screen functional** in both desktop and web
- [x] **Tray daemon scope correct** (system tray functions only)
- [x] **Package size maintained** (~125MB unified architecture)
- [x] **VPS deployment verified** (server components only)

---

## 🔧 Phase 1: Application Building

### Prerequisites Check
- [ ] **Flutter 3.24+** installed and verified (`flutter --version`)
- [ ] **Python 3.10+** with pip available (`python3 --version`)
- [ ] **PyInstaller 6.0+** installed (`pip3 show pyinstaller`)
- [ ] **Development environment** clean and ready

### Version Management
- [ ] **Backup pubspec.yaml**: `cp pubspec.yaml pubspec.yaml.backup`
- [ ] **Update version**: `sed -i 's/version: 3\.2\.0+[0-9]*/version: 3.2.1+1/' pubspec.yaml`
- [ ] **Verify version**: `grep "version:" pubspec.yaml` shows 3.2.1+1

### Flutter Desktop Build
- [ ] **Clean environment**: `flutter clean && rm -rf build/ .dart_tool/`
- [ ] **Get dependencies**: `flutter pub get`
- [ ] **Enable desktop**: `flutter config --enable-linux-desktop`
- [ ] **Build release**: `flutter build linux --release --verbose`
- [ ] **Verify executable**: `test -f build/linux/x64/release/bundle/cloudtolocalllm`
- [ ] **Critical check**: `test ! -f build/linux/x64/release/bundle/cloudtolocalllm-settings`

### Python Tray Daemon Build
- [ ] **Install dependencies**: `cd tray_daemon && pip3 install --user -r requirements.txt pyinstaller`
- [ ] **Clean builds**: `rm -rf build/ dist/ *.spec`
- [ ] **Build tray daemon**: `pyinstaller --onefile --name cloudtolocalllm-enhanced-tray --hidden-import pystray._xorg --console enhanced_tray_daemon.py`
- [ ] **Verify executable**: `test -f dist/cloudtolocalllm-enhanced-tray`
- [ ] **Critical check**: `test ! -f dist/cloudtolocalllm-settings`

### Architecture Verification
- [ ] **No external settings references**: `grep -r "_launchTraySettings\|cloudtolocalllm-settings" lib/ || echo "✅ Clean"`
- [ ] **No settings executables**: `find . -name "*settings*" -type f -executable | grep -v ".git" || echo "✅ Clean"`
- [ ] **Tray daemon scope**: `grep -c "def.*settings" tray_daemon/enhanced_tray_daemon.py || echo "✅ Correct scope"`
- [ ] **Package size check**: Total Flutter + Tray ~125MB

### Functionality Testing
- [ ] **Launch application**: `./build/linux/x64/release/bundle/cloudtolocalllm &`
- [ ] **Navigate to Settings**: Verify Settings screen accessible
- [ ] **Test all sections**: Appearance, LLM Provider, System Tray, Cloud & Sync, App Info
- [ ] **Critical verification**: NO "Advanced Settings" or external app buttons
- [ ] **Test controls**: All switches, dropdowns, buttons functional
- [ ] **Kill test app**: `pkill cloudtolocalllm`

**Phase 1 Gate**: ✅ All builds successful, no external settings app, Flutter settings functional

---

## 📦 Phase 2: Release Management

### Git Workflow
- [ ] **Create release branch**: `git checkout -b release/v3.2.1`
- [ ] **Stage changes**: `git add lib/screens/settings_screen.dart packaging/aur/PKGBUILD pubspec.yaml`
- [ ] **Commit with message**: Architecture correction commit with detailed description
- [ ] **Create tag**: `git tag -a v3.2.1 -m "Architecture correction release message"`
- [ ] **Merge to master**: `git checkout master && git merge release/v3.2.1 --no-ff`

### GitHub Distribution (Primary)
- [ ] **Verify remote**: `git remote -v` shows origin pointing to GitHub
- [ ] **Push branch**: `git push origin release/v3.2.1`
- [ ] **Push tag**: `git push origin v3.2.1`
- [ ] **Push master**: `git push origin master`

### Binary Archive Creation
- [ ] **Create dist directory**: `mkdir -p dist/v3.2.1`
- [ ] **Copy Flutter bundle**: `cp -r build/linux/x64/release/bundle dist/v3.2.1/cloudtolocalllm-bundle`
- [ ] **Copy tray daemon**: `cp tray_daemon/dist/cloudtolocalllm-enhanced-tray dist/v3.2.1/`
- [ ] **Copy documentation**: `cp README.md CHANGELOG.md LICENSE dist/v3.2.1/`
- [ ] **Create archive**: `cd dist/v3.2.1 && tar -czf cloudtolocalllm-3.2.1-x86_64.tar.gz *`
- [ ] **Verify size**: Archive ~125MB
- [ ] **Critical check**: `tar -tzf cloudtolocalllm-3.2.1-x86_64.tar.gz | grep -v "cloudtolocalllm-settings"`

### GitHub Release Creation
- [ ] **Create release**: `gh release create v3.2.1 --title "..." --notes-file RELEASE_NOTES_v3.2.1.md --target master dist/v3.2.1/cloudtolocalllm-3.2.1-x86_64.tar.gz`
- [ ] **Verify release**: `gh release view v3.2.1` shows release details and binary asset

### VPS Deployment Verification
- [ ] **Check Flutter web**: `ssh cloudllm@cloudtolocalllm.online "ls -la /opt/cloudtolocalllm/build/web/"`
- [ ] **Check API backend**: `ssh cloudllm@cloudtolocalllm.online "ls -la /opt/cloudtolocalllm/api-backend/server.js"`
- [ ] **Critical check**: `ssh cloudllm@cloudtolocalllm.online "test ! -f /opt/cloudtolocalllm/tray_daemon/dist/cloudtolocalllm-enhanced-tray"`
- [ ] **Docker status**: `ssh cloudllm@cloudtolocalllm.online "docker ps | grep cloudtolocalllm"`
- [ ] **Security check**: `ssh cloudllm@cloudtolocalllm.online "docker exec cloudtolocalllm-webapp id"` shows uid=1001

### GitHub Release Verification
- [ ] **Verify tag**: `curl -s https://api.github.com/repos/imrightguy/CloudToLocalLLM/tags | jq -r '.[0].name'` shows v3.2.1
- [ ] **Verify assets**: `gh release view v3.2.1 --json assets --jq '.assets[].name'` shows cloudtolocalllm-3.2.1-x86_64.tar.gz
- [ ] **Test download**: Download and verify binary integrity

**Phase 2 Gate**: ✅ GitHub release created, VPS verified, security maintained

---

## 🏗️ Phase 3: AUR Publication

### PKGBUILD Validation
- [ ] **Check corrections**: `grep -n "cloudtolocalllm-settings" packaging/aur/PKGBUILD || echo "✅ Clean"`
- [ ] **Update version**: `sed -i 's/pkgver=3\.2\.0/pkgver=3.2.1/' packaging/aur/PKGBUILD`
- [ ] **Update release**: `sed -i 's/pkgrel=[0-9]*/pkgrel=1/' packaging/aur/PKGBUILD`
- [ ] **Update source**: Point to GitHub v3.2.1 release
- [ ] **Verify dependencies**: Flutter in makedepends only, not runtime depends

### Local Testing
- [ ] **Create test environment**: `mkdir -p /tmp/aur-test-v3.2.1 && cd /tmp/aur-test-v3.2.1`
- [ ] **Copy PKGBUILD**: `cp /home/rightguy/Dev/CloudToLocalLLM/packaging/aur/PKGBUILD .`
- [ ] **Update checksums**: `updpkgsums`
- [ ] **Build package**: `makepkg -si --noconfirm`
- [ ] **Verify contents**: `tar -tf *.pkg.tar.* | grep -v "cloudtolocalllm-settings" || echo "❌ Settings app found"`
- [ ] **Check size**: Package ~125MB
- [ ] **Test installation**: Package installs without errors

### Installation Testing
- [ ] **Verify version**: `pacman -Qi cloudtolocalllm-desktop | grep Version` shows 3.2.1
- [ ] **Critical check**: `test ! -f /usr/bin/cloudtolocalllm-settings`
- [ ] **Verify launchers**: `test -f /usr/bin/cloudtolocalllm && test -f /usr/bin/cloudtolocalllm-tray`
- [ ] **Test application**: `cloudtolocalllm &` → navigate to Settings → verify functionality
- [ ] **Test tray daemon**: `cloudtolocalllm-tray --help` executes without errors

### AUR Submission
- [ ] **Clone AUR repo**: `git clone ssh://aur@aur.archlinux.org/cloudtolocalllm-desktop.git`
- [ ] **Update files**: Copy PKGBUILD, generate .SRCINFO with `makepkg --printsrcinfo > .SRCINFO`
- [ ] **Verify metadata**: `grep -E "pkgver|pkgrel" .SRCINFO` shows 3.2.1, 1
- [ ] **Commit changes**: Descriptive commit message explaining architecture corrections
- [ ] **Push to AUR**: `git push origin master`

### Post-Publication Verification
- [ ] **Wait for indexing**: 1-2 minutes
- [ ] **Search package**: `yay -Ss cloudtolocalllm-desktop` shows v3.2.1
- [ ] **Test AUR install**: `yay -S cloudtolocalllm-desktop --noconfirm`
- [ ] **Final verification**: `test ! -f /usr/bin/cloudtolocalllm-settings`

**Phase 3 Gate**: ✅ AUR package published, installs correctly, architecture corrections verified

---

## 🎯 Final Verification Checklist

### Critical Success Criteria
- [ ] **No external settings app**: Zero cloudtolocalllm-settings executables in any distribution
- [ ] **Flutter settings functional**: All settings accessible and working in main app
- [ ] **Tray daemon scope correct**: Only system tray functions (show/hide/quit)
- [ ] **Package size maintained**: ~125MB unified architecture
- [ ] **Version consistency**: 3.2.1 across all distribution channels
- [ ] **Security standards**: All containers run as cloudllm:1001 (non-root)

### Distribution Channel Verification
- [ ] **GitHub Repository**: v3.2.1 tag and commits present
- [ ] **GitHub Release**: cloudtolocalllm-3.2.1-x86_64.tar.gz attached
- [ ] **Release Download**: Binary download works correctly
- [ ] **AUR Package**: Version 3.2.1-1 available via yay
- [ ] **VPS Deployment**: Server components only, no Python tray daemon

### User Experience Verification
- [ ] **Settings access**: Intuitive navigation to Settings screen
- [ ] **All settings present**: Appearance, LLM Provider, System Tray, Cloud & Sync, App Info
- [ ] **No external buttons**: Zero references to external settings applications
- [ ] **Controls functional**: All switches, dropdowns, buttons work correctly
- [ ] **Settings persistence**: Configuration survives app restarts

### Documentation and Communication
- [ ] **Migration guide**: Clear instructions for existing users
- [ ] **Release notes**: Comprehensive explanation of architecture changes
- [ ] **Support channels**: Ready to handle user questions
- [ ] **Rollback plan**: Documented and tested procedures

---

## 🚨 Emergency Procedures

### If Critical Issues Found
1. **STOP deployment immediately**
2. **Assess impact and scope**
3. **Execute rollback procedures**:
   - Revert AUR package to v3.2.0
   - Delete GitHub v3.2.1 release
   - Revert Git tags if necessary
4. **Communicate with users**
5. **Analyze root cause**
6. **Plan corrective release**

### Rollback Triggers
- External settings app found in any distribution
- Flutter settings screen non-functional
- Package installation failures >10%
- Security vulnerabilities discovered
- User migration failures >20%

---

## 📊 Success Metrics

### Technical Metrics (Target)
- **Build Success Rate**: 100%
- **Package Size**: 120-130MB
- **Installation Success**: 100%
- **Settings Functionality**: 100%

### User Experience Metrics (Target)
- **Migration Success**: >95%
- **Support Tickets**: <5
- **User Satisfaction**: >90%
- **Adoption Rate**: >80%

---

## 📋 Sign-off Requirements

### Phase 1 Approval
**Technical Lead**: _________________ Date: _________  
**Criteria**: All builds successful, architecture corrections verified

### Phase 2 Approval  
**Release Manager**: _________________ Date: _________  
**Criteria**: All distribution channels updated, VPS verified

### Phase 3 Approval
**Project Owner**: _________________ Date: _________  
**Criteria**: AUR published, user migration path clear

### Final Deployment Approval
**Deployment Lead**: _________________ Date: _________  
**Criteria**: All success criteria met, ready for user access

---

**Deployment Status**: 🟡 Ready to Execute  
**Next Action**: Begin Phase 1 - Application Building  
**Critical Reminder**: NO cloudtolocalllm-settings executable in ANY artifact
