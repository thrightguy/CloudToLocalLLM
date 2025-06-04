# VPS Deployment Guide for CloudToLocalLLM

## IMPORTANT: Deployment Script
The primary script for deployment and management on the VPS is typically located in the `scripts/setup/` directory (e.g., `docker_startup_vps.sh` or a similar script). This script should be used for most operations.

This script handles all necessary deployment steps including:
- Docker container management (using `docker compose`)
- SSL certificate handling via Certbot
- Service verification
- Ensuring proper user permissions for critical files and directories.

## Quick Setup

1. SSH into your VPS as the `cloudllm` user:
```bash
ssh cloudllm@cloudtolocalllm.online
```

2. Navigate to the installation directory:
```bash
cd /opt/cloudtolocalllm
```

3. Pull the latest changes from the `master` (or `main`) branch:
```bash
git pull origin master
```

4. Run the main deployment/startup script (ensure you know the correct script name, e.g., `scripts/setup/docker_startup_vps.sh`):
```bash
bash scripts/setup/docker_startup_vps.sh # Or your primary deployment script
```

## SSL Setup

The SSL certificates are managed automatically by the deployment script. If you need to manually manage SSL certificates, use:
```bash
bash scripts/ssl/manage_ssl.sh
```

## Monitoring

To check the status of your deployment:
```bash
# Check running containers (use v2 syntax)
docker compose ps

# View logs for all services
docker compose logs -f

# View logs for a specific service (e.g., webapp)
docker compose logs -f webapp
```

## Troubleshooting

If you encounter issues:

1. Check container status:
```bash
docker compose ps
```

2. Check container logs (especially for the `webapp` or `nginx` container if web access is the issue):
```bash
docker compose logs webapp
```

3. Verify Nginx Configuration:
   - SSH into the VPS.
   - Navigate to `/opt/cloudtolocalllm`.
   - The Nginx configuration for the webapp is typically mounted from `config/nginx/nginx-webapp-internal.conf` to `/etc/nginx/conf.d/default.conf` inside the `webapp` container.
   - To test the configuration from the host (if Nginx is also installed there, or by checking the config file syntax):
     ```bash
     # If nginx is on host:
     # sudo nginx -t
     # Or, more relevantly, check the config file that gets mounted:
     # (No direct command, but ensure it's valid Nginx syntax)
     ```
   - Inside the container (if it's running):
     ```bash
     docker exec cloudtolocalllm-webapp nginx -t
     ```

4. Verify SSL certificates:
   - Certificates are stored in `/opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online/` on the host.
   - Ensure `fullchain.pem` and `privkey.pem` exist.
   - Permissions: These files should be readable by the Nginx process inside the container. The `certbot` container usually sets these to be owned by user `101:101` or makes them world-readable (e.g., `644`).
     ```bash
     ls -la /opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online/
     ls -la /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online/ # Actual files are here
     ```
   - If permissions are incorrect, re-running the main deployment script or a specific certbot permission hook script (if available) should fix it. As a last resort, `root` can fix permissions on the host:
     ```bash
     # Example: ssh root@cloudtolocalllm.online "chown -R 101:101 /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online && chmod -R 644 /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online/*.pem"
     # ssh root@cloudtolocalllm.online "chown -R 101:101 /opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online && chmod -R 755 /opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online"
     # Ensure symlinks in 'live' are also owned by 101:101 or accessible.
     ```

5. Check `static_homepage` Directory:
   - The main domain `cloudtolocalllm.online` serves content from the `static_homepage` directory.
   - If you see a 403 error for the main domain, ensure this directory exists at `/opt/cloudtolocalllm/static_homepage` and contains an `index.html` file.
   - If it was accidentally deleted, it can be restored from git history:
     ```bash
     # On your local machine or on the VPS in /opt/cloudtolocalllm
     git log -- static_homepage # Find commit that deleted it
     git checkout <commit_hash_before_deletion>^ -- static_homepage
     git add static_homepage
     git commit -m "Restore static_homepage"
     git push # (if local)
     # Then on VPS: git pull
     ```

## Important Notes

- Always use the `cloudllm` user for deployment operations
- The deployment script handles all necessary root operations internally
- Do not create or modify deployment scripts without explicit approval
- All deployment operations should be performed through the official deployment script

**This document is outdated.**

Please refer to the main [VPS Deployment Guide](DEPLOYMENT.MD) for the current and recommended deployment procedures, which utilize the `scripts/setup/docker_startup_vps.sh` script and the `admin_control_daemon`.

## Quick Setup

The easiest way to deploy CloudToLocalLLM to a VPS is to use the provided deployment script:

```bash
# From your local machine
cd cloud
./deploy_to_vps.sh user@your-vps-ip
```

This script will:
1. Create a CPU-friendly version of docker-compose.yml
2. Configure nginx as a reverse proxy
3. Set up firewall rules
4. Install all required dependencies
5. Start the application

## SSL Setup

To set up SSL for your VPS deployment, use our SSL setup script:

```powershell
# From your local machine
.\deploy_ssl_fix.ps1 "user@your-vps-ip"
```

This script will:
1. Upload an SSL fix script to your VPS
2. Install and configure Certbot to obtain SSL certificates
3. Set up Nginx with proper SSL configuration
4. Configure automatic certificate renewal
5. Create a simple test website to verify SSL is working

## Manual Deployment

If you prefer to deploy manually, follow these steps:

### 1. Prerequisites

- A VPS with at least 2GB RAM running Ubuntu/Debian
- Domain name pointing to your VPS IP (optional)
- SSH access to your VPS

### 2. Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y docker.io docker-compose nginx curl git

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 3. Application Setup

```bash
# Clone the repository (as cloudllm user)
cd /opt/cloudtolocalllm # Ensure this is the chosen directory
git clone https://github.com/imrightguy/CloudToLocalLLM.git . # Clone into current dir

# Create CPU-only docker-compose.yml
# (The main docker-compose.yml should already be suitable)
```

### 4. Nginx Configuration

Create a configuration at `/etc/nginx/sites-available/cloudtolocalllm.conf`:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name your-domain.com www.your-domain.com;
    
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
        autoindex off;
    }

    location /cloud/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Apply the configuration:
