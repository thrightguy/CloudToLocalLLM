\
<!-- filepath: /home/rightguy/Dev/CloudToLocalLLM/docs/VPS_DEPLOYMENT.md -->
# VPS Deployment Guide for CloudToLocalLLM

## IMPORTANT: Deployment Script
The ONLY script that should be used for deployment is:
```bash
scripts/setup/docker_startup_vps.sh
```

This script handles all necessary deployment steps including:
- Docker container management
- SSL certificate handling
- Service verification
- Proper user permissions

## Quick Setup

1. SSH into your VPS as the `cloudllm` user:
   ```bash
   ssh cloudllm@cloudtolocalllm.online
   ```

2. Navigate to the installation directory:
   ```bash
   cd /opt/cloudtolocalllm
   ```

3. Pull the latest changes:
   ```bash
   git pull
   ```
   **Note on Permissions:** If `git pull` fails due to permission errors (e.g., `fatal: cannot create directory at \'static_homepage/css\': Permission denied`), you may need to ensure the `cloudllm` user owns the `/opt/cloudtolocalllm` directory. This can be fixed by running `sudo chown -R cloudllm:cloudllm /opt/cloudtolocalllm` on the VPS (requires root access).

4. Run the deployment script:
   ```bash
   bash scripts/setup/docker_startup_vps.sh
   ```

## Static Homepage Content (`static_homepage`)

The main domain (e.g., `https://cloudtolocalllm.online`) serves static content from the `static_homepage` directory in the root of the repository. This directory should contain an `index.html` and any other necessary assets for your landing page.

- **Ensure this directory is present in your git repository and is pulled to the VPS.**
- If this directory is missing or empty on the VPS, Nginx will likely return a 403 Forbidden error for the main domain.
- The Flutter web application itself is served from the `app` subdomain (e.g., `https://app.cloudtolocalllm.online`).

## SSL Setup
The SSL certificates are managed automatically by the deployment script. The script utilizes Let's Encrypt for obtaining and renewing SSL certificates. It will configure Nginx to use these certificates for HTTPS.

If you need to manually inspect or manage SSL certificates (e.g., for troubleshooting), the relevant files are typically located in `/opt/cloudtolocalllm/certbot/conf/live/your-domain.com/` on the VPS. However, direct manual intervention should rarely be needed as the deployment script handles this.

The script `scripts/ssl/manage_ssl.sh` can be used for some manual SSL operations if absolutely necessary, but prefer relying on the main deployment script.

## Monitoring

To check the status of your deployment:
```bash
# Check running containers
# Ensure you are in the /opt/cloudtolocalllm directory or specify the full path to the compose file
docker compose -f /opt/cloudtolocalllm/config/docker/docker-compose.yml ps

# View logs
docker compose -f /opt/cloudtolocalllm/config/docker/docker-compose.yml logs -f
```

## Troubleshooting

If you encounter issues:

1.  **Check Container Status:**
    ```bash
    docker compose -f /opt/cloudtolocalllm/config/docker/docker-compose.yml ps
    ```
    Ensure all expected containers (e.g., `webapp`, `postfix-mail`, `certbot`) are running.

2.  **Check Container Logs:**
    ```bash
    # For all services
    docker compose -f /opt/cloudtolocalllm/config/docker/docker-compose.yml logs

    # For a specific service (e.g., webapp)
    docker compose -f /opt/cloudtolocalllm/config/docker/docker-compose.yml logs webapp
    ```
    Look for any error messages or repeated restarting of containers.

3.  **Verify SSL Certificates:**
    - Check the Nginx configuration within the `webapp` container to ensure it's pointing to the correct certificate paths.
    - On the VPS, inspect certificate files:
      ```bash
      sudo ls -la /opt/cloudtolocalllm/certbot/conf/live/cloudtolocalllm.online/
      ```
    - Ensure Nginx (running as user `101` inside the container) has read access to the certificate files mounted from the host. The deployment script should set appropriate permissions, but if issues arise, verify ownership and permissions in `/opt/cloudtolocalllm/certbot/` on the VPS.

4.  **403 Forbidden on Main Domain (`https://cloudtolocalllm.online`)**:
    - This usually indicates an issue with the `static_homepage` content.
    - Verify that the `/opt/cloudtolocalllm/static_homepage` directory exists on the VPS and contains an `index.html` file and other necessary assets (e.g., `css/`, `images/`).
    - If it's missing or incomplete, ensure it's committed to your git repository and run `git pull` on the VPS. You might need to restore it from git history if it was accidentally deleted.
    - Check Nginx logs for specific errors related to file access.

5.  **Web Application Not Loading on `app` Subdomain (`https://app.cloudtolocalllm.online`)**:
    - Check `webapp` container logs for errors during startup or request processing.
    - Verify Nginx configuration for the `app` subdomain is correct and proxying requests to the Flutter application.
    - Ensure the Flutter application within the `webapp` container is building and running correctly.

6.  **General Nginx Issues:**
    - You can test the Nginx configuration from within the running `webapp` container:
      ```bash
      docker exec -it <webapp_container_id_or_name> nginx -t
      ```
    - Check Nginx error logs (usually available through `docker logs webapp`).

7.  **Connectivity Issues:**
    - Ensure your VPS firewall (e.g., `ufw`) is allowing traffic on ports 80 and 443.
      ```bash
      sudo ufw status
      ```
    - Verify DNS records for your domain and subdomain are correctly pointing to your VPS IP address.

## Important Notes

- Always use the `cloudllm` user for deployment operations on the VPS after the initial setup.
- The deployment script `scripts/setup/docker_startup_vps.sh` is designed to handle most setup and update tasks, including necessary root operations via `sudo` where appropriate.
- Avoid direct manual modifications to Nginx configurations or Docker container settings on the VPS unless for temporary troubleshooting; changes should be made in the repository and deployed via the script.
- All deployment operations should ideally be performed through the official deployment script to maintain consistency.

<!-- Sections below this line are deprecated and will be removed. -->
