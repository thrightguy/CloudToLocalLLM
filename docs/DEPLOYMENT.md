# CloudToLocalLLM VPS Deployment Guide

This guide provides step-by-step instructions for deploying the CloudToLocalLLM stack to your Virtual Private Server (VPS) using Docker and the provided setup scripts.

## Core Deployment Strategy

The deployment relies on Docker and Docker Compose, orchestrated by an `admin_control_daemon` (also running in Docker). A primary setup script, `scripts/setup/docker_startup_vps.sh`, automates the initial server preparation and launch of the `admin_control_daemon`. Once the daemon is running, it handles the deployment and management of the main application services.

## VPS Deployment Directory

It is recommended to clone the CloudToLocalLLM repository to `/opt/cloudtolocalllm/` on your VPS.

```bash
sudo mkdir -p /opt/cloudtolocalllm
sudo chown $USER:$USER /opt/cloudtolocalllm # Or your non-root user
cd /opt/cloudtolocalllm
git clone https://github.com/thrightguy/CloudToLocalLLM.git .
```

The directory structure on the VPS will then mirror the Git repository.

## Prerequisites

- A VPS running a recent version of Ubuntu or Debian.
- Root or sudo access to the VPS.
- A domain name (e.g., `cloudtolocalllm.online`) pointed to your VPS's IP address.
- Ports 80 (HTTP) and 443 (HTTPS) open in your VPS firewall.
- Git installed (`sudo apt update && sudo apt install -y git`).

## Deployment Steps

The primary script for setting up and deploying to a VPS is `scripts/setup/docker_startup_vps.sh`.

- **You must run this script as root or with sudo privileges.**
- All orchestration and SSL scripts now require root and will fail if not run as root.

```bash
cd /opt/cloudtolocalllm
sudo bash scripts/setup/docker_startup_vps.sh
```

### What the `docker_startup_vps.sh` Script Does:

1.  **Environment Cleanup**: Stops and removes relevant existing Docker containers and networks to ensure a clean start.
2.  **Docker Check**: Ensures Docker is installed and the service is running.
3.  **Admin Daemon Startup**:
    *   Builds the `webapp` Docker image defined in `config/docker/Dockerfile.web` using `config/docker/docker-compose.yml` with `--no-cache` to ensure the latest configuration is used.
    *   Starts the `admin_control_daemon` using `config/docker/docker-compose.admin.yml`. The daemon is built from `config/docker/Dockerfile.admin_daemon`.
    *   Waits for the `admin_control_daemon` to become healthy by checking its `/admin/health` endpoint (defaulting to `http://localhost:9001`).
4.  **Full Stack Deployment via Admin Daemon**:
    *   Once the admin daemon is ready, the script makes a POST request to the daemon's `/admin/deploy/all` endpoint.
    *   The `admin_control_daemon` then uses `config/docker/docker-compose.yml` to bring up all main application services (e.g., `webapp`, `fusionauth-app`, `fusionauth-db`, etc.).
5.  **Network Check**: Verifies that containers are attached to the `cloudllm-network`.

Refer to the script's output and its log file (`/opt/cloudtolocalllm/startup_docker.log`) for detailed status and troubleshooting.

## Service Configuration Files

-   **Admin Daemon**:
    -   Compose file: `config/docker/docker-compose.admin.yml`
    -   Dockerfile: `config/docker/Dockerfile.admin_daemon`
    -   Listens on port 9001 by default.
-   **Main Application Services**:
    -   Compose file: `config/docker/docker-compose.yml`
    -   Services include:
        -   `webapp`: The Flutter web application served by Nginx. Built from `config/docker/Dockerfile.web`.
        -   `cloudtolocalllm-fusionauth-app`: FusionAuth identity server.
        -   `cloudtolocalllm-fusionauth-db`: PostgreSQL database for FusionAuth.
        -   (Other services as defined in the compose file)

## SSL Configuration

### Default: Self-Signed Certificates for `webapp`

-   The `webapp` service (Nginx) is configured by default to use **self-signed SSL certificates**.
-   These certificates are generated *within the `webapp` Docker image* during its build process (see `config/docker/Dockerfile.web`).
-   The Nginx configuration (`config/nginx/nginx.conf`, copied into the image and also mounted from `config/docker/nginx.conf`) is set up to use these self-signed certificates located at `/etc/nginx/ssl/selfsigned.crt` and `/etc/nginx/ssl/selfsigned.key`.
-   This approach simplifies initial deployment and avoids immediate dependencies on external certificate authorities or DNS propagation.
-   **Note**: Browsers will show a warning for self-signed certificates. This is expected for development or internal use. For public-facing sites, use Let's Encrypt or a commercial SSL certificate.

