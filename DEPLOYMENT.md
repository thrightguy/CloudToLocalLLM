# CloudToLocalLLM VPS Deployment

This document details the deployment of CloudToLocalLLM on a VPS with containerized architecture.

## Overview

CloudToLocalLLM is deployed on a VPS (162.254.34.115) with the domain `cloudtolocalllm.online`. The deployment uses Docker containers with Nginx for SSL termination and reverse proxy.

## Architecture

The system uses a multi-container architecture with:

1. **Nginx Proxy** - Front-facing reverse proxy handling all incoming traffic with SSL
2. **API Service** - Backend service providing user authentication and management
3. **Database** - PostgreSQL database for user data
4. **User Manager** - Service for container provisioning and management

## Domain Structure

- `cloudtolocalllm.online` - Main portal
- `api.cloudtolocalllm.online` - API service
- `users.cloudtolocalllm.online` - User portal
- `{username}.users.cloudtolocalllm.online` - User-specific environments

## Deployment Scripts

Several PowerShell scripts are used to manage the deployment:

1. **containers_setup.ps1** - Initial container setup script
   ```powershell
   .\containers_setup.ps1 -VpsHost "root@162.254.34.115"
   ```

2. **fix_container_setup.ps1** - Script to fix SSL certification issues
   ```powershell
   .\fix_container_setup.ps1 -VpsHost "root@162.254.34.115"
   ```

3. **fix_ssl_and_add_auth.ps1** - Script to improve SSL security and add authentication
   ```powershell
   .\fix_ssl_and_add_auth.ps1 -VpsHost "root@162.254.34.115"
   ```

4. **fix_api_login.ps1** - Script to configure the API service with login functionality
   ```powershell
   .\fix_api_login.ps1 -VpsHost "root@162.254.34.115"
   ```

## Security Features

The deployment includes several security features:

1. **SSL Everywhere** - All traffic is encrypted with HTTPS
2. **Authentication** - JWT-based authentication for user access
3. **Container Isolation** - User environments are isolated in separate containers
4. **Security Headers** - HTTP security headers are configured in Nginx
5. **CORS Protection** - API has proper CORS configuration

## Default Credentials

For initial access, use the following credentials:

- **Username**: admin
- **Password**: admin123

> **Important**: Change these credentials after initial login!

## SSL Certificates

SSL certificates are obtained and managed through Certbot:

- Auto-renewal is configured via cron jobs
- Renewal hooks ensure Nginx is reloaded when certificates are renewed

## SSL Configuration Options

### Let's Encrypt (Current Implementation)
The current deployment uses Let's Encrypt for SSL certificates, which are:
- Free
- Auto-renewable
- Requires specifying each subdomain explicitly
- Requires stopping Nginx during renewal
- Needs certificate updates when adding new subdomains

### Wildcard SSL Certificate (Recommended for Production)
For production environments with multiple dynamic subdomains, a wildcard SSL certificate from a provider like Namecheap is recommended:

**Advantages:**
- Single certificate covers all subdomains (*.cloudtolocalllm.online)
- No need to update certificates when adding new subdomains
- Simplifies the dynamic user subdomain architecture
- No service interruption during certificate installation/renewal
- More reliable than automated renewal processes

**Implementation:**
1. Purchase a wildcard SSL certificate from Namecheap or similar provider
2. Install the certificate files on the VPS
3. Update Nginx configuration to use the wildcard certificate
4. Remove the Let's Encrypt renewal logic from your maintenance scripts

The wildcard certificate can be installed using:
```bash
sudo mkdir -p /opt/cloudtolocalllm/nginx/ssl
sudo cp /path/to/wildcard.crt /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
sudo cp /path/to/wildcard.key /opt/cloudtolocalllm/nginx/ssl/privkey.pem
sudo chmod 644 /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
sudo chmod 600 /opt/cloudtolocalllm/nginx/ssl/privkey.pem
```

Then restart the Nginx container:
```bash
cd /opt/cloudtolocalllm
docker-compose restart nginx-proxy
```

**Cost Consideration:**
While wildcard certificates typically cost $70-100/year compared to free Let's Encrypt certificates, the simplified management and improved reliability make them worth considering for production deployments.

## Container Management

User containers are managed through the User Manager service, which:

1. Creates containers on demand based on user requests
2. Provides access via username subdomains
3. Manages container lifecycle (start, stop, remove)

## Troubleshooting

If you encounter issues:

1. **SSL Problems**: Run the SSL fix script 
   ```powershell
   .\fix_ssl_and_add_auth.ps1 -VpsHost "root@162.254.34.115"
   ```

2. **API Issues**: Check the API logs inside the container
   ```bash
   docker exec -it api-service cat /app/server.log
   ```

3. **Database Issues**: Connect to the PostgreSQL container
   ```bash
   docker exec -it db-service psql -U postgres -d cloudtolocalllm
   ```

## Maintenance

Regular maintenance tasks include:

1. Verifying SSL certificate renewal
2. Checking container logs for errors
3. Monitoring disk space and resource usage
4. Backing up the database

## Future Enhancements

Planned improvements to the deployment:

1. Enhanced monitoring with Prometheus/Grafana
2. Automated backups to cloud storage
3. Load balancing for high availability
4. Kubernetes migration for better orchestration 