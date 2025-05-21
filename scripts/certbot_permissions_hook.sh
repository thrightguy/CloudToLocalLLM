#!/bin/bash
set -e
# This script runs inside the certbot container after a successful renewal.
# It adjusts permissions on the certificate files in the shared volume
# /etc/letsencrypt, so that Nginx (running in the webapp container) can access them.
# Assumes Certbot itself is run with a user/group that allows Nginx group to read.

DOMAIN="cloudtolocalllm.online" # This will be the directory name for wildcard certs too.
LE_BASE_PATH="/etc/letsencrypt"
LIVE_DIR="${LE_BASE_PATH}/live"
ARCHIVE_DIR="${LE_BASE_PATH}/archive"
DOMAIN_LIVE_DIR="${LIVE_DIR}/${DOMAIN}"
DOMAIN_ARCHIVE_DIR="${ARCHIVE_DIR}/${DOMAIN}"

echo "Certbot deploy hook: Adjusting permissions for ${DOMAIN} (non-root mode)"

# Base directories: Owner rwx, Group rx, Others ---
# This assumes the parent directories up to /etc/letsencrypt are already traversable
# by the group Certbot/Nginx are in. The volume mount handles host permissions.
# Inside the container, Certbot (as appuser:NGINX_GID) will create these with suitable ownership.
echo "Setting base directory permissions..."
chmod 0750 "${LE_BASE_PATH}"
chmod 0750 "${LIVE_DIR}"
chmod 0750 "${ARCHIVE_DIR}"

if [ -d "${DOMAIN_LIVE_DIR}" ]; then
  chmod 0750 "${DOMAIN_LIVE_DIR}"
  # Symlinks created by certbot usually have rwxrwxrwx, pointing to files in archive.
  # The permissions of the target files are what matter most.
else
  echo "Warning: Live directory for domain not found: ${DOMAIN_LIVE_DIR}"
  # Attempt to create it with appropriate permissions if certbot didn't
  mkdir -p "${DOMAIN_LIVE_DIR}"
  chmod 0750 "${DOMAIN_LIVE_DIR}"
fi

if [ -d "${DOMAIN_ARCHIVE_DIR}" ]; then
  chmod 0750 "${DOMAIN_ARCHIVE_DIR}"

  # Private key(s): Owner rw, Group r, Others ---
  echo "Setting permissions for private key(s) in ${DOMAIN_ARCHIVE_DIR}..."
  find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'privkey*.pem' -exec chmod 0640 {} \\;

  # Public certificates and chain: Owner rw, Group r, Others r (or Group r, Others --- if stricter)
  # For simplicity and wider compatibility if other tools inside container need to read them:
  echo "Setting permissions for public certs in ${DOMAIN_ARCHIVE_DIR}..."
  find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'cert*.pem' -exec chmod 0644 {} \\;
  find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'chain*.pem' -exec chmod 0644 {} \\;
  find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'fullchain*.pem' -exec chmod 0644 {} \\;
else
  echo "Warning: Archive directory for domain not found: ${DOMAIN_ARCHIVE_DIR}"
  mkdir -p "${DOMAIN_ARCHIVE_DIR}"
  chmod 0750 "${DOMAIN_ARCHIVE_DIR}"
fi

echo "Certbot deploy hook: Permissions adjustment complete (non-root mode)."
echo "IMPORTANT: Nginx in the webapp container must be reloaded externally to pick up certificate changes."
echo "Example: docker compose exec webapp nginx -s reload"

# Set proper permissions for the certificates
chmod -R 755 /etc/letsencrypt/live
chmod -R 755 /etc/letsencrypt/archive

# Restart Nginx to pick up the new certificates
docker restart cloudtolocalllm-webapp 