### Option: Let's Encrypt

-   To use Let's Encrypt:
    1.  **Modify `config/docker/docker-compose.yml`**:
        *   Uncomment the Certbot service (`certbot-service`).
        *   Uncomment the Certbot-related volume mounts for the `webapp` service (e.g., `certbot_conf:/etc/letsencrypt/` and `certbot_www:/var/www/certbot/`).
        *   You might need to comment out or adjust the self-signed certificate generation in `config/docker/Dockerfile.web` if it conflicts.
    2.  **Update Nginx Configuration**:
        *   Modify `config/nginx/nginx.conf` (and ensure `config/docker/nginx.conf` is consistent if you keep the mount) to point to the Let's Encrypt certificate paths (e.g., `/etc/letsencrypt/live/yourdomain.com/fullchain.pem`).
    3.  **Initial Certificate Issuance**: You will need to run the Certbot service initially to obtain the certificates. This typically involves a command like:
        ```bash
        docker compose -f config/docker/docker-compose.yml run --rm certbot-service certonly --webroot --webroot-path=/var/www/certbot -d yourdomain.com --email your@email.com --agree-tos --no-eff-email
        ```
        Ensure the `webapp` (Nginx) container is running and accessible for the HTTP-01 challenge.
    4.  **Automatic Renewal**: The `certbot-service` in the Compose file is typically configured to attempt renewal periodically.

### Option: Commercial Wildcard SSL

1.  Purchase a wildcard certificate (e.g., `*.yourdomain.com`).
2.  Upload the certificate files (private key, full chain) to a secure location on your VPS, for example, in a new directory like `/opt/cloudtolocalllm/ssl/commercial/`.
3.  Modify `config/docker/docker-compose.yml`:
    *   Add volume mounts to the `webapp` service to make these certificate files available inside the container (e.g., mounting `/opt/cloudtolocalllm/ssl/commercial/` to `/etc/nginx/commercial_ssl/`).
4.  Modify `config/nginx/nginx.conf` (and `config/docker/nginx.conf`) to use these commercial certificate paths.
5.  Rebuild and redeploy the `webapp` service: `docker compose -f config/docker/docker-compose.yml up -d --build webapp` (or trigger via admin daemon).

## FusionAuth Integration

-   FusionAuth and its PostgreSQL database are included in `config/docker/docker-compose.yml`.
-   Access the FusionAuth admin UI at `https://yourdomain.com/auth/`.
-   The initial setup password is set via the `FUSIONAUTH_APP_SETUP_PASSWORD` environment variable in the Compose file.
-   **Security**: Change default passwords and manage secrets appropriately for production. The provided passwords in the compose file are for initial setup and development.

## Troubleshooting and Maintenance

-   **View Logs**:
    -   Admin Daemon: `docker logs ctl_admin-admin-daemon-1` (or the actual container name/ID)
    -   Application Services: Use `docker compose -f config/docker/docker-compose.yml logs <service_name>` (e.g., `webapp`, `cloudtolocalllm-fusionauth-app`).
-   **Restarting Services**:
    -   To restart all application services (after admin daemon is up):
        ```bash
        curl -X POST http://localhost:9001/admin/deploy/all
        ```
    -   To restart specific services: `docker compose -f config/docker/docker-compose.yml restart <service_name>`
-   **Updating the Application**:
    1.  Pull the latest changes from Git:
        ```bash
        cd /opt/cloudtolocalllm
        git pull
        ```
    2.  Re-run the main setup script if there are changes to the admin daemon or its Docker setup. This script will also rebuild the webapp image with no cache.
        ```bash
        sudo bash scripts/setup/docker_startup_vps.sh
        ```
        This will trigger the `admin_control_daemon` to redeploy other services as needed based on the updated compose files and Dockerfiles.
-   **Data Persistence**:
    -   PostgreSQL data for FusionAuth is stored in a Docker named volume (`fusionauth_postgres_data`).
    -   FusionAuth configuration is stored in a Docker named volume (`fusionauth_config`).
    -   To backup, consider Docker volume backup strategies or standard PostgreSQL backup procedures for the database.

## Old Scripts (For Reference/Review - Likely Deprecated)

The repository may contain older scripts in `scripts/` or mentioned in previous documentation versions (e.g., `deploy_commands.sh`, `fix_nginx.sh`, `renew-ssl.sh`). These are likely superseded by the `docker_startup_vps.sh` script and the `admin_control_daemon`. Review them before use, as they may not align with the current Dockerized architecture.

--- 