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
# Login directly as root
ssh root@162.254.34.115
```

### 2. Initial Deployment

The simplest way to deploy is using our comprehensive deployment script:

```bash
# Create deployment directory
mkdir -p /opt/cloudtolocalllm/portal
cd /opt/cloudtolocalllm/portal

# Clone GitHub repository
git clone https://github.com/thrightguy/CloudToLocalLLM.git .

# Make scripts executable
chmod +x *.sh

# Run the combined fix and deploy script
./fix_and_deploy.sh
```

This script will:
1. Pull the latest changes from GitHub
2. Fix any nginx configuration issues
3. Restart the containers with the correct configuration
4. Set up SSL certificates

### 3. Adding Additional Subdomains

To add support for additional subdomains (e.g., beta.cloudtolocalllm.online):

```bash
# Run the SSL update script
./update_ssl_fixed.sh
```

This will:
1. Update the SSL certificate to include the beta subdomain
2. Update the nginx configuration to support the new subdomain
3. Restart the containers with the new configuration

### 4. Verify Deployment

After deployment completes, verify the services are running:

```bash
docker-compose -f docker-compose.web.yml ps
```

Check that the portal is accessible by visiting:
- https://cloudtolocalllm.online
- https://www.cloudtolocalllm.online
- https://beta.cloudtolocalllm.online

### 5. Troubleshooting

#### SSL Certificate Issues
If SSL certificate doesn't work properly:
```bash
docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" certbot/certbot certificates
```

#### Nginx Configuration Issues
If the server won't start due to nginx configuration issues:
```bash
# Run the nginx fix script
./fix_nginx.sh
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

#### Webapp Build Issues
If the webapp build fails due to Flutter SDK version issues:
1. The Dockerfile has been updated to use `--no-sound-null-safety` flag
2. Check the Docker build logs:
```bash
docker-compose -f docker-compose.web.yml logs webapp
```

### 6. Maintenance

#### Regular Updates
To update the portal with the latest changes:
```bash
# Use the git pull script
./git_pull.sh

# Then reapply configuration and restart
./fix_and_deploy.sh
```

#### Renew SSL Certificates
SSL certificates are set to auto-renew, but you can manually renew them:
```bash
./renew-ssl.sh
```

## Services Architecture

- **Webapp Service**: Flutter web frontend with Nginx
- **Auth Service**: Authentication service
- **Tunnel Service**: Node.js Express server for cloud synchronization
- **SSL**: Managed by Certbot with auto-renewal

## Important Files

- `docker-compose.web.yml`: Docker Compose configuration
- `server.conf`: Nginx server blocks configuration
- `nginx.conf`: Main Nginx configuration
- `Dockerfile`: Flutter web app build
- `fix_and_deploy.sh`: Combined fix and deployment script
- `update_ssl_fixed.sh`: Script to add subdomains to SSL certificate
- `git_pull.sh`: Script to pull latest changes from GitHub
- `fix_nginx.sh`: Script to fix nginx configuration issues 