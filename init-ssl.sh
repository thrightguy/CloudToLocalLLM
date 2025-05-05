#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting SSL setup...${NC}"

# Create necessary directories
mkdir -p certbot/www
mkdir -p certbot/conf

# Stop any running containers
docker-compose -f docker-compose.web.yml down

# Use standalone mode for certificate generation
echo -e "${YELLOW}Requesting SSL certificate using standalone mode...${NC}"
docker run --rm -p 80:80 -p 443:443 \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --standalone \
  --agree-tos --no-eff-email \
  --email admin@cloudtolocalllm.online \
  -d cloudtolocalllm.online -d www.cloudtolocalllm.online

# Start services with SSL
echo -e "${YELLOW}Starting services with SSL...${NC}"
docker-compose -f docker-compose.web.yml up -d

echo -e "${GREEN}SSL initialization complete. Checking certificate status...${NC}"

# Verify certificate
docker run --rm \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  certbot/certbot certificates

echo -e "${GREEN}Setup complete. The portal should now be accessible via HTTPS.${NC}"

# Set up automatic renewal
echo -e "${YELLOW}Setting up automatic certificate renewal...${NC}"
cat > renew-ssl.sh << 'EOF'
#!/bin/bash
# Stop services to free port 80
docker-compose -f docker-compose.web.yml down

# Renew certificate in standalone mode
docker run --rm -p 80:80 -p 443:443 \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot renew

# Restart services
docker-compose -f docker-compose.web.yml up -d
EOF

chmod +x renew-ssl.sh

# Add to crontab if not already present
(crontab -l 2>/dev/null || echo "") | grep -v "renew-ssl.sh" | { cat; echo "0 3 * * * $(pwd)/renew-ssl.sh >> /var/log/certbot-renew.log 2>&1"; } | crontab -

echo -e "${GREEN}Setup complete!${NC}"
echo -e "${YELLOW}Certificate renewal has been scheduled to run daily at 3 AM${NC}" 