```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 5. Firewall Configuration

```bash
# For Ubuntu/Debian with UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # If using SSL

# For RHEL/CentOS with FirewallD
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp  # If using SSL
sudo firewall-cmd --reload
```

### 6. Start the Application

```bash
cd /var/www/html
sudo docker-compose up -d
```

## Manual SSL Configuration

To manually secure your site with HTTPS:

```bash
# Install Certbot
sudo apt install -y certbot

# Stop services using port 80
sudo systemctl stop nginx
sudo docker stop $(docker ps -q --filter publish=80) || true

# Get SSL certificate
sudo certbot certonly --standalone --non-interactive --agree-tos \
  --email admin@your-domain.com -d your-domain.com -d www.your-domain.com

# Set up Nginx with SSL
# See direct_ssl_fix.sh for a complete example
```

## Deploying/Updating the Admin UI Portal

The Admin UI (frontend portal) is deployed and updated using a specific script and Docker Compose configuration. This component is typically served via Nginx and handles the user interface for administration.

**Prerequisites:**
- Ensure SSL certificates for your domain (e.g., `cloudtolocalllm.online`) are correctly set up and available in `/opt/cloudtolocalllm/portal/certbot/conf/` on the VPS. This path is relative to where the `docker-compose.web.yml` is run, which is `/opt/cloudtolocalllm/portal/`. The `docker-compose.web.yml` mounts `./certbot/conf` from this location. This is usually handled by the SSL setup scripts (e.g., `init-ssl.sh` or `deploy_ssl_fix.ps1`).
- The necessary tools (`git`, `node`, `npm`, `docker`) must be installed on the VPS. The `deploy_admin_ui.sh` script attempts to install them if missing.

**Deployment/Update Steps:**
1.  SSH into your VPS.
2.  The `deploy_admin_ui.sh` script is typically located in the root of the cloned repository on the VPS, e.g., `/opt/cloudtolocalllm/portal/deploy_admin_ui.sh`.
3.  Run the deployment script from the repository root:
    ```bash
    # Example: if your project is cloned to /opt/cloudtolocalllm/portal
    cd /opt/cloudtolocalllm/portal
    sudo ./deploy_admin_ui.sh
    ```

This script will:
- Change to the `/opt/cloudtolocalllm/portal` directory.
- Pull the latest changes from the `master` branch of the Git repository.
- Install/update Node.js dependencies for the `admin-ui`.
- Build the `admin-ui` static assets (into `admin-ui/dist`).
- Rebuild and restart the `webapp` service using `docker-compose -f docker-compose.web.yml up -d --build`.

The `webapp` service (defined in `docker-compose.web.yml`) uses `Dockerfile.web` which packages the `admin-ui/dist` build artifacts with Nginx. The Nginx configuration (`nginx.conf` copied into the Docker image) handles serving the UI and SSL termination using the certificates mounted from the host.

## Troubleshooting

If you experience connectivity issues:

1. Check if nginx is running: `systemctl status nginx`
2. Check if Docker containers are running: `docker ps`
3. Verify port availability: `netstat -tulpn | grep ':80\|:8080'`
4. Check nginx error logs: `sudo tail -f /var/log/nginx/error.log`
5. Check Docker logs: `docker-compose logs`

SSL-specific issues:
1. Verify certificate paths: `ls -la /etc/letsencrypt/live/your-domain.com/`
2. Check certificate permissions
3. Validate nginx SSL configuration: `nginx -t`
4. Check SSL connectivity: `openssl s_client -connect your-domain.com:443`

## Updating the Application

To update your application:

```bash
cd /var/www/html
git pull
sudo docker-compose down
sudo docker-compose up -d
```