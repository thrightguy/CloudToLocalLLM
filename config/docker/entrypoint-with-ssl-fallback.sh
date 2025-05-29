#!/bin/sh
set -e

CERT_DIR="/etc/letsencrypt/live/cloudtolocalllm.online"
FALLBACK_CERT="/etc/nginx/ssl/selfsigned.crt"
FALLBACK_KEY="/etc/nginx/ssl/selfsigned.key"

# Create fallback SSL directory if needed
mkdir -p /etc/nginx/ssl

# If real certs are missing, generate a self-signed cert
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
  echo "[entrypoint] Real certs not found, generating self-signed fallback cert..."
  if [ ! -f "$FALLBACK_CERT" ] || [ ! -f "$FALLBACK_KEY" ]; then
    openssl req -x509 -nodes -days 2 -newkey rsa:2048 \
      -keyout "$FALLBACK_KEY" \
      -out "$FALLBACK_CERT" \
      -subj "/CN=cloudtolocalllm.online"
    echo "[entrypoint] Self-signed cert generated."
  else
    echo "[entrypoint] Self-signed cert already exists."
  fi
else
  echo "[entrypoint] Real certs found, using them."
fi

# Start nginx
exec nginx -g 'daemon off;' 