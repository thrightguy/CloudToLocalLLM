# CloudToLocalLLM Complete Deployment Workflow

## 🚨 **STOP FUCKING AROUND WITH PARTIAL DEPLOYMENTS** 🚨

This is the **ONE AND ONLY** deployment document for CloudToLocalLLM. Follow this exactly or you'll end up with the same version mismatch bullshit that's been plaguing this project.

---

## 📋 **Version Management - THE SINGLE SOURCE OF TRUTH**

### **pubspec.yaml is KING**
- **ALL** version information comes from `pubspec.yaml`
- Format: `MAJOR.MINOR.PATCH+BUILD` (e.g., `3.1.3+001`)
- **NEVER** manually edit version numbers anywhere else

### **Version Increment Process**
```bash
# Use the version manager script - ALWAYS
./scripts/version_manager.sh increment <type>

# Types:
# - major: Creates GitHub release (x.0.0) - significant changes
# - minor: Feature additions (x.y.0) - no GitHub release
# - patch: Bug fixes (x.y.z) - no GitHub release  
# - build: Build increments (x.y.z+nnn) - no GitHub release
```

### **Version Consistency Requirements**
Before ANY deployment, verify these files match pubspec.yaml version:
- `assets/version.json`
- `aur-package/PKGBUILD` (pkgver field)
- All build scripts and documentation

---

## 🔄 **COMPLETE DEPLOYMENT PROCESS**

### **Phase 1: Local Development & Version Management**

1. **Increment Version**
   ```bash
   # Determine increment type based on changes
   ./scripts/version_manager.sh increment patch  # or minor/major
   
   # Verify version updated correctly
   ./scripts/version_manager.sh info
   ```

2. **Update All Version References**
   ```bash
   # Update assets/version.json to match pubspec.yaml
   # Update aur-package/PKGBUILD pkgver field
   # This should be automated but verify manually
   ```

3. **Commit Version Changes**
   ```bash
   git add pubspec.yaml assets/version.json aur-package/PKGBUILD
   git commit -m "Version bump to $(./scripts/version_manager.sh get)"
   ```

4. **Push to SourceForge Git (PRIMARY)**
   ```bash
   # SourceForge is the single source of truth for deployments
   git push sourceforge master
   
   # Verify push succeeded
   git log --oneline -5
   ```

### **Phase 2: Build & Package Creation**

5. **Build Flutter Application**
   ```bash
   # Clean build
   flutter clean
   flutter pub get
   
   # Build for Linux desktop
   flutter build linux --release
   
   # Build for web (VPS deployment)
   flutter build web --release --no-tree-shake-icons
   ```

6. **Create Binary Package**
   ```bash
   # Create unified binary package for AUR
   ./scripts/build/create_unified_package.sh
   
   # Verify package created in dist/
   ls -la dist/cloudtolocalllm-*.tar.gz
   ```

7. **Upload to SourceForge File Hosting**
   ```bash
   # Upload binary package to SourceForge
   sftp imrightguy@frs.sourceforge.net
   # Navigate to /home/frs/project/cloudtolocalllm/releases/
   # Upload the tar.gz file and SHA256 checksum
   ```

### **Phase 3: AUR Package Deployment**

8. **Update AUR PKGBUILD**
   ```bash
   cd aur-package/
   
   # Update PKGBUILD with new version and checksums
   # Update source URLs to point to new SourceForge files
   # Update sha256sums with new checksums
   ```

9. **Test AUR Package Locally**
   ```bash
   # CRITICAL: Test before submission
   makepkg -si --noconfirm
   
   # Verify installation
   yay -U cloudtolocalllm-*.pkg.tar.zst
   
   # Test the installed package
   cloudtolocalllm --version
   ```

10. **Submit to AUR**
    ```bash
    # Only after local testing passes
    git add PKGBUILD .SRCINFO
    git commit -m "Update to version $(./scripts/version_manager.sh get)"
    git push origin master
    ```

### **Phase 4: VPS Deployment**

11. **Deploy to VPS**
    ```bash
    # SSH to VPS as cloudllm user
    ssh cloudllm@cloudtolocalllm.online
    
    # Navigate to project directory
    cd /opt/cloudtolocalllm
    
    # Run deployment script
    ./scripts/deploy/update_and_deploy.sh
    ```

