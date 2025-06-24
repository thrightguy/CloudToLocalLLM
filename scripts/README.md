# CloudToLocalLLM Scripts Documentation

**Version**: 3.6.9  
**Last Updated**: 2025-06-24

This directory contains all automation scripts for CloudToLocalLLM development, deployment, and maintenance.

## 📁 Directory Structure

### Core Scripts
- **build_time_version_injector.sh** - Injects build timestamps into application
- **build_unified_package.sh** - Creates unified packages for distribution
- **create_aur_binary_package.sh** - Creates AUR binary packages
- **flutter_build_with_timestamp.sh** - Builds Flutter apps with timestamp injection
- **version_manager.sh** - Manages version numbers and build metadata

### Deployment Scripts (`deploy/`)
- **complete_automated_deployment.sh** - Complete deployment automation
- **complete_deployment.sh** - Guided deployment workflow with rollback
- **deploy_to_vps.sh** - VPS deployment automation
- **deployment_utils.sh** - Deployment utility functions
- **fix_container_permissions.sh** - Fixes Docker container permissions
- **sync_versions.sh** - Synchronizes version information
- **update_and_deploy.sh** - Update and deploy workflow
- **verify_deployment.sh** - Comprehensive deployment verification

### Packaging Scripts (`packaging/`)
- **build_all_packages.sh** - Builds all Linux packages
- **build_aur.sh** - Builds AUR packages
- **build_snap.sh** - Builds Snap packages

### PowerShell Scripts (`powershell/`)
- **BuildEnvironmentUtilities.ps1** - Build environment utilities
- **Create-UnifiedPackages.ps1** - Unified package creation
- **Fix-CloudToLocalLLMEnvironment.ps1** - Environment fixes
- **build_time_version_injector.ps1** - PowerShell version injector
- **fix_line_endings.ps1** - Fixes line endings for bash scripts
- **flutter-setup.ps1** - Flutter development setup
- **version_manager.ps1** - PowerShell version management

### Release Scripts (`release/`)
- **clean_releases.ps1** - Release cleanup
- **check_for_updates.ps1** - Update checking
- **create_github_release.sh** - GitHub release creation
- **sf_upload.sh** - SourceForge upload
- **upload_release_assets.ps1** - GitHub release asset upload

### SSL Scripts (`ssl/`)
- **check_certificates.sh** - Certificate checking
- **manage_ssl.sh** - SSL management
- **setup_letsencrypt.sh** - Let's Encrypt setup

### Setup Scripts (`setup/`)
- **setup_almalinux9_server.sh** - AlmaLinux 9 server setup

### Docker Scripts (`docker/`)
- **docker_startup_vps.sh** - Docker startup for VPS
- **validate_dev_environment.sh** - Docker development environment validation

### Maintenance Scripts (`maintenance/`)
- **daily_maintenance.sh** - Daily maintenance tasks
- **weekly_maintenance.sh** - Weekly maintenance tasks
- **monthly_maintenance.sh** - Monthly maintenance tasks

### Backup Scripts (`backup/`)
- **full_backup.sh** - Comprehensive backup creation

### Utility Scripts
- **check_ssl_expiry.sh** - SSL certificate expiry monitoring
- **health_check.sh** - System health monitoring
- **optimize_performance.sh** - Performance optimization
- **performance_report.sh** - Performance analysis and reporting
- **security_scan.sh** - Security scanning and assessment
- **update_documentation.sh** - Documentation maintenance
- **verify_backups.sh** - Backup integrity verification

## 🚀 Quick Start

### Development Setup
```bash
# Set up Flutter development environment (Windows)
./scripts/powershell/flutter-setup.ps1

# Validate Docker development environment
./scripts/docker/validate_dev_environment.sh

# Build with timestamp injection
./scripts/flutter_build_with_timestamp.sh web
```

### Deployment
```bash
# Complete deployment workflow
./scripts/deploy/complete_deployment.sh

# Verify deployment
./scripts/deploy/verify_deployment.sh

# Quick VPS deployment
./scripts/deploy/deploy_to_vps.sh
```

### Maintenance
```bash
# Daily maintenance
./scripts/maintenance/daily_maintenance.sh

# System health check
./scripts/health_check.sh

# Performance optimization
./scripts/optimize_performance.sh

# Security scan
./scripts/security_scan.sh
```

### Package Building
```bash
# Build all Linux packages
./scripts/packaging/build_all_packages.sh

# Create AUR binary package
./scripts/create_aur_binary_package.sh

# Build unified packages (PowerShell)
./scripts/powershell/Create-UnifiedPackages.ps1
```

## 🔧 Platform Separation

### Bash Scripts (Linux/WSL/VPS Operations)
- All deployment scripts
- Linux package building
- SSL/certificate management
- Server setup and maintenance
- Docker operations
- System monitoring and health checks

### PowerShell Scripts (Windows Operations)
- Windows build environment setup
- Windows package creation
- Release asset management
- Development utilities

## 📋 Script Conventions

### Naming
- **Bash scripts**: kebab-case (e.g., `build-package.sh`)
- **PowerShell scripts**: PascalCase (e.g., `Build-Package.ps1`)

### Structure
- All scripts include help documentation (`--help` flag)
- Proper error handling with `set -euo pipefail`
- Colored output for better readability
- Logging functions for consistent output

### Documentation
- Each script includes a header comment describing its purpose
- Usage examples in help text
- Clear parameter documentation

## 🔍 Finding Scripts

Use the following commands to find scripts by purpose:

```bash
# Find all deployment scripts
find scripts -name "*deploy*" -type f

# Find all maintenance scripts
find scripts -name "*maintenance*" -type f

# Find all PowerShell scripts
find scripts -name "*.ps1" -type f

# Find scripts with specific functionality
grep -r "SSL" scripts/ --include="*.sh"
```

## 📚 Related Documentation

- [Main README](../README.md) - Project overview and setup
- [Deployment Guide](../docs/DEPLOYMENT/) - Detailed deployment instructions
- [Development Guide](../docs/DEVELOPMENT/) - Development workflow
- [Operations Guide](../docs/OPERATIONS/) - System operations and maintenance

---

**Note**: This documentation is automatically updated by `scripts/update_documentation.sh`. 
Last update: 2025-06-24
