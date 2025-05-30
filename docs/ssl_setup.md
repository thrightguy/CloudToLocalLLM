# SSL Certificate Setup

This document describes the SSL certificate setup process for CloudToLocalLLM, primarily managed via Certbot within a Docker container.

## Overview

The application uses Let's Encrypt certificates managed by the `certbot` Docker container for SSL/TLS encryption. These certificates are configured for automatic renewal. The Nginx service, running in the `webapp` container, uses these certificates to serve HTTPS traffic.

## Certificate Management

### Initial Setup & Renewal

1. The `certbot` container handles certificate acquisition (for domains like `cloudtolocalllm.online`, `app.cloudtolocalllm.online`, etc.) and automated renewals.
2. After certificate creation or renewal, the `certbot` container (or an associated script like `certbot_permissions_hook.sh`) is responsible for setting correct file permissions.
   - Nginx (typically running as user `101:101` in its container) needs to read these certificates.
   - Permissions are usually set so that the certificate files (`.pem`) are readable by this user (e.g., owned by `101:101` or having world-readable permissions like `644`). Symlinks and directories also need appropriate permissions.
3. Certificates are stored on the host in volumes mounted into the containers:
   - Live certificates (symlinks): `/opt/cloudtolocalllm/certbot/live/`
   - Archived certificates (actual files): `/opt/cloudtolocalllm/certbot/archive/`
   - Inside containers, these often map to `/etc/letsencrypt/live/` and `/etc/letsencrypt/archive/`.

### Important Notes

- The nginx container runs as user 101:101 (nginx user)
- Certificates must be owned by the nginx user for proper access
- Ownership is automatically changed after certificate creation and renewal
- The certbot container handles all certificate operations and permission management

### Backup

A backup script is provided to backup certificates before any changes:

```bash
./backup_ssl.sh
```

This will create a timestamped backup in `./certbot/backup/`.

## Troubleshooting

If you encounter permission issues:

1. Check certificate ownership:
   ```bash
   ls -la ./certbot/live/
   ls -la ./certbot/archive/
   ```

2. Certificates should be owned by user 101:101 (nginx user)

3. If permissions are incorrect, you can fix them by:
   ```bash
   chown -R 101:101 ./certbot/live ./certbot/archive
   ```

4. After fixing permissions, reload nginx:
   ```bash
   docker exec cloudtolocalllm-webapp nginx -s reload
   ```

## Common Issues and Solutions

### 1. Nginx Not Listening on Port 443 or SSL Errors

If Nginx isn't serving HTTPS correctly, or you see SSL-related errors in `docker compose logs webapp`:

1. Verify the Nginx configuration:
   - The main SSL configuration is in `config/nginx/nginx-webapp-internal.conf` (mounted to `/etc/nginx/conf.d/default.conf` in the `webapp` container).
   - Ensure server blocks for HTTPS listen on `443 ssl http2;` (or `443 ssl;`).
   - Check that `ssl_certificate` and `ssl_certificate_key` point to the correct paths:
     ```nginx
     ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
     ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;
     ```
2. Test Nginx configuration syntax from inside the container:
   ```bash
   docker exec cloudtolocalllm-webapp nginx -t
   ```
3. Check Nginx error logs within the container or via `docker compose logs webapp`.

### 2. Certificate Permission Issues

If nginx can't read the certificates:

1. Check certificate ownership:
   ```bash
   # From the VPS host
   ls -la /opt/cloudtolocalllm/certbot/live/cloudtolocalllm.online/
   ls -la /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online/
   ```
   The owner should effectively be the Nginx user (e.g., 101).

2. Fix ownership/permissions:
   - **Preferred**: Let Certbot handle it. Restarting the `certbot` container or triggering its permission hook script (if one exists, like `certbot_permissions_hook.sh` referenced in `docker-compose.yml`) might resolve this.
   - **Manual (Host, as root)**:
     ```bash
     sudo chown -R 101:101 /opt/cloudtolocalllm/certbot/live /opt/cloudtolocalllm/certbot/archive
     sudo chmod -R o-rwx /opt/cloudtolocalllm/certbot/archive # Secure private keys
     sudo chmod -R ug+rX,o+rX /opt/cloudtolocalllm/certbot/live # Ensure nginx can read/traverse
     sudo chmod 644 /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online/*.pem
     sudo chmod 600 /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online/privkey*.pem 
     # Ensure the group 101 can read privkey if nginx runs as nginx:nginx (101:101)
     # sudo chgrp 101 /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online/privkey*.pem
     # sudo chmod 640 /opt/cloudtolocalllm/certbot/archive/cloudtolocalllm.online/privkey*.pem

     # After changes, restart webapp
     docker compose restart webapp
     ```
   - **Manual (Certbot container exec)**:
     ```bash
     docker exec cloudtolocalllm-certbot chown -R 101:101 /etc/letsencrypt/live /etc/letsencrypt/archive
     # Add chmod commands as above, targeting /etc/letsencrypt paths
     ```
     Then restart `webapp`.

### 3. Volume Mount Issues

If certificates aren't visible in the nginx container:

1. Check docker-compose.yml volume mounts:
   ```yaml
   volumes:
     - ./certbot/www:/var/www/certbot
     - ./certbot/live:/etc/letsencrypt/live
     - ./certbot/archive:/etc/letsencrypt/archive
   ```

2. Ensure these mounts are not commented out

### 4. `static_homepage` Not Found (403/404 on main domain)

If you get a 403 or 404 error for `https://cloudtolocalllm.online` after SSL is working:

1. Ensure the `static_homepage` directory exists at `/opt/cloudtolocalllm/static_homepage`.
2. Ensure it contains an `index.html` file.
3. The Nginx configuration (`config/nginx/nginx-webapp-internal.conf`) should have a server block for `cloudtolocalllm.online` that sets `root /usr/share/nginx/landing;` (or similar, matching the volume mount for `static_homepage`).
   The `docker-compose.yml` mounts `./static_homepage:/usr/share/nginx/landing`.
4. If the directory was deleted, restore it from git history (see `VPS_DEPLOYMENT.md` troubleshooting).

## Flutter Web Deployment (Best Practice)

- The Flutter web build output (`build/web`) is now mounted directly into the Nginx container using a volume in `docker-compose.yml`:
  ```yaml
  volumes:
    - ./build/web:/usr/share/nginx/html
  ```
- To deploy a new version of the app:
  1. Run `flutter build web` locally or on the VPS.
  2. The changes are instantly reflected in the running container—no need to copy files manually.
  3. If you update the container image or config, just run `docker compose up -d webapp` to restart the container.
- The deploy script no longer copies the build output; it just builds and restarts as needed.