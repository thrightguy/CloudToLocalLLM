# CloudToLocalLLM Script-First Resolution Guide

## Overview

The "Script-First Resolution" principle is a core deployment philosophy for CloudToLocalLLM that emphasizes using existing automation scripts rather than manual file operations or ad-hoc commands. This approach ensures consistency, reliability, and maintainability across all deployment processes.

## Core Principle

**Always use existing automation scripts instead of manual operations.**

### ✅ Correct Approach
```bash
# Use automation scripts
./scripts/version_manager.sh increment patch
./scripts/deploy/sync_versions.sh
./scripts/create_aur_binary_package.sh
./scripts/deploy/submit_aur_package.sh --force --verbose
```

### ❌ Incorrect Approach
```bash
# Manual file editing and git commands
sed -i 's/3.5.13/3.5.14/' pubspec.yaml
git add . && git commit -m "Update version"
cd aur-package && git push origin master
```

## AUR Deployment Best Practices

### Mandatory AUR Submission Process

**ALWAYS use the automation script:**
```bash
./scripts/deploy/submit_aur_package.sh --force --verbose
```

**NEVER use manual git commands:**
```bash
# ❌ WRONG - Manual process prone to errors
cd aur-package
git add PKGBUILD .SRCINFO
git commit -m "Update to v3.5.14"
git push origin master
```

### Mandatory AUR Installation Verification

**Phase 6 completion requires real-world AUR testing:**

```bash
# 1. Clear yay cache (if testing updated packages)
yay -Sc --noconfirm
rm -rf ~/.cache/yay/cloudtolocalllm  # Force clean build

# 2. Test real AUR installation (DEPLOYMENT GATE)
yay -S cloudtolocalllm --noconfirm

# 3. Verify correct version
cloudtolocalllm --version  # Must show correct version in logs

# 4. Clean up test installation
yay -R cloudtolocalllm --noconfirm
```

**Why `yay -S` is mandatory:**
- Tests complete deployment chain: Git → GitHub raw URLs → AUR → User installation
- Validates SHA256 checksums from live GitHub distribution
- Confirms package extraction with correct directory structure
- Simulates real user experience, not just local testing

**Why `pacman -U` is insufficient:**
- Only tests local package files, not the GitHub distribution chain
- Doesn't validate AUR repository updates
- Misses real-world download and checksum verification
- Can pass locally while failing for actual users

## Distribution Package Creation

### Fixed Issues in v3.5.14

**Problem:** `scripts/create_aur_binary_package.sh` had binary file management conflicts
**Solution:** Permanently disabled problematic binary file management

```bash
# Binary file management permanently disabled for AUR packages
# AUR packages use GitHub raw URL distribution - no file splitting needed
```

**Archive Structure Requirements:**
- Must create `cloudtolocalllm-${pkgver}-x86_64/` directory structure
- AUR PKGBUILD expects subdirectory, not flat extraction
- Unified architecture: Tray daemon is optional, not required

## Common Deployment Mistakes

### 1. Manual File Operations
```bash
# ❌ WRONG
tar -czf dist/package.tar.gz -C build/linux/x64/release/bundle .
sed -i 's/old_checksum/new_checksum/' aur-package/PKGBUILD

# ✅ CORRECT
./scripts/create_aur_binary_package.sh
```

### 2. Skipping Real AUR Testing
```bash
# ❌ WRONG - Local testing only
cd aur-package && makepkg -si --noconfirm

# ✅ CORRECT - Real AUR testing
yay -S cloudtolocalllm --noconfirm
```

### 3. Manual AUR Submission
```bash
# ❌ WRONG - Manual git operations
cd aur-package
git add . && git commit && git push

# ✅ CORRECT - Automation script
./scripts/deploy/submit_aur_package.sh --force --verbose
```

## Deployment Verification Chain

### Complete Validation Required

1. **Git Repository**: Changes committed and pushed to master
2. **GitHub Raw URLs**: Distribution files accessible via raw.githubusercontent.com
3. **AUR Repository**: PKGBUILD updated with correct checksums
4. **User Installation**: `yay -S cloudtolocalllm` downloads and installs correctly
5. **Application Launch**: Correct version reported in application logs

### Deployment Gates

**Phase 4 Gate**: Distribution package created with correct structure
**Phase 5 Gate**: VPS deployment successful with live endpoints
**Phase 6 Gate**: MANDATORY real AUR installation verification passed

## Script Inventory

### Version Management
- `./scripts/version_manager.sh` - Version increment and synchronization
- `./scripts/deploy/sync_versions.sh` - Cross-file version consistency

### Build and Distribution
- `./scripts/create_aur_binary_package.sh` - Create AUR distribution package
- `./scripts/deploy/submit_aur_package.sh` - Submit to AUR repository

### Deployment
- `./scripts/deploy/update_and_deploy.sh` - VPS deployment
- `./scripts/deploy/complete_automated_deployment.sh` - Full 6-phase deployment

### Verification
- `./scripts/deploy/verify_deployment.sh` - Post-deployment validation

## Emergency Procedures

### If Automation Scripts Fail

1. **Identify root cause** in the script, don't bypass with manual operations
2. **Fix the script** to handle the edge case
3. **Test the fix** with dry-run modes where available
4. **Document the fix** for future deployments

### If AUR Installation Fails

1. **Check GitHub raw URLs** are accessible
2. **Verify SHA256 checksums** match between dist/ and AUR PKGBUILD
3. **Clear yay cache** and retry: `rm -rf ~/.cache/yay/cloudtolocalllm`
4. **Check AUR repository** was actually updated (not just local files)

## Success Indicators

### Deployment Complete When:
- ✅ All automation scripts executed successfully
- ✅ Live web endpoints serve correct version
- ✅ AUR repository updated with correct PKGBUILD
- ✅ Real `yay -S cloudtolocalllm` installation successful
- ✅ Application reports correct version in logs
- ✅ No manual interventions required

**Remember: If you need manual intervention, the automation needs improvement, not bypassing.**
