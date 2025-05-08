# CloudToLocalLLM VPS Deployment Guide

This guide provides step-by-step instructions for deploying the CloudToLocalLLM portal to your VPS.

## VPS Deployment Directory Structure

It is recommended to deploy the CloudToLocalLLM application to `/opt/cloudtolocalllm/` on your VPS. After cloning the repository to this location, the structure will mirror the Git repository:

```
/opt/cloudtolocalllm/
├── admin_control_daemon/   # New Dart daemon for admin tasks
├── admin-ui/               # Vue.js Admin UI
├── assets/                 # Static assets for the Flutter application
├── auth_service/           # Dart Authentication Service
├── backend/                # Backend services (includes tunnel_service)
├── config/                 # Centralized configuration files
│   ├── docker/             # Docker-compose files and service-specific Dockerfiles (e.g., Dockerfile, Dockerfile.web)
│   ├── nginx/              # Nginx configurations
│   └── systemd/            # Systemd service unit files
├── docs/                   # Project documentation
├── installers/             # Installer scripts (e.g., Inno Setup for Windows)
├── lib/                    # Main Flutter application source code
├── releases/               # (Gitignored) Place for release binaries like .zip, .exe
├── scripts/                # Various utility and operational scripts
├── secrets/                # (Gitignored) For local secrets, keys not for version control
├── static_portal_files/    # Static HTML files for a potential simple Nginx portal root
├── tools/                  # Developer tools, third-party installers
├── ... (standard Flutter project directories like android/, ios/, web/, windows/, etc.)
├── .gitignore
├── CONTRIBUTING.md
├── LICENSE                 # (To be created) Project License file
├── README.md
├── package.json
├── pubspec.yaml
└── ... (other root project files)
```

**Deployment Location for Key Components:**

*   **Main Application Code:** `/opt/cloudtolocalllm/` (entire cloned repository)
*   **Compiled `admin_control_daemon`:** `/opt/cloudtolocalllm/admin_control_daemon/bin/admin_daemon`
*   **Docker Configuration:** Primarily in `/opt/cloudtolocalllm/config/docker/` (e.g., `docker-compose.auth.yml`, `docker-compose.web.yml`, `Dockerfile`).
*   **Persistent Docker Data:** Docker volumes will be managed by Docker, typically under `/var/lib/docker/volumes/`. For example, `postgres_data` for the auth database.
*   **SSL Certificates (Certbot):** If using Certbot, certificates are usually in `/etc/letsencrypt/`. The `certbot/` directory in the project root (`/opt/cloudtolocalllm/certbot/` on VPS) is used by `docker-compose.web.yml` which mounts `./certbot/conf:/etc/letsencrypt` and `./certbot/www:/var/www/certbot`. This implies Certbot is run such that its configuration and challenge files are placed here.

## Prerequisites
- VPS with Ubuntu/Debian Linux
- Domain name pointed to your VPS (cloudtolocalllm.online)
- SSH access to your VPS
- Ports 80 & 443 open in your firewall

## Deployment Steps

### 1. Initial Server Setup

```bash
# SSH into your server
ssh root@your-server-ip

# Update the system
apt update && apt upgrade -y

# Install basic tools if needed
apt install -y curl git
```

### 2. Deploy the Application

```bash
# Create deployment directory
mkdir -p /opt/cloudtolocalllm/portal
cd /opt/cloudtolocalllm/portal

# Clone the repository
git clone https://github.com/thrightguy/CloudToLocalLLM.git .

# Make scripts executable
chmod +x *.sh

# Run the deploy script
./deploy_commands.sh
```

The deployment script will:
1. Pull the latest changes from GitHub
2. Install Docker and Docker Compose (if not present)
3. Create necessary directories
4. Deploy the application with Docker Compose
5. Set up SSL certificates automatically

### 3. Verify Deployment

After the deployment completes successfully:

1. Check that containers are running:
   ```bash
   docker-compose -f docker-compose.web.yml ps
   ```

2. Visit your domain in a browser:
   ```
   https://cloudtolocalllm.online
   ```

3. Verify SSL certificate is working properly:
   ```bash
   docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" certbot/certbot certificates
   ```

### 4. Troubleshooting

#### Fix Nginx Configuration
If you encounter issues with the Nginx configuration:
```bash
./fix_nginx.sh
```

#### Fix Permission Issues
If there are permission issues with the Docker containers:
```bash
./fix_user_permissions.sh
```

#### Rebuild and Redeploy
For a complete rebuild and redeploy:
```bash
./fix_and_deploy.sh
```

### 5. Maintaining Your Deployment

#### Update the Application
```bash
# Pull latest changes and restart
cd /opt/cloudtolocalllm/portal
git pull origin master
./deploy_commands.sh
```

#### Manual SSL Certificate Renewal
SSL certificates will auto-renew, but you can trigger manually:
```bash
./renew-ssl.sh
```

#### Backup Your Data
Backup critical files and directories:
```bash
mkdir -p /backups
tar -czf /backups/cloudtolocalllm-$(date +%Y%m%d).tar.gz \
    /opt/cloudtolocalllm/portal/certbot \
    /opt/cloudtolocalllm/portal/auth_service/data
```

## Advanced Configuration

### Adding Subdomains
To add subdomains (like beta.cloudtolocalllm.online):
```bash
./update_ssl_fixed.sh
```

### Using Wildcard SSL
For wildcard SSL certificates:
1. Purchase a wildcard certificate (*.cloudtolocalllm.online)
2. Follow the installation instructions for your certificate provider
3. Update the Nginx configuration to use the new certificate 