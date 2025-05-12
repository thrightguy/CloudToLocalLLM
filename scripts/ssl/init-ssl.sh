#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN="cloudtolocalllm.online"
EMAIL="admin@cloudtolocalllm.online"

# --- Certbot Symlink Structure Cleanup ---
LIVE_DIR="/etc/letsencrypt/live/$DOMAIN"
ARCHIVE_DIR="/etc/letsencrypt/archive/$DOMAIN"
RENEWAL_CONF="/etc/letsencrypt/renewal/$DOMAIN.conf"

if [ -d "$LIVE_DIR" ] && [ ! -L "$LIVE_DIR/cert.pem" ]; then
  echo -e "${RED}Detected broken cert.pem (not a symlink) in $LIVE_DIR. Backing up and removing broken certbot data...${NC}"
  BACKUP_SUFFIX="backup_$(date +%Y%m%d_%H%M%S)"
  mv "$LIVE_DIR" "${LIVE_DIR}_$BACKUP_SUFFIX" || true
  if [ -d "$ARCHIVE_DIR" ]; then
    mv "$ARCHIVE_DIR" "${ARCHIVE_DIR}_$BACKUP_SUFFIX" || true
  fi
  if [ -f "$RENEWAL_CONF" ]; then
    mv "$RENEWAL_CONF" "${RENEWAL_CONF}_$BACKUP_SUFFIX" || true
  fi
  echo -e "${GREEN}Backed up and removed broken certbot data. Will proceed to obtain a fresh certificate.${NC}"
fi

echo -e "${YELLOW}Initializing SSL certificates for $DOMAIN...${NC}"

# Stop the web server temporarily
docker-compose -f docker-compose.web.yml down

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Installing certbot...${NC}"
    apt-get update
    apt-get install -y certbot
fi

# Request certificate
echo -e "${YELLOW}Requesting SSL certificate...${NC}"
certbot certonly --standalone \
    --preferred-challenges http \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN \
    -d www.$DOMAIN

# Copy certificates to the correct location
echo -e "${YELLOW}Copying certificates...${NC}"
mkdir -p certbot/conf
cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem certbot/conf/
cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem certbot/conf/

# Set up auto-renewal
echo -e "${YELLOW}Setting up auto-renewal...${NC}"
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Restart the web server
echo -e "${YELLOW}Restarting web server...${NC}"
docker-compose -f docker-compose.web.yml up -d

echo -e "${GREEN}SSL certificates initialized successfully!${NC}" 