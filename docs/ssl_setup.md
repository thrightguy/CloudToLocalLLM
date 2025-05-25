# SSL Certificate Setup

This document describes the SSL certificate setup process for CloudToLocalLLM.

## Overview

The application uses Let's Encrypt certificates managed by Certbot for SSL/TLS encryption. The certificates are automatically renewed every 12 hours if they're close to expiration.

## Certificate Management

### Initial Setup

1. The certificates are managed by the `certbot` container which runs as root
2. After certificate creation or renewal, ownership is changed to the nginx user (101:101) to ensure proper access
3. The certificates are stored in the following locations:
   - Live certificates: `./certbot/live/`
   - Archived certificates: `./certbot/archive/`

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

### 1. Nginx Not Listening on Port 443

If nginx is not listening on port 443, check the following:

1. Verify the SSL server block is not commented out in `/etc/nginx/conf.d/default.conf`
2. Check nginx error logs:
   ```bash
   docker exec cloudtolocalllm-webapp cat /var/log/nginx/error.log
   ```
3. Common syntax errors to look for:
   - Uncommented comment lines (should start with `#`)
   - Missing closing braces
   - Incorrect indentation

### 2. Certificate Permission Issues

If nginx can't read the certificates:

1. Check certificate ownership:
   ```bash
   docker exec cloudtolocalllm-webapp ls -la /etc/letsencrypt/live/cloudtolocalllm.online/
   ```

2. Fix ownership from within the certbot container:
   ```bash
   docker exec cloudtolocalllm-certbot chown -R 101:101 /etc/letsencrypt/live /etc/letsencrypt/archive
   ```

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

### 4. 404 Not Found

If you get a 404 error after SSL is working:

1. Check that the root directory is correctly set in the nginx config
2. Verify that the files exist in the mounted volume
3. Check nginx access logs:
   ```bash
   docker exec cloudtolocalllm-webapp cat /var/log/nginx/access.log
   ```

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