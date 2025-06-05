# CloudToLocalLLM GitHub Release Workflow

This document describes the new GitHub release-based deployment workflow for CloudToLocalLLM, which replaces the previous SourceForge-based distribution method.

## Overview

The new workflow establishes GitHub releases as the primary distribution point for binary packages, providing better reliability and integration with the AUR package system.

### Workflow Steps

1. **Build Application** → Create binary packages locally
2. **Create GitHub Release** → Upload binaries to GitHub releases
3. **Update AUR Package** → Configure AUR to download from GitHub releases
4. **Deploy to VPS** → Update production environment
5. **Verify Deployment** → Ensure all components are synchronized

## Prerequisites

### Required Tools

```bash
# Install GitHub CLI
sudo pacman -S github-cli

# Authenticate with GitHub
gh auth login
```

### Required Permissions

- Write access to the CloudToLocalLLM repository
- AUR package maintainer access
- SSH access to cloudtolocalllm.online VPS

## Quick Start

### Complete Automated Workflow

```bash
# Run the complete deployment workflow
./scripts/deploy/complete_github_workflow.sh
```

This script handles all steps automatically:
- Builds the application
- Creates GitHub release
- Updates AUR package
- Deploys to VPS
- Verifies deployment

### Manual Step-by-Step

#### 1. Test Prerequisites

```bash
# Test GitHub release readiness
./scripts/test_github_release.sh
```

#### 2. Create GitHub Release

```bash
# Create release for current version
./scripts/release/create_github_release.sh
```

#### 3. Update AUR Package

```bash
cd aur-package/
makepkg -si --noconfirm
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "Update to v$(../scripts/version_manager.sh get-semantic)"
git push origin master
```

#### 4. Deploy to VPS

```bash
ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && ./scripts/deploy/update_and_deploy.sh"
```

## Scripts Reference

### `scripts/release/create_github_release.sh`

Creates GitHub releases with binary artifacts.

**Features:**
- Automatically detects version from pubspec.yaml
- Builds binary packages if needed
- Creates comprehensive release notes
- Uploads binary assets to GitHub
- Handles existing release conflicts

**Usage:**
```bash
./scripts/release/create_github_release.sh
```

### `scripts/deploy/complete_github_workflow.sh`

Complete automated deployment workflow.

**Features:**
- Checks all prerequisites
- Builds application and packages
- Creates GitHub release
- Updates and tests AUR package
- Deploys to VPS
- Verifies complete deployment

**Usage:**
```bash
./scripts/deploy/complete_github_workflow.sh
```

### `scripts/test_github_release.sh`

Tests GitHub release readiness without creating releases.

**Features:**
- Validates GitHub CLI setup
- Checks repository access
- Verifies binary packages exist
- Tests AUR configuration
- Reports readiness status

**Usage:**
```bash
./scripts/test_github_release.sh
```

## AUR Package Configuration

The AUR package now downloads from GitHub releases instead of local files:

```bash
# PKGBUILD source configuration
source=(
    "cloudtolocalllm-${pkgver}-x86_64.tar.gz::https://github.com/imrightguy/CloudToLocalLLM/releases/download/v${pkgver}/cloudtolocalllm-${pkgver}-x86_64.tar.gz"
    "cloudtolocalllm-${pkgver}-x86_64.tar.gz.sha256::https://github.com/imrightguy/CloudToLocalLLM/releases/download/v${pkgver}/cloudtolocalllm-${pkgver}-x86_64.tar.gz.sha256"
)
```

### Benefits

- **Reliability**: GitHub's CDN provides better download reliability
- **Automation**: Automatic version detection and download
- **Integrity**: SHA256 verification for all downloads
- **Consistency**: Single source of truth for all distributions

## Version Management

### Version Strategy

- **Major versions (x.0.0)**: Always create GitHub releases
- **Minor versions (x.y.0)**: Create GitHub releases for significant features
- **Patch versions (x.y.z)**: Create GitHub releases for important fixes
- **Build increments (x.y.z+nnn)**: No GitHub releases needed

### Version Commands

```bash
# Get current version
./scripts/version_manager.sh get-semantic

# Increment version
./scripts/version_manager.sh increment patch

# Set specific version
./scripts/version_manager.sh set 3.2.1
```

## Troubleshooting

### Common Issues

#### GitHub CLI Not Authenticated

```bash
# Error: GitHub CLI is not authenticated
gh auth login
```

#### Release Already Exists

```bash
# Delete existing release if needed
gh release delete v3.2.0 --repo imrightguy/CloudToLocalLLM --yes
git tag -d v3.2.0
git push origin --delete v3.2.0
```

#### Binary Package Not Found

```bash
# Build binary package
./scripts/create_unified_aur_package.sh
```

#### AUR Package Build Fails

```bash
# Clean and rebuild
cd aur-package/
rm -rf pkg/ src/ *.pkg.tar.zst
makepkg -si --noconfirm
```

### Verification Commands

```bash
# Check GitHub release
gh release view v3.2.0 --repo imrightguy/CloudToLocalLLM

# Check VPS deployment
curl -s https://app.cloudtolocalllm.online/version.json | jq '.version'

# Check AUR package
yay -Ss cloudtolocalllm
```

## Migration from SourceForge

The workflow has been migrated from SourceForge to GitHub releases for better integration and reliability:

### Changes Made

1. **PKGBUILD Updated**: Now downloads from GitHub releases
2. **Scripts Added**: New GitHub release automation scripts
3. **Workflow Integrated**: Complete deployment pipeline
4. **Documentation Updated**: Comprehensive workflow documentation

### Benefits of Migration

- **Better Integration**: Native GitHub ecosystem integration
- **Improved Reliability**: GitHub's robust CDN infrastructure
- **Automated Workflow**: Streamlined deployment process
- **Version Consistency**: Single source of truth for versions

## Security Considerations

### Binary Integrity

- All binary packages include SHA256 checksums
- Checksums are verified during AUR package installation
- GitHub releases provide tamper-evident distribution

### Access Control

- GitHub releases require repository write access
- AUR submissions require maintainer privileges
- VPS deployment uses SSH key authentication

## Support

For issues with the GitHub release workflow:

1. Check the troubleshooting section above
2. Run `./scripts/test_github_release.sh` for diagnostics
3. Review logs in `/tmp/cloudtolocalllm-*.log`
4. Open an issue on the GitHub repository

---

**Last Updated**: December 2024  
**Version**: 3.2.0+  
**Maintainer**: Christopher Maltais
