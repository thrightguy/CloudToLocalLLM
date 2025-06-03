# CloudToLocalLLM Deployment Scripts

This directory contains production-ready deployment scripts for the CloudToLocalLLM application. All scripts follow security best practices and run without root privileges.

## 🚀 Quick Start

### Initial Deployment
```bash
# On VPS server as cloudllm user
cd /opt/cloudtolocalllm
./scripts/deploy_vps.sh
```

### Regular Updates
```bash
# Pull latest changes and rebuild
./scripts/update_deployment.sh
```

### Container Management
```bash
# Start/restart containers only
./scripts/docker_startup_vps.sh
```

## 📁 Directory Structure

### Core Deployment Scripts
- `deploy_vps.sh` - **Main deployment script** (non-root, production-ready)
- `docker_startup_vps.sh` - **Container startup script** (uses existing Let's Encrypt certs)
- `update_deployment.sh` - **Update script** for regular deployments

### Organized Script Directories

#### `/build/` - Build Scripts
- `build_appimage_manjaro.sh` - AppImage build script for Manjaro Linux
- `build_webapp_verbose.sh` - Verbose web application build script

#### `/deploy/` - Deployment Scripts
- `EXECUTE_VPS_DEPLOYMENT.sh` - VPS deployment execution script
- `VPS_DEPLOYMENT_COMMANDS.sh` - VPS deployment commands
- `VPS_DEPLOYMENT_VERIFICATION.sh` - VPS deployment verification

#### `/setup/` - Initial Setup Scripts
- `initial_server_setup.sh` - Initial server configuration
- `vps_initial_setup.sh` - VPS initial setup and configuration

#### `/release/` - Release Management
- `sf_upload.sh` - SourceForge file upload script for binary distribution

#### Other Directories
- `auth0/` - Auth0 integration scripts
- `docker/` - Docker-related utilities
- `install/` - Installation scripts for various components
- `maintenance/` - System maintenance scripts
- `packaging/` - Package creation scripts
- `powershell/` - Windows PowerShell scripts
- `ssl/` - SSL certificate management
- `utils/` - General utility scripts
- `verification/` - Deployment verification tools

### Root Scripts (Moved to Organized Folders)
Scripts previously in the project root have been moved to their appropriate directories:
- Debug scripts → `/scripts/`
- Deployment scripts → `/scripts/deploy/`
- Build scripts → `/scripts/build/`
- Setup scripts → `/scripts/setup/`
- Release scripts → `/scripts/release/`

## 🔧 Script Details

### `deploy_vps.sh` - Main Deployment Script
**Purpose**: Complete application deployment with Flutter build and Docker containers

**Features**:
- ✅ Non-root execution (requires Docker group membership)
- ✅ Comprehensive logging and error handling
- ✅ Flutter web application build
- ✅ Docker container management
- ✅ Deployment verification
- ✅ Uses existing Let's Encrypt certificates

**Usage**:
```bash
./scripts/deploy_vps.sh
```

**Requirements**:
- User in Docker group: `sudo usermod -aG docker $USER`
- Flutter installed and in PATH
- Existing Let's Encrypt certificates (optional but recommended)

### `docker_startup_vps.sh` - Container Startup
**Purpose**: Start Docker containers using existing configuration

**Features**:
- ✅ Non-root execution
- ✅ Uses existing Let's Encrypt certificates (no self-signed generation)
- ✅ Container health verification
- ✅ Proper error handling

**Usage**:
```bash
./scripts/docker_startup_vps.sh
```

### `update_deployment.sh` - Regular Updates
**Purpose**: Update application with latest code changes

**Features**:
- ✅ Git pull latest changes
- ✅ Rebuild Flutter application
- ✅ Restart containers with zero-downtime approach
- ✅ Verify deployment success

**Usage**:
```bash
./scripts/update_deployment.sh
```

### `release/sf_upload.sh` - SourceForge Upload
**Purpose**: Upload binary distribution files to SourceForge for AUR packaging

**Features**:
- ✅ Creates versioned binary archives
- ✅ Generates SHA256 checksums
- ✅ Uploads to SourceForge file hosting
- ✅ Provides AUR PKGBUILD integration URLs
- ✅ Automatic cleanup of local files

**Usage**:
```bash
# Upload with default version (v3.0.1)
./scripts/release/sf_upload.sh

# Upload with specific version
./scripts/release/sf_upload.sh v3.1.0
```

**Output**:
- Binary archive: `cloudtolocalllm-v3.0.1-binaries.tar.gz`
- Checksum file: `cloudtolocalllm-v3.0.1-binaries.tar.gz.sha256`
- SourceForge download URLs for AUR PKGBUILD integration

## 🔒 Security Features

### Non-Root Execution
- All scripts run as `cloudllm` user
- No `sudo` commands required during deployment
- Docker group membership provides necessary container access

### Certificate Management
- Uses existing Let's Encrypt certificates
- No self-signed certificate generation
- Proper certificate permissions (nginx user 101:101)

### Error Handling
- `set -e` and `set -u` for strict error handling
- Comprehensive logging to deployment.log
- Graceful failure recovery

## 📋 Prerequisites

### System Requirements
- Ubuntu/Debian VPS with Docker installed
- User added to Docker group: `sudo usermod -aG docker cloudllm`
- Flutter SDK installed and in PATH
- Git repository access

### Let's Encrypt Certificates (Recommended)
```bash
# Certificates should exist at:
/opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online/
```

### Directory Permissions
```bash
# Project directory owned by cloudllm user
sudo chown -R cloudllm:cloudllm /opt/cloudtolocalllm
```

## 🚦 Deployment Workflow

### 1. Initial Setup (One-time)
```bash
# Ensure user is in docker group
sudo usermod -aG docker cloudllm
newgrp docker

# Clone repository
git clone https://github.com/imrightguy/CloudToLocalLLM.git /opt/cloudtolocalllm
cd /opt/cloudtolocalllm

# Set permissions
sudo chown -R cloudllm:cloudllm /opt/cloudtolocalllm
```

### 2. Deploy Application
```bash
# Run main deployment script
./scripts/deploy_vps.sh
```

### 3. Regular Updates
```bash
# For code updates
./scripts/update_deployment.sh

# For container restarts only
./scripts/docker_startup_vps.sh
```

## 🌐 Application URLs

After successful deployment:
- **Homepage**: http://cloudtolocalllm.online
- **Web App**: http://app.cloudtolocalllm.online
- **HTTPS** (if certificates configured): https://cloudtolocalllm.online

## 🔧 Troubleshooting

### Common Issues

**Docker Permission Denied**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

**Flutter Not Found**
```bash
# Add Flutter to PATH in ~/.bashrc
export PATH="$PATH:/opt/flutter/bin"
source ~/.bashrc
```

**Container Startup Fails**
```bash
# Check logs
docker logs cloudtolocalllm-webapp
# Verify docker-compose.yml syntax
docker compose config
```

## 📝 Notes

- All scripts maintain backward compatibility with existing Docker setup
- Let's Encrypt certificates are preserved and reused
- No root privileges required for normal operations
- Comprehensive logging for troubleshooting
- Zero-downtime updates when possible