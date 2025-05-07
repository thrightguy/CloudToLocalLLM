#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN="cloudtolocalllm.online"
EMAIL="admin@cloudtolocalllm.online"

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