12. **Verify VPS Deployment**
    ```bash
    # Check container status
    docker-compose -f docker-compose.yml ps
    
    # Verify web accessibility
    curl -I https://app.cloudtolocalllm.online
    curl -I https://cloudtolocalllm.online
    
    # Check version endpoint
    curl https://api.cloudtolocalllm.online/version
    ```

---

## ✅ **VERIFICATION REQUIREMENTS**

### **Cross-Component Synchronization Check**

**ALL THREE COMPONENTS MUST MATCH THE SAME VERSION:**

1. **Git Repository**
   ```bash
   # Check current version
   ./scripts/version_manager.sh get
   
   # Verify latest commit pushed
   git log --oneline -1
   ```

2. **VPS Deployment**
   ```bash
   # Check deployed version
   curl https://api.cloudtolocalllm.online/version
   
   # Verify container health
   ssh cloudllm@cloudtolocalllm.online "docker-compose ps"
   ```

3. **AUR Package**
   ```bash
   # Check AUR package version
   yay -Si cloudtolocalllm | grep Version
   
   # Verify package builds
   yay -G cloudtolocalllm && cd cloudtolocalllm && makepkg
   ```

### **Functional Testing Requirements**

- [ ] Desktop application launches and shows correct version
- [ ] Web application accessible and shows correct version  
- [ ] AUR package installs without errors
- [ ] System tray functionality works (if applicable)
- [ ] Authentication flow completes successfully
- [ ] Local Ollama connectivity works
- [ ] Cloud proxy functionality works

---

## 🚫 **DEPLOYMENT COMPLETION CRITERIA**

### **DEPLOYMENT IS NOT COMPLETE UNTIL:**

1. **Version Consistency Verified**
   - pubspec.yaml, assets/version.json, PKGBUILD all match
   - Git repository shows latest version committed and pushed
   - VPS deployment shows correct version in API response
   - AUR package shows correct version and builds successfully

2. **All Components Deployed**
   - SourceForge Git repository updated
   - Binary packages uploaded to SourceForge file hosting
   - AUR package submitted and building
   - VPS deployment completed and verified

3. **Comprehensive Testing Completed**
   - Local testing of all packages passed
   - VPS accessibility verified
   - AUR package installation tested
   - Functional testing completed

4. **Explicit Confirmation Given**
   - User has explicitly confirmed deployment completion
   - All verification steps documented and signed off
   - No outstanding issues or version mismatches

### **FAILURE CONDITIONS**

**DEPLOYMENT FAILS IF:**
- Any component shows different version numbers
- VPS deployment is inaccessible
- AUR package fails to build
- Functional testing reveals critical issues
- User has not explicitly confirmed completion

---

## 🔧 **Troubleshooting Common Issues**

### **Version Mismatch Issues**
```bash
# Reset all versions to pubspec.yaml
./scripts/version_manager.sh validate
./scripts/version_manager.sh info

# Update assets/version.json manually if needed
# Update PKGBUILD manually if needed
```

### **AUR Package Issues**
```bash
# Clean build environment
rm -rf src/ pkg/ *.pkg.tar.zst

# Rebuild from scratch
makepkg -si --noconfirm
```

### **VPS Deployment Issues**
```bash
# Check container logs
docker-compose -f docker-compose.yml logs

# Restart services
docker-compose -f docker-compose.yml down
docker-compose -f docker-compose.yml up -d
```

---

## 📞 **Support & Escalation**

If deployment fails or version mismatches occur:

1. **STOP** - Do not continue with partial deployment
2. **Document** the exact error and current state
3. **Rollback** if necessary to last known good state
4. **Fix** the root cause before proceeding
5. **Restart** the deployment process from Phase 1

**Remember: A partial deployment with version mismatches is worse than no deployment at all.**

---

## 🤖 **Automation Scripts**

### **Version Synchronization Script**
```bash
#!/bin/bash
# scripts/deploy/sync_versions.sh
# Ensures all version references match pubspec.yaml

PUBSPEC_VERSION=$(./scripts/version_manager.sh get-semantic)
PUBSPEC_BUILD=$(./scripts/version_manager.sh get-build)

# Update assets/version.json
cat > assets/version.json << EOF
{
  "version": "$PUBSPEC_VERSION",
  "build_number": "$PUBSPEC_BUILD",
  "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_commit": "$(git rev-parse --short HEAD)"
}
EOF

# Update AUR PKGBUILD
sed -i "s/^pkgver=.*/pkgver=$PUBSPEC_VERSION/" aur-package/PKGBUILD

echo "✅ All versions synchronized to $PUBSPEC_VERSION+$PUBSPEC_BUILD"
```

