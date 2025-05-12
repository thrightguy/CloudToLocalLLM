#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Updating SSL certificate to include beta subdomain...${NC}"

# Check if docker compose is installed
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: docker compose is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if docker-compose.web.yml exists
if [[ ! -f "docker-compose.web.yml" ]]; then
    echo -e "${RED}Error: docker-compose.web.yml not found.${NC}"
    exit 1
fi

# Stop containers to free port 80
echo -e "${YELLOW}Stopping containers...${NC}"
docker compose -f docker-compose.web.yml down || {
    echo -e "${RED}Failed to stop containers${NC}"
    exit 1
}

echo -e "${YELLOW}Checking for broken Certbot symlink structure for cloudtolocalllm.online...${NC}"
LIVE_DIR="$(pwd)/certbot/conf/live/cloudtolocalllm.online"
ARCHIVE_DIR="$(pwd)/certbot/conf/archive/cloudtolocalllm.online"
RENEWAL_CONF="$(pwd)/certbot/conf/renewal/cloudtolocalllm.online.conf"

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

# Get new certificate with beta subdomain included
# Using --expand flag to automatically expand the certificate
echo -e "${YELLOW}Requesting SSL certificate...${NC}"
docker run --rm -p 80:80 -p 443:443 \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  certbot/certbot certonly --standalone \
  --agree-tos --no-eff-email \
  --email admin@cloudtolocalllm.online \
  --expand \
  -d cloudtolocalllm.online -d www.cloudtolocalllm.online -d beta.cloudtolocalllm.online || {
    echo -e "${RED}Failed to obtain SSL certificate${NC}"
    exit 1
}

# Check if server.conf exists
if [[ -f "server.conf" ]]; then
  # Make a backup of the current server.conf
  cp "server.conf" "server.conf.bak" || {
    echo -e "${RED}Failed to create backup of server.conf${NC}"
    exit 1
  }
  echo -e "${GREEN}Created backup of server.conf as server.conf.bak${NC}"
  
  # Check if beta subdomain is already in the configuration
  if grep -q "server_name beta.cloudtolocalllm.online" server.conf; then
    echo -e "${GREEN}Beta subdomain already configured in server.conf${NC}"
  else
    echo -e "${YELLOW}Updating server.conf to include beta subdomain...${NC}"
    
    # Check if we need to update the HTTP redirect block
    if grep -q "server_name cloudtolocalllm.online www.cloudtolocalllm.online;" server.conf; then
      sed -i 's/server_name cloudtolocalllm.online www.cloudtolocalllm.online;/server_name cloudtolocalllm.online www.cloudtolocalllm.online beta.cloudtolocalllm.online;/g' server.conf || {
        echo -e "${RED}Failed to update HTTP redirect block${NC}"
        exit 1
      }
      echo -e "${GREEN}Updated HTTP redirect block with beta subdomain${NC}"
    fi
    
    # Add the beta server block if it doesn't exist
    if ! grep -q "server_name beta.cloudtolocalllm.online;" server.conf; then
      cat >> "server.conf" << 'CONF' || {
        echo -e "${RED}Failed to update server.conf${NC}"
        exit 1
      }

# Beta subdomain with auth
server {
    listen 443 ssl http2;
    server_name beta.cloudtolocalllm.online;

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
        set $upstream_auth http://auth:8080;
        proxy_pass $upstream_auth/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Handle SPA routing
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Proxy auth service
    location /auth/ {
        set $upstream_auth http://auth:8080;
        proxy_pass $upstream_auth/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
CONF
      echo -e "${GREEN}Added beta subdomain server block to server.conf${NC}"
    fi
  fi
else
  # Create server.conf with all required configurations
  echo -e "${YELLOW}Creating new server.conf file...${NC}"
  cat > "server.conf" << 'CONF' || {
    echo -e "${RED}Failed to create server.conf${NC}"
    exit 1
  }
server {
    listen 80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online beta.cloudtolocalllm.online;
    return 301 https://$server_name$request_uri;
}

# Main domain and www subdomain
server {
    listen 443 ssl http2;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;

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

    # Proxy cloud service
    location /cloud/ {
        set $upstream_cloud http://cloud:3456;
        proxy_pass $upstream_cloud/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}

# Beta subdomain with auth
server {
    listen 443 ssl http2;
    server_name beta.cloudtolocalllm.online;

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
        set $upstream_auth http://auth:8080;
        proxy_pass $upstream_auth/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Handle SPA routing
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Proxy auth service
    location /auth/ {
        set $upstream_auth http://auth:8080;
        proxy_pass $upstream_auth/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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

# Check if docker-compose.web.fixed.yml exists
if [[ ! -f "docker-compose.web.fixed.yml" ]]; then
    echo -e "${RED}Error: docker-compose.web.fixed.yml not found.${NC}"
    exit 1
fi

# Ensure docker-compose.web.yml has the auth service
if ! grep -q "auth:" docker-compose.web.yml; then
  echo -e "${YELLOW}Updating docker-compose.web.yml to include auth service...${NC}"
  cp "docker-compose.web.fixed.yml" "docker-compose.web.yml" || {
    echo -e "${RED}Failed to update docker-compose.web.yml${NC}"
    exit 1
  }
  echo -e "${GREEN}Updated docker-compose.web.yml with auth service${NC}"
fi

# Rebuild and restart containers
echo -e "${YELLOW}Rebuilding and restarting containers...${NC}"
docker compose -f docker-compose.web.yml build webapp || {
    echo -e "${RED}Failed to build webapp container${NC}"
    exit 1
}

docker compose -f docker-compose.web.yml up -d || {
    echo -e "${RED}Failed to start containers${NC}"
    exit 1
}

echo -e "${GREEN}SSL certificate updated!${NC}"
echo -e "${GREEN}The portal should now be accessible at:${NC}"
echo -e "${GREEN}- https://cloudtolocalllm.online${NC}"
echo -e "${GREEN}- https://www.cloudtolocalllm.online${NC}"
echo -e "${GREEN}- https://beta.cloudtolocalllm.online (with authentication)${NC}"

# Check container status
echo -e "${YELLOW}Container status:${NC}"
docker ps 