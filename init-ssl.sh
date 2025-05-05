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

# Start nginx without SSL
docker-compose -f docker-compose.web.yml up -d webapp

# Wait for nginx to start
echo -e "${YELLOW}Waiting for nginx to start...${NC}"
sleep 5

# Request SSL certificate
docker-compose -f docker-compose.web.yml run --rm certbot

# Restart nginx with SSL
docker-compose -f docker-compose.web.yml restart webapp

echo -e "${GREEN}SSL initialization complete. Checking certificate status...${NC}"

# Verify certificate
docker-compose -f docker-compose.web.yml run --rm certbot certificates

echo -e "${GREEN}Setup complete. The portal should now be accessible via HTTPS.${NC}"

# Set up automatic renewal
echo -e "${YELLOW}Setting up automatic certificate renewal...${NC}"
cat > renew-ssl.sh << 'EOF'
#!/bin/bash
docker-compose -f docker-compose.web.yml run --rm certbot renew
docker-compose -f docker-compose.web.yml exec webapp nginx -s reload
EOF

chmod +x renew-ssl.sh

# Add to crontab if not already present
(crontab -l 2>/dev/null || echo "") | grep -v "renew-ssl.sh" | { cat; echo "0 3 * * * $(pwd)/renew-ssl.sh >> /var/log/certbot-renew.log 2>&1"; } | crontab -

echo -e "${GREEN}Setup complete!${NC}"
echo -e "${YELLOW}Certificate renewal has been scheduled to run daily at 3 AM${NC}" 