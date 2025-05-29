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

# Check if real Let's Encrypt certificates exist
if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
  echo "[entrypoint] Real Let's Encrypt certificates found, using them."
  # Create a temporary copy of the config and modify it
  cp "$NGINX_CONF" "$NGINX_CONF.tmp"
  sed "s|ssl_certificate $FALLBACK_CERT;|ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;|g" "$NGINX_CONF.tmp" > "$NGINX_CONF.new"
  sed "s|ssl_certificate_key $FALLBACK_KEY;|ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;|g" "$NGINX_CONF.new" > "$NGINX_CONF.final"
  mv "$NGINX_CONF.final" "$NGINX_CONF"
  rm -f "$NGINX_CONF.tmp" "$NGINX_CONF.new"
else
  echo "[entrypoint] Real certs not found, generating self-signed fallback certificates..."
  # Generate self-signed certificates only if real ones don't exist
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$FALLBACK_KEY" \
    -out "$FALLBACK_CERT" \
    -subj "/CN=cloudtolocalllm.online" \
    2>/dev/null || echo "[entrypoint] Self-signed cert generation failed, continuing..."
  
  echo "[entrypoint] Self-signed certificates created as fallback."
  # Create a temporary copy of the config and modify it
  cp "$NGINX_CONF" "$NGINX_CONF.tmp"
  sed "s|ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;|ssl_certificate $FALLBACK_CERT;|g" "$NGINX_CONF.tmp" > "$NGINX_CONF.new"
  sed "s|ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;|ssl_certificate_key $FALLBACK_KEY;|g" "$NGINX_CONF.new" > "$NGINX_CONF.final"
  mv "$NGINX_CONF.final" "$NGINX_CONF"
  rm -f "$NGINX_CONF.tmp" "$NGINX_CONF.new"
  echo "[entrypoint] WARNING: Using self-signed certificates. Please set up Let's Encrypt certificates for production use."
fi

# Create a test file in the ACME challenge directory
echo "acme-challenge-test" > /var/www/certbot/.well-known/acme-challenge/test.txt
chmod 644 /var/www/certbot/.well-known/acme-challenge/test.txt

echo "[entrypoint] ACME challenge directory is ready for Let's Encrypt verification."
echo "[entrypoint] Starting Nginx..."

# Start nginx
exec nginx -g 'daemon off;' 