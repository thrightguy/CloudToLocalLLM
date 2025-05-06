#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Updating SSL certificate to include beta subdomain...${NC}"

# Stop containers to free port 80
docker-compose -f docker-compose.web.yml down

# Get new certificate with beta subdomain included
# Using --expand flag to automatically expand the certificate
docker run --rm -p 80:80 -p 443:443 \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --standalone \
  --agree-tos --no-eff-email \
  --email admin@cloudtolocalllm.online \
  --expand \
  -d cloudtolocalllm.online -d www.cloudtolocalllm.online -d beta.cloudtolocalllm.online

# Check if server.conf exists
if [ -f "server.conf" ]; then
  # Update server.conf to include beta subdomain
  sed -i 's/server_name cloudtolocalllm.online www.cloudtolocalllm.online;/server_name cloudtolocalllm.online www.cloudtolocalllm.online beta.cloudtolocalllm.online;/g' server.conf
  echo -e "${GREEN}Updated server.conf with beta subdomain${NC}"
else
  # Create server.conf if it doesn't exist
  cat > server.conf << 'CONF'
server {
    listen 80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online beta.cloudtolocalllm.online;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online beta.cloudtolocalllm.online;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    root /usr/share/nginx/html;
    index index.html;

    # Health check endpoint
    location = /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # Handle SPA routing
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
CONF
  echo -e "${GREEN}Created new server.conf with beta subdomain${NC}"
fi

# Restart containers
docker-compose -f docker-compose.web.yml build webapp
docker-compose -f docker-compose.web.yml up -d

echo -e "${GREEN}SSL certificate updated!${NC}"
echo -e "${GREEN}The portal should now be accessible at https://beta.cloudtolocalllm.online${NC}"

# Check container status
docker ps 