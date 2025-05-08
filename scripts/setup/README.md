# CloudToLocalLLM Setup and Maintenance Scripts

This directory contains scripts for setting up, maintaining, and deploying the CloudToLocalLLM application.

## Key Scripts

### `update_and_deploy.sh`

The main deployment script that handles:
- Pulling the latest code from GitHub
- Fixing Android embedding issues
- Fixing Docker build configuration issues
- Cleaning the Flutter build
- Stopping, rebuilding, and restarting the admin daemon
- Deploying all services

Usage:
```bash
./scripts/setup/update_and_deploy.sh
```

### `migrate_android_v2.sh`

A comprehensive script to migrate Android embedding to V2, which is required for compatibility with plugins like `device_info_plus`. This script:
- Updates AndroidManifest.xml
- Updates MainActivity.kt
- Configures build.gradle with appropriate SDK versions

Usage:
```bash
./scripts/setup/migrate_android_v2.sh
```

### `fix_docker_build.sh`

A script to fix Flutter Docker build issues related to running as root. It:
- Adds environment variables to suppress root user warnings
- Updates Docker Compose configurations
- Modifies build commands to improve compatibility

Usage:
```bash
./scripts/setup/fix_docker_build.sh
```

### `docker_android_fix.sh`

A script designed to run inside Docker containers during build to fix Android embedding issues:
- Creates necessary directory structure
- Updates AndroidManifest.xml
- Creates MainActivity files
- Updates build.gradle

This script is automatically called by the Dockerfile and should not need to be run manually.

## Docker Compose Setup

A comprehensive `docker-compose.yml` file is included in the root directory that sets up all services:
- Web application
- Tunnel service
- FusionAuth
- Database
- Admin daemon
- Nginx for routing
- Certbot for SSL

Usage:
```bash
docker-compose up -d
```

## Troubleshooting

### Flutter Root User Warnings

If you see warnings about running Flutter as root, this is normal in Docker containers. Our scripts add environment variables to suppress these warnings:
```
FLUTTER_NO_ROOT_WARNING=true
```

### Android Embedding Issues

If you encounter errors related to Android embedding or plugin compatibility, try running the migration script:
```bash
./scripts/setup/migrate_android_v2.sh
```

### Docker Build Failures

If Docker builds fail, try:
1. Running the fix script: `./scripts/setup/fix_docker_build.sh`
2. Cleaning Docker: `docker system prune -a`
3. Rebuilding: `docker-compose build --no-cache`

## Maintenance

Regular maintenance tasks:
1. Run `./scripts/setup/update_and_deploy.sh` to get the latest code and deploy
2. Check logs with `systemctl status cloudllm-daemon.service`
3. Monitor Docker containers with `docker-compose ps`

For more detailed documentation, see the main project README. 