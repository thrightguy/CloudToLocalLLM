# CloudToLocalLLM VPS Deployment Guide

This guide provides step-by-step instructions for deploying the CloudToLocalLLM portal to your VPS.

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