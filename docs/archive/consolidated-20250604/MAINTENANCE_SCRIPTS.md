# CloudToLocalLLM Maintenance Scripts

**[IMPORTANT NOTE] This document is likely outdated. The primary method for VPS deployment and initial setup is now the `scripts/setup/docker_startup_vps.sh` script, which utilizes the `admin_control_daemon` for service management. Many of the scripts listed below may be deprecated or their functionality incorporated into the new workflow. Please refer to `docs/DEPLOYMENT.MD` for the current deployment strategy.**

This document provides an overview of various maintenance scripts that have been part of the CloudToLocalLLM portal. Review each script's relevance before use.

## Quick Reference (Review for Currency)

| Script | Purpose (Verify if still current) |
|--------|---------|
| `scripts/setup/docker_startup_vps.sh` | **Current primary script for initial VPS setup and deployment.** |
| `fix_and_deploy.sh` | (Likely Deprecated) Main deployment script - fixes nginx configuration and deploys the portal |
| `git_pull.sh` | (Likely Deprecated by `docker_startup_vps.sh` which includes git pull) Pulls the latest changes from GitHub |
| `fix_nginx.sh` | (Likely Deprecated) Fixes nginx configuration issues |
| `update_ssl_fixed.sh` | (Likely Deprecated) Updates SSL certificates to include subdomains and configures auth service |
| `verify_beta_auth.sh` | (Likely Deprecated) Verifies the beta authentication setup |
| `deploy_with_monitoring.sh` | (Review) Comprehensive deployment script with Netdata monitoring |
| `setup_monitoring.sh` | (Review) Sets up Netdata monitoring only |
| `renew-ssl.sh` | (Review, Certbot service aims for auto-renewal) Manually renews SSL certificates |
| `deploy_commands.sh` | (Deprecated) Original deployment script |

## Detailed Usage (Review Individual Scripts for Relevance)

### fix_and_deploy.sh
Comprehensive script that handles everything from pulling the latest changes to fixing configuration issues and deploying:

```bash
./fix_and_deploy.sh
```

This script:
1. Pulls the latest changes from GitHub
2. Fixes nginx configuration
3. Restarts containers
4. Shows container status

### git_pull.sh
Simple script to pull the latest changes from GitHub:

```bash
./git_pull.sh
```

This script:
1. Stashes any local changes
2. Pulls the latest changes from GitHub
3. Makes scripts executable

### fix_nginx.sh
Script to fix nginx configuration issues:

```bash
./fix_nginx.sh
```

This script:
1. Creates a backup of the original nginx.conf
2. Creates a new nginx.conf without the problematic directives
3. Provides instructions to restart the containers

### update_ssl_fixed.sh
Script to update SSL certificates to include additional subdomains and configure the auth service:

```bash
./update_ssl_fixed.sh
```

This script:
1. Stops containers
2. Updates the SSL certificate to include the beta subdomain
3. Updates server.conf with appropriate server blocks
   - Main domain and www subdomain block
   - Beta subdomain block with auth service integration
4. Ensures docker-compose.web.yml includes the auth service
5. Rebuilds and restarts containers

### verify_beta_auth.sh
Script to verify that the beta authentication setup is properly configured:

```bash
./verify_beta_auth.sh
```

This script:
1. Checks if server.conf exists and has proper beta subdomain configuration
2. Verifies that docker-compose.web.yml includes the auth service
3. Confirms the auth service is running and healthy
4. Checks if the SSL certificate includes the beta subdomain
5. Provides guidance for manual testing and troubleshooting

### deploy_with_monitoring.sh
Comprehensive deployment script that includes Netdata monitoring:

```bash
./deploy_with_monitoring.sh
```

This script:
1. Pulls the latest changes from GitHub if it's a Git repository
2. Sets up authentication for monitoring access
3. Configures SSL certificates for all domains
4. Creates server.conf with Netdata monitoring integration
5. Optionally connects to Netdata Cloud for remote monitoring
6. Builds and starts all containers, including the monitoring service
7. Verifies that all services are running properly

### setup_monitoring.sh
Script to set up Netdata monitoring for an existing deployment:

```bash
./setup_monitoring.sh
```

This script:
1. Checks Docker and Docker Compose installation
2. Ensures the webnet network exists
3. Optionally configures Netdata Cloud integration
4. Starts the Netdata container
5. Provides instructions for integrating monitoring with your main site

### renew-ssl.sh
Script to manually renew SSL certificates:

```bash
./renew-ssl.sh
```

This script:
1. Stops containers to free port 80
2. Renews SSL certificates
3. Restarts containers

## Initial Deployment

For a fresh installation with monitoring, follow these steps:

```bash
# Create deployment directory
mkdir -p /opt/cloudtolocalllm/portal
cd /opt/cloudtolocalllm/portal

# Clone GitHub repository
git clone https://github.com/imrightguy/CloudToLocalLLM.git .

# Make scripts executable
chmod +x *.sh

# Run the comprehensive deployment script with monitoring
./deploy_with_monitoring.sh
```

For a deployment without monitoring, use:

```bash
./fix_and_deploy.sh
```

## Troubleshooting

If you encounter issues with any script:

1. Check the container logs:
```bash
docker-compose -f docker-compose.web.yml logs webapp
docker-compose -f docker-compose.web.yml logs auth
docker-compose -f docker-compose.monitor.yml logs netdata
```

2. Check the SSL certificate status:
```bash
docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" certbot/certbot certificates
```

3. For nginx configuration issues:
```bash
cat server.conf
```

4. For monitoring issues:
```bash
# Check if Netdata is running
docker ps | grep netdata

# View Netdata logs
docker logs cloudtolocalllm_monitor

# Try accessing Netdata directly (if available)
curl http://localhost:19999/api/v1/info
``` 