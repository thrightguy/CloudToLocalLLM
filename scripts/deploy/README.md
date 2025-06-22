# CloudToLocalLLM Deployment Scripts

This directory contains the deployment scripts for the CloudToLocalLLM application.

## Architecture Separation

**VPS Deployment (Linux-only):**
- All VPS deployment operations use bash scripts (.sh files) exclusively
- Must be executed via WSL (Arch Linux distribution) from Windows
- SSH operations to cloudtolocalllm.online VPS go through WSL
- Flutter web builds, Docker container management, and git operations use Linux commands only

**Windows Package Management:**
- Windows desktop application packaging (MSI, NSIS, Portable ZIP) handled by PowerShell scripts in `scripts/powershell/`
- Local Windows builds and testing use PowerShell scripts
- Windows-specific dependency management (Chocolatey, Windows features) stays in PowerShell

## Main Deployment Script

### `update_and_deploy.sh`
The primary deployment script for the VPS. This script handles the complete deployment workflow:

1. **Git Pull**: Pulls the latest changes from the repository
2. **Flutter Build**: Builds the Flutter web application on the VPS
3. **Container Management**: Stops existing containers and starts new ones
4. **Health Checks**: Verifies container health and web app accessibility
5. **SSL Verification**: Ensures SSL certificates are properly configured

#### Usage
```bash
# From WSL (Windows users)
wsl -d archlinux
cd /opt/cloudtolocalllm
bash scripts/deploy/update_and_deploy.sh

# On the VPS directly
cd /opt/cloudtolocalllm
bash scripts/deploy/update_and_deploy.sh
```

#### Prerequisites
- Flutter SDK installed on the VPS
- Docker and Docker Compose installed
- SSL certificates configured (Let's Encrypt)
- Proper file permissions for the cloudllm user

#### What it does
1. Pulls latest code from git
2. Runs `flutter clean && flutter pub get && flutter build web`
3. Stops running Docker containers
4. Starts containers with the new build
5. Performs health checks
6. Verifies web app accessibility

## Other Scripts

### `cleanup_containers.sh`
Utility script to clean up Docker containers and images.

### PowerShell Scripts
Various PowerShell scripts for Windows-based deployment scenarios (legacy).

## Deployment Workflow

### Complete Deployment Process
1. **Local Development**: Make changes and commit locally
2. **Push to Git**: `git push origin master`
3. **VPS Deployment**: SSH to VPS and run `scripts/deploy/update_and_deploy.sh`
4. **Verification**: Check that the app is accessible at https://app.cloudtolocalllm.online

### Security Notes
- All deployment operations run as the `cloudllm` user (non-root)
- SSL certificates are managed by Let's Encrypt
- Docker containers run with appropriate security settings

### Troubleshooting
- Check container logs: `docker compose -f docker-compose.yml logs`
- Verify container status: `docker compose -f docker-compose.yml ps`
- Check SSL certificates: `ls -la certbot/conf/live/cloudtolocalllm.online/`

## Cleaned Up Scripts
The following redundant scripts have been removed to maintain a clean deployment workflow:
- `scripts/deploy.sh`
- `scripts/clean_and_redeploy_web.sh`
- `scripts/deploy_diagnostic_fix.sh`
- `scripts/deploy_vps.sh`
- `scripts/deploy_with_ssl.sh`
- `scripts/update_deployment.sh`
- `scripts/deploy/deploy.sh`
- `scripts/deploy/deploy_from_github.sh`
- `scripts/deploy/deploy_portal.sh`
- `scripts/deploy/deploy_with_monitoring.sh`
- `scripts/deploy/deploy_commands.sh`

This ensures a single, clear deployment workflow using `update_and_deploy.sh`.
