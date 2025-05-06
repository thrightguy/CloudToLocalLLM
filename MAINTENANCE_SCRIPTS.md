# CloudToLocalLLM Maintenance Scripts

This document provides an overview of all the maintenance scripts available for the CloudToLocalLLM portal.

## Quick Reference

| Script | Purpose |
|--------|---------|
| `fix_and_deploy.sh` | Main deployment script - fixes nginx configuration and deploys the portal |
| `git_pull.sh` | Pulls the latest changes from GitHub |
| `fix_nginx.sh` | Fixes nginx configuration issues |
| `update_ssl_fixed.sh` | Updates SSL certificates to include subdomains |
| `renew-ssl.sh` | Manually renews SSL certificates |
| `deploy_commands.sh` | Original deployment script (deprecated) |

## Detailed Usage

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
Script to update SSL certificates to include additional subdomains:

```bash
./update_ssl_fixed.sh
```

This script:
1. Stops containers
2. Updates the SSL certificate to include the beta subdomain
3. Updates server.conf
4. Rebuilds and restarts containers

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

For a fresh installation, follow these steps:

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

## Troubleshooting

If you encounter issues with any script:

1. Check the container logs:
```bash
docker-compose -f docker-compose.web.yml logs webapp
```

2. Check the SSL certificate status:
```bash
docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" certbot/certbot certificates
```

3. For nginx configuration issues:
```bash
cat server.conf
cat nginx.conf
``` 