### **Complete Deployment Script**
```bash
#!/bin/bash
# scripts/deploy/complete_deployment.sh
# Executes the full deployment workflow

set -e

echo "🚀 Starting CloudToLocalLLM Complete Deployment"

# Phase 1: Version Management
echo "📋 Phase 1: Version Management"
read -p "Increment type (major/minor/patch/build): " INCREMENT_TYPE
./scripts/version_manager.sh increment "$INCREMENT_TYPE"
./scripts/deploy/sync_versions.sh

# Phase 2: Build & Package
echo "🔨 Phase 2: Build & Package"
flutter clean && flutter pub get
flutter build linux --release
flutter build web --release --no-tree-shake-icons
./scripts/build/create_unified_package.sh

# Phase 3: Git Operations
echo "📤 Phase 3: Git Operations"
git add pubspec.yaml assets/version.json aur-package/PKGBUILD
git commit -m "Version bump to $(./scripts/version_manager.sh get)"
git push sourceforge master

echo "✅ Deployment preparation complete!"
echo "🔄 Next steps:"
echo "1. Upload binaries to SourceForge file hosting"
echo "2. Test and submit AUR package"
echo "3. Deploy to VPS"
echo "4. Run verification checks"
```

### **Verification Script**
```bash
#!/bin/bash
# scripts/deploy/verify_deployment.sh
# Comprehensive deployment verification

EXPECTED_VERSION=$(./scripts/version_manager.sh get-semantic)

echo "🔍 Verifying CloudToLocalLLM Deployment v$EXPECTED_VERSION"

# Check Git repository
echo "📂 Checking Git repository..."
CURRENT_VERSION=$(./scripts/version_manager.sh get-semantic)
if [ "$CURRENT_VERSION" = "$EXPECTED_VERSION" ]; then
    echo "✅ Git repository version: $CURRENT_VERSION"
else
    echo "❌ Git repository version mismatch: $CURRENT_VERSION != $EXPECTED_VERSION"
    exit 1
fi

# Check VPS deployment
echo "🌐 Checking VPS deployment..."
VPS_VERSION=$(curl -s https://api.cloudtolocalllm.online/version | jq -r '.version' 2>/dev/null || echo "ERROR")
if [ "$VPS_VERSION" = "$EXPECTED_VERSION" ]; then
    echo "✅ VPS deployment version: $VPS_VERSION"
else
    echo "❌ VPS deployment version mismatch: $VPS_VERSION != $EXPECTED_VERSION"
fi

# Check AUR package
echo "📦 Checking AUR package..."
AUR_VERSION=$(grep "^pkgver=" aur-package/PKGBUILD | cut -d'=' -f2)
if [ "$AUR_VERSION" = "$EXPECTED_VERSION" ]; then
    echo "✅ AUR package version: $AUR_VERSION"
else
    echo "❌ AUR package version mismatch: $AUR_VERSION != $EXPECTED_VERSION"
fi

echo "🎯 Deployment verification complete!"
```

---

## 📚 **Documentation Cleanup**

### **Deprecated Documents**
The following documents are **OBSOLETE** and should be ignored:
- `docs/DEPLOYMENT.md` (generic, outdated)
- `docs/DEPLOYMENT_CHECKLIST_ENHANCED.md` (too complex, outdated)
- `docs/DEPLOYMENT_INSTRUCTIONS.md` (incomplete)
- `docs/DEPLOYMENT_SUMMARY.md` (partial information)
- `docs/VPS_DEPLOYMENT.md` (VPS-only, incomplete)

### **Active Documents**
- **THIS DOCUMENT** (`docs/COMPLETE_DEPLOYMENT_WORKFLOW.md`) - **THE ONLY DEPLOYMENT GUIDE**
- `docs/VERSIONING_STRATEGY.md` - Version format reference
- `scripts/version_manager.sh` - Version management tool

---

## 🎯 **Success Metrics**

### **Deployment Success Indicators**
- All three components show identical version numbers
- VPS responds with correct version in API
- AUR package builds without errors
- Desktop application launches with correct version
- No version-related support tickets

### **Failure Indicators**
- Version mismatches between any components
- VPS deployment shows wrong version
- AUR package fails to build
- User reports version confusion
- Multiple deployment attempts needed

---

*This document eliminates the confusion and ensures consistent, complete deployments. Follow it exactly or face the wrath of version mismatch hell.*
