#!/bin/bash
# Certbot deploy hook script for CloudToLocalLLM
# This script is executed after successful certificate renewal

set -e

echo "[certbot-hook] Certificate deployment hook triggered"
echo "[certbot-hook] RENEWED_LINEAGE: $RENEWED_LINEAGE"
echo "[certbot-hook] RENEWED_DOMAINS: $RENEWED_DOMAINS"

# Set proper permissions for nginx user (101:101)
if [ -d "/etc/letsencrypt/live" ]; then
    echo "[certbot-hook] Setting permissions for certificate files..."
    chown -R 101:101 /etc/letsencrypt/live /etc/letsencrypt/archive
    chmod -R 755 /etc/letsencrypt/live /etc/letsencrypt/archive
    echo "[certbot-hook] Permissions updated successfully"
fi

# Restart nginx container to reload certificates
if command -v docker >/dev/null 2>&1; then
    echo "[certbot-hook] Restarting nginx container to reload certificates..."
    docker restart cloudtolocalllm-webapp || echo "[certbot-hook] Failed to restart nginx container"
else
    echo "[certbot-hook] Docker not available, skipping container restart"
fi

echo "[certbot-hook] Deploy hook completed"
