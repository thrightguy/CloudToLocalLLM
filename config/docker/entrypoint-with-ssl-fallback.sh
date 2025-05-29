#!/bin/sh
set -e

CERT_DIR="/etc/letsencrypt/live/cloudtolocalllm.online"
FALLBACK_CERT="/etc/nginx/ssl/selfsigned.crt"
FALLBACK_KEY="/etc/nginx/ssl/selfsigned.key"
NGINX_CONF="/etc/nginx/conf.d/default.conf"

# Create fallback SSL directory if needed
mkdir -p /etc/nginx/ssl
mkdir -p /var/www/certbot/.well-known/acme-challenge
chmod -R 755 /var/www/certbot

# If real certs are missing, generate a self-signed cert
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
  echo "[entrypoint] Real certs not found, generating self-signed fallback cert..."
  if [ ! -f "$FALLBACK_CERT" ] || [ ! -f "$FALLBACK_KEY" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$FALLBACK_KEY" \
      -out "$FALLBACK_CERT" \
      -subj "/CN=cloudtolocalllm.online"
    echo "[entrypoint] Self-signed cert generated."
  else
    echo "[entrypoint] Self-signed cert already exists."
  fi
  
  # Update Nginx configuration to use self-signed certificates
  echo "[entrypoint] Updating Nginx configuration to use self-signed certificates..."
  sed -i "s|ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;|ssl_certificate $FALLBACK_CERT;|g" $NGINX_CONF
  sed -i "s|ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;|ssl_certificate_key $FALLBACK_KEY;|g" $NGINX_CONF
  
  echo "[entrypoint] WARNING: Using self-signed certificates. Please set up Let's Encrypt certificates for production use."
else
  echo "[entrypoint] Real certs found, using them."
fi

# Create a test file in the ACME challenge directory
echo "acme-challenge-test" > /var/www/certbot/.well-known/acme-challenge/test.txt
chmod 644 /var/www/certbot/.well-known/acme-challenge/test.txt

echo "[entrypoint] ACME challenge directory is ready for Let's Encrypt verification."
echo "[entrypoint] Starting Nginx..."

# Start nginx
exec nginx -g 'daemon off;' 