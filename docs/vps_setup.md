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

## Improved Error Handling and Troubleshooting

- The startup script now waits for the admin daemon to be healthy before deploying services.
- If any service fails to start or is unhealthy, the admin daemon will return detailed error messages and recent logs in the API response.
- The startup script will print these errors and suggest how to get further logs.

## Troubleshooting Deployment Failures

If the deployment fails:
- The script will print the error and the relevant logs for unhealthy containers.
- You can also check the admin daemon logs with:
  ```bash
  docker logs docker-admin-daemon-1
  ```
- For individual service logs, use:
  ```bash
  docker logs <container-name>
  ```

If you need to provide errors for support, copy the output from the script and the relevant logs.

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