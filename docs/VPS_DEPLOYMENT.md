# VPS Deployment Guide for CloudToLocalLLM

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
# Clone the repository
cd /var/www/html
git clone https://github.com/yourusername/CloudToLocalLLM.git .

# Create CPU-only docker-compose.yml
# (Remove GPU requirements and change port to 8080)
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