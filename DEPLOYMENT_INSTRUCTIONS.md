# CloudToLocalLLM Deployment Instructions

This document provides step-by-step instructions for deploying the CloudToLocalLLM portal to your VPS.

## Server Requirements
- Linux VPS (tested on Ubuntu/Debian)
- Root access
- Ports 80 and 443 open
- Domain name pointing to the VPS IP (cloudtolocalllm.online)

## Deployment Process

### 1. SSH to Your Server
```bash
ssh cloudllm@162.254.34.115
# Then switch to root user
sudo su -
```

### 2. Deploy the Portal

Execute the following commands as root:

```bash
# Create deployment directory
mkdir -p /opt/cloudtolocalllm/portal
cd /opt/cloudtolocalllm/portal

# Clone GitHub repository
git clone https://github.com/thrightguy/CloudToLocalLLM.git .

# Create SSL directories
mkdir -p certbot/www
mkdir -p certbot/conf

# Make initialization script executable
chmod +x init-ssl.sh

# Start Docker services
docker-compose -f docker-compose.web.yml up -d

# Initialize SSL
./init-ssl.sh
```

Alternatively, you can run the included deployment script:

```bash
chmod +x deploy_commands.sh
./deploy_commands.sh
```

### 3. Verify Deployment

After deployment completes, verify the services are running:

```bash
docker-compose -f docker-compose.web.yml ps
```

Check that the portal is accessible by visiting:
- https://cloudtolocalllm.online

### 4. Troubleshooting

#### SSL Certificate Issues
If SSL certificate doesn't work properly:
```bash
docker-compose -f docker-compose.web.yml run --rm certbot certificates
```

#### Webapp Build Issues
If the webapp build fails due to Flutter SDK version issues:
1. The Dockerfile has been updated to use `--no-sound-null-safety` flag
2. Check the Docker build logs:
```bash
docker-compose -f docker-compose.web.yml logs webapp
```

### 5. Maintenance

#### Renew SSL Certificates
SSL certificates are set to auto-renew, but you can manually renew them:
```bash
./renew-ssl.sh
```

#### Update the Portal
To update the portal after changes to the repository:
```bash
cd /opt/cloudtolocalllm/portal
git pull
docker-compose -f docker-compose.web.yml down
docker-compose -f docker-compose.web.yml up -d --build
```

## Services Architecture

- **Webapp Service**: Flutter web frontend with Nginx
- **Auth Service**: Authentication service
- **Tunnel Service**: Node.js Express server for cloud synchronization
- **SSL**: Managed by Certbot with auto-renewal

## Important Files

- `docker-compose.web.yml`: Docker Compose configuration
- `init-ssl.sh`: SSL initialization script
- `nginx.conf`: Nginx configuration
- `Dockerfile`: Flutter web app build 