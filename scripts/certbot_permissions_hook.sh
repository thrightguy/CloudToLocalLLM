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

echo "Certbot deploy hook: Adjusting permissions for ${DOMAIN}"

# Create directories if they don't exist
mkdir -p "${LIVE_DIR}" "${ARCHIVE_DIR}" "${DOMAIN_LIVE_DIR}" "${DOMAIN_ARCHIVE_DIR}"

# Set base directory permissions
chmod 755 "${LE_BASE_PATH}"
chmod 755 "${LIVE_DIR}"
chmod 755 "${ARCHIVE_DIR}"
chmod 755 "${DOMAIN_LIVE_DIR}"
chmod 755 "${DOMAIN_ARCHIVE_DIR}"

# Set permissions for certificate files
if [ -d "${DOMAIN_ARCHIVE_DIR}" ]; then
    # Private key: Owner rw, Group r, Others ---
    find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'privkey*.pem' -exec chmod 640 {} \;
    
    # Public certificates and chain: Owner rw, Group r, Others r
    find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'cert*.pem' -exec chmod 644 {} \;
    find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'chain*.pem' -exec chmod 644 {} \;
    find "${DOMAIN_ARCHIVE_DIR}" -type f -name 'fullchain*.pem' -exec chmod 644 {} \;
fi

# Ensure symlinks in live directory are readable
if [ -d "${DOMAIN_LIVE_DIR}" ]; then
    chmod 755 "${DOMAIN_LIVE_DIR}"
    find "${DOMAIN_LIVE_DIR}" -type l -exec chmod 755 {} \;
fi

echo "Certbot deploy hook: Permissions adjustment complete"

# Restart Nginx to pick up the new certificates
docker restart cloudtolocalllm-webapp 