# CloudToLocalLLM Deployment Instructions

**This document may contain outdated information. Always refer to `VPS_DEPLOYMENT.md` for the most current and comprehensive VPS deployment procedures.**

## Server Requirements
- Linux VPS (tested on Ubuntu/Debian)
- A dedicated non-root user (e.g., `cloudllm`) for application management. Root access is needed for initial setup and system-level tasks.
- Ports 80 and 443 open
- Domain name pointing to the VPS IP (e.g., cloudtolocalllm.online)

## Deployment Process

### 1. SSH to Your Server
Log in as your non-root user (e.g., `cloudllm`):
```bash
ssh cloudllm@your_vps_ip_or_domain
```
Initial server setup (installing Docker, git, etc.) might require `root` or `sudo`.

### 2. Initial Deployment / Updates
The simplest way to deploy or update is using the main deployment script (e.g., `scripts/setup/docker_startup_vps.sh`).

```bash
# Navigate to the application directory
cd /opt/cloudtolocalllm

# Pull the latest changes from GitHub
git pull origin master # Or your main branch

# Ensure scripts are executable (usually done once)
# chmod +x scripts/setup/*.sh 

# Run the main deployment/startup script
bash scripts/setup/docker_startup_vps.sh # Replace with your actual script name
```

This script typically handles:
1. Pulling the latest changes from GitHub (though often done manually before running the script).
2. Building/rebuilding Docker images if necessary.
3. Starting/restarting Docker containers using `docker compose`.
4. Setting up SSL certificates via Certbot.
5. Applying necessary file permissions.

### 3. Adding Beta Subdomain with Authentication
If applicable, specific scripts might handle adding subdomains or features. Refer to relevant documentation or script comments.

### 4. Verify Deployment

After deployment completes, verify the services are running:

```bash
# Use Docker Compose v2 syntax
docker compose ps
```

Check that the portal is accessible by visiting:
- https://cloudtolocalllm.online (should show static landing page)
- https://app.cloudtolocalllm.online (should show the Flutter web application)
- Other subdomains as configured.

### 5. Troubleshooting

Refer to the troubleshooting section in `VPS_DEPLOYMENT.md`. Key areas:
- **Container Logs**: `docker compose logs webapp` (or other services).
- **Nginx Configuration**: Check for syntax errors (`docker exec cloudtolocalllm-webapp nginx -t`). The configuration is usually mounted from `config/nginx/nginx-webapp-internal.conf`.
- **SSL Certificates**: Ensure certificates exist in `/opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online/` and have correct permissions (readable by Nginx user 101:101).
- **`static_homepage` Directory**: Ensure `/opt/cloudtolocalllm/static_homepage/index.html` exists for the main domain's landing page.

#### SSL Certificate Issues
If SSL certificate doesn't work properly:
```bash
# Check certbot container logs
docker compose logs certbot

# List certificates known to certbot (run from host, mounts are relative to docker-compose.yml)
# This command might need adjustment based on your certbot container setup.
# A simpler check is to inspect the cert files on the host:
ls -la /opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online/
```

#### Nginx Configuration Issues
If the server won't start due to nginx configuration issues:
```bash
# Check webapp container logs for specific Nginx errors
docker compose logs webapp

# Test Nginx configuration inside the container
docker exec cloudtolocalllm-webapp nginx -t
```
If `nginx-webapp-internal.conf` was modified, ensure changes are valid and then restart:
```bash
docker compose restart webapp
```

#### Server Configuration Issues
If you need to update the server configuration for multiple domains:
```bash
# Edit the server.conf file
nano server.conf

# Then rebuild and restart the container
docker-compose -f docker-compose.web.yml down
docker-compose -f docker-compose.web.yml build webapp
docker-compose -f docker-compose.web.yml up -d
```

#### Auth Service Issues
If the authentication service isn't working properly:
```bash
# Check the auth service logs
docker-compose -f docker-compose.web.yml logs auth

# Restart just the auth service
docker-compose -f docker-compose.web.yml restart auth
```

**If the auth container fails to start due to missing ./bin/server:**
1. Check Docker build logs:
   ```bash
   docker-compose -f docker-compose.web.yml build auth
   ```
2. Try building the binary locally:
   ```bash
   cd auth_service
   dart pub get
   dart compile exe bin/auth_service.dart -o bin/server
   ```
3. Fix any Dart errors and retry the build.

#### Webapp Build Issues
If the webapp build fails (usually handled by Docker image build process):
1. Check Docker build logs if you're building images on the VPS:
   ```bash
   docker compose build webapp # Or the service that failed
   ```
2. Ensure your Flutter SDK (if building locally before pushing image) is compatible.

### 6. Maintenance

#### Regular Updates
To update the application with the latest changes:
```bash
cd /opt/cloudtolocalllm
git pull origin master
bash scripts/setup/docker_startup_vps.sh # Or your main deployment script
```

#### Renew SSL Certificates
SSL certificates managed by Certbot (via the `certbot` container) are typically set to auto-renew. You can check the `certbot` container logs for renewal activity.
Manual renewal can often be triggered by restarting the `certbot` container or running a specific renewal command if provided by your setup.

## Services Architecture

- **Webapp Service**: Flutter web frontend with Nginx
- **Auth Service**: Authentication service for the beta subdomain
- **Tunnel Service**: Node.js Express server for cloud synchronization
- **SSL**: Managed by Certbot with auto-renewal

## Important Files

- `docker-compose.yml`: Main Docker Compose configuration.
- `config/nginx/nginx-webapp-internal.conf`: Nginx server blocks configuration for the webapp.
- `scripts/setup/docker_startup_vps.sh` (or similar): Main deployment/startup script