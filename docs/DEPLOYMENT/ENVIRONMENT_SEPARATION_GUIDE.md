# CloudToLocalLLM Environment Separation Guide

## Overview

CloudToLocalLLM uses a clear separation between Windows and Linux environments to ensure clean, maintainable deployment workflows. This guide outlines the architecture and provides workflow examples.

## Architecture Separation

### VPS Deployment (Linux-only)

**Environment**: WSL (Arch Linux distribution) → SSH → Linux VPS  
**Purpose**: Deploy web applications to cloudtolocalllm.online VPS  
**Tools**: Bash scripts (.sh files) exclusively  

**Key Principles:**
- All VPS deployment operations use bash scripts in `scripts/deploy/` directory
- Must be executed via WSL (Ubuntu distribution) from Windows
- SSH operations to cloudtolocalllm.online VPS go through WSL
- Flutter web builds, Docker container management, and git operations use Linux commands only
- No PowerShell scripts for VPS deployment

**Main Scripts:**
- `scripts/deploy/update_and_deploy.sh` - Primary VPS deployment script
- `scripts/deploy/deploy_to_vps.sh` - VPS deployment script
- `scripts/deploy/complete_automated_deployment.sh` - Complete deployment workflow
- `scripts/deploy/sync_versions.sh` - Version synchronization

### Windows Package Management (PowerShell-only)

**Environment**: Windows Terminal → PowerShell → Local Windows operations  
**Purpose**: Build and package Windows desktop applications  
**Tools**: PowerShell scripts (.ps1 files) exclusively  

**Key Principles:**
- Windows desktop application packaging (MSI, NSIS, Portable ZIP) handled by PowerShell scripts
- Local Windows builds and testing use PowerShell scripts
- Windows-specific dependency management (Chocolatey, Windows features) stays in PowerShell
- Linux package creation uses WSL integration but orchestrated by PowerShell
- No bash scripts for Windows packaging

**Main Scripts:**
- `scripts/powershell/Create-UnifiedPackages.ps1` - Unified package creator
- `scripts/powershell/build_unified_package.ps1` - Windows builds
- `scripts/powershell/build_all_packages.ps1` - Package management
- `scripts/powershell/version_manager.ps1` - Version management

## Workflow Examples

### VPS Deployment Workflow

**From Windows:**
```powershell
# 1. Open Windows Terminal
# 2. Access WSL Arch Linux distribution
wsl -d archlinux

# 3. Navigate to project directory
cd /opt/cloudtolocalllm

# 4. Execute VPS deployment
bash scripts/deploy/update_and_deploy.sh --force --verbose

# 5. Verify deployment
curl -s https://app.cloudtolocalllm.online/version.json | jq '.version'
```

**Direct on VPS:**
```bash
# SSH to VPS
ssh cloudllm@cloudtolocalllm.online

# Navigate to project
cd /opt/cloudtolocalllm

# Deploy
bash scripts/deploy/update_and_deploy.sh --force
```

### Windows Package Creation Workflow

**From Windows PowerShell:**
```powershell
# 1. Open Windows Terminal (PowerShell)
# 2. Navigate to project directory
cd C:\Users\chris\Dev\CloudToLocalLLM

# 3. Create Windows packages only
.\scripts\powershell\Create-UnifiedPackages.ps1 -WindowsOnly -AutoInstall

# 4. Create all packages (Windows + Linux via WSL)
.\scripts\powershell\Create-UnifiedPackages.ps1 -AutoInstall

# 5. Build specific Windows package
.\scripts\powershell\build_unified_package.ps1 windows -Clean -AutoInstall
```

### Version Management Workflow

**From Windows PowerShell:**
```powershell
# Update version across all files
.\scripts\powershell\version_manager.ps1 set-version 3.7.0

# Get current version
.\scripts\powershell\version_manager.ps1 get-semantic

# Increment version
.\scripts\powershell\version_manager.ps1 increment-patch
```

## Directory Structure

```
CloudToLocalLLM/
├── scripts/
│   ├── deploy/                    # Linux VPS deployment (bash only)
│   │   ├── update_and_deploy.sh   # Main VPS deployment script
│   │   ├── deploy_unified_web_architecture.sh
│   │   ├── VPS_DEPLOYMENT_COMMANDS.sh
│   │   └── *.sh                   # All VPS deployment scripts
│   │
│   └── powershell/                # Windows package management (PowerShell only)
│       ├── Create-UnifiedPackages.ps1
│       ├── build_unified_package.ps1
│       ├── version_manager.ps1
│       └── *.ps1                  # All Windows packaging scripts
│
├── docs/
│   └── DEPLOYMENT/
│       ├── ENVIRONMENT_SEPARATION_GUIDE.md  # This document
│       └── COMPLETE_DEPLOYMENT_WORKFLOW.md  # Main deployment guide
```

## Environment Requirements

### For VPS Deployment
- WSL with Arch Linux distribution installed
- SSH access to cloudtolocalllm.online VPS
- Git configured in WSL
- Flutter SDK in WSL (auto-installed with scripts)

### For Windows Package Management
- Windows 10/11 with PowerShell 5.1+
- Chocolatey (auto-installed with -AutoInstall)
- Flutter SDK for Windows
- Visual Studio Build Tools (auto-installed)
- WiX Toolset for MSI packages (auto-installed)
- NSIS for NSIS installers (auto-installed)

## Best Practices

### Do's
✅ Use bash scripts for all VPS deployment operations  
✅ Use PowerShell scripts for all Windows packaging operations  
✅ Execute VPS deployments via WSL from Windows  
✅ Use -AutoInstall parameter for dependency management  
✅ Follow the established script naming conventions  
✅ Test deployments with --dry-run flags when available  

### Don'ts
❌ Create PowerShell scripts for VPS deployment  
❌ Create bash scripts for Windows packaging  
❌ Mix deployment environments in single scripts  
❌ Manually edit package configuration files  
❌ Bypass the GitHub-based deployment workflow  
❌ Use manual file operations instead of automated scripts  

## Troubleshooting

### VPS Deployment Issues
1. **SSH Connection Failed**: Ensure SSH keys are properly configured in WSL
2. **Flutter Build Failed**: Check Flutter SDK installation in WSL
3. **Docker Issues**: Verify Docker permissions on VPS
4. **SSL Certificate Issues**: Check Let's Encrypt certificate status

### Windows Package Issues
1. **Build Tools Missing**: Use -AutoInstall parameter
2. **WSL Not Available**: Install WSL for Linux package creation
3. **Permission Denied**: Run PowerShell as Administrator if needed
4. **Flutter SDK Issues**: Verify Flutter installation and PATH

## Migration Notes

This architecture separation was implemented to eliminate complexity and ensure clean environment boundaries. Previous hybrid PowerShell/WSL scripts for VPS operations have been removed in favor of this clear separation.

**Removed Scripts:**
- `scripts/powershell/deploy_vps.ps1`
- `scripts/deploy/deploy_vps_powershell.ps1`
- Various PowerShell VPS deployment scripts in `scripts/deploy/`

**Migration Path:**
- VPS deployment: Use `scripts/deploy/update_and_deploy.sh` via WSL
- Windows packaging: Use `scripts/powershell/Create-UnifiedPackages.ps1`
