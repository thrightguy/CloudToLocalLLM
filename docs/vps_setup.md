# CloudToLocalLLM VPS Setup Guide

This document provides instructions for setting up the CloudToLocalLLM stack on a VPS.

## Prerequisites

- A Linux VPS (tested on Ubuntu 22.04/Debian 11/12)
- Root access to the VPS
- Docker and Docker Compose installed
- Git installed

## Container Base Image

**All containers, including the admin daemon, web, and tunnel services, use the [ghcr.io/cirruslabs/flutter:latest](https://github.com/cirruslabs/docker-images-flutter) image as the base.**

- This ensures full Flutter and Dart support everywhere.
- The admin daemon container also installs the Docker CLI and Compose plugin for service management.

## Installation Options

There are two approaches to setting up the CloudToLocalLLM stack:

1. **Daemon-based approach** - Runs the admin daemon as a systemd service with a dedicated user
2. **Docker-based approach** - Runs the admin daemon in a Docker container (recommended)

### Option 1: Daemon-based Approach

1. Clone the repository:
   ```bash
   cd /opt
   git clone https://github.com/thrightguy/CloudToLocalLLM.git cloudtolocalllm
   cd cloudtolocalllm
   ```

2. Run the startup script:
   ```bash
   bash scripts/setup/startup_vps.sh
   ```

### Option 2: Docker-based Approach (Recommended)

1. Clone the repository:
   ```bash
   cd /opt
   git clone https://github.com/thrightguy/CloudToLocalLLM.git cloudtolocalllm
   cd cloudtolocalllm
   ```

2. Run the Docker-based startup script:
   ```bash
   bash scripts/setup/docker_startup_vps.sh
   ```

3. (Optional) Install as a systemd service:
   ```bash
   cp config/systemd/cloudllm-docker.service /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable cloudllm-docker
   systemctl start cloudllm-docker
   ```

---

**Note:** All containers are built from the same Flutter image for consistency and easier management.

## Troubleshooting

### Common Issues

#### Permission Problems

If you encounter permission issues with Dart or Flutter:

```bash
# Fix ownership of the installation directory
chown -R cloudllm:cloudllm /opt/cloudtolocalllm

# Fix permissions for the pub cache
mkdir -p /home/cloudllm/.pub-cache
chown -R cloudllm:cloudllm /home/cloudllm/.pub-cache
```

#### Flutter Not Initialized

If Flutter is not initialized for the cloudllm user:

```bash
# Switch to the cloudllm user
su - cloudllm

# Initialize Flutter
flutter --version

# Exit back to root
exit
```

#### Admin Daemon Not Responding

Check the admin daemon logs:

```bash
# For daemon-based approach
journalctl -u cloudllm-daemon

# For Docker-based approach
docker logs cloudtolocalllm-admin-daemon-1
```

## API Endpoints

The admin daemon provides the following API endpoints:

- `GET /admin/health` - Check if the daemon is running
- `POST /admin/deploy/web` - Deploy the web service
- `POST /admin/deploy/fusionauth` - Deploy FusionAuth
- `POST /admin/stop/web` - Stop the web service
- `POST /admin/stop/fusionauth` - Stop FusionAuth
- `POST /admin/git/pull` - Pull the latest code
- `POST /admin/ssl/issue-renew` - Issue or renew SSL certificates
- `POST /admin/deploy/all` - Deploy all services 