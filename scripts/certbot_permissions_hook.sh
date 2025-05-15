#!/bin/sh
# This script runs inside the certbot container after a successful renewal.
# It adjusts permissions on the certificate files in the shared volume
# /etc/letsencrypt, so that Nginx (running as root for master, then dropping to nginx user for workers)
# in the webapp container can access them.

DOMAIN="cloudtolocalllm.online"
LE_BASE_PATH="/etc/letsencrypt"
LIVE_DIR="${LE_BASE_PATH}/live"
ARCHIVE_DIR="${LE_BASE_PATH}/archive"
DOMAIN_LIVE_DIR="${LIVE_DIR}/${DOMAIN}"
DOMAIN_ARCHIVE_DIR="${ARCHIVE_DIR}/${DOMAIN}"

echo "Certbot deploy hook: Adjusting permissions for ${DOMAIN}"

# Ensure base directories are traversable by root (owner) and readable/traversable by others.
# Mode 0755: drwxr-xr-x. Owner (root in certbot container) has full control. Group/Others can read/execute (traverse).
echo "Setting permissions for live and archive directories..."
# Create directories if they don't exist (should be created by Certbot, but good for script robustness)
mkdir -p "${DOMAIN_LIVE_DIR}"
mkdir -p "${DOMAIN_ARCHIVE_DIR}"

chmod 0755 "${LE_BASE_PATH}" # Ensure /etc/letsencrypt itself is traversable
chmod 0755 "${LIVE_DIR}"
chmod 0755 "${ARCHIVE_DIR}"

if [ -d "${DOMAIN_LIVE_DIR}" ]; then
  chmod 0755 "${DOMAIN_LIVE_DIR}"
  # Ensure symlinks are not broken and are traversable (usually they are root:root rwxrwxrwx)
  # Actual file permissions are checked in archive
else
  echo "Warning: Live directory for domain not found after attempting creation: ${DOMAIN_LIVE_DIR}"
fi

if [ -d "${DOMAIN_ARCHIVE_DIR}" ]; then
  chmod 0755 "${DOMAIN_ARCHIVE_DIR}"

  # Private key: readable only by owner (root). Nginx master process reads this as root.
  echo "Setting permissions for private key(s) in ${DOMAIN_ARCHIVE_DIR}..."
  find "${DOMAIN_ARCHIVE_DIR}" -name 'privkey*.pem' -exec chmod 0600 {} \;
  find "${DOMAIN_ARCHIVE_DIR}" -name 'privkey*.pem' -exec chown root:root {} \; # Ensure root ownership

  # Public certificates and chain: readable by all.
  echo "Setting permissions for public certs in ${DOMAIN_ARCHIVE_DIR}..."
  find "${DOMAIN_ARCHIVE_DIR}" -name 'cert*.pem' -exec chmod 0644 {} \;
  find "${DOMAIN_ARCHIVE_DIR}" -name 'chain*.pem' -exec chmod 0644 {} \;
  find "${DOMAIN_ARCHIVE_DIR}" -name 'fullchain*.pem' -exec chmod 0644 {} \;
  find "${DOMAIN_ARCHIVE_DIR}" \\( -name 'cert*.pem' -o -name 'chain*.pem' -o -name 'fullchain*.pem' \\) -exec chown root:root {} \;
else
  echo "Warning: Archive directory for domain not found after attempting creation: ${DOMAIN_ARCHIVE_DIR}"
fi

echo "Certbot deploy hook: Permissions adjustment complete."
echo "IMPORTANT: Nginx in the webapp container must be reloaded externally to pick up certificate changes."
echo "Example: docker compose exec webapp nginx -s reload" 