#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}====== CloudToLocalLLM Portal Fix and Deploy ======${NC}"

# Pull latest changes from GitHub
echo -e "${YELLOW}Step 1: Pulling latest changes from GitHub...${NC}"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not a git repository. Please run this script from the project root.${NC}"
    exit 1
fi

# Save any local changes
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${YELLOW}Local changes detected. Stashing them...${NC}"
    git stash || {
        echo -e "${RED}Failed to stash local changes${NC}"
        exit 1
    }
fi

# Pull the latest changes
echo -e "${YELLOW}Pulling latest changes...${NC}"
(git pull origin master || git pull origin main) || {
    echo -e "${RED}Failed to pull latest changes${NC}"
    exit 1
}

# Make scripts executable
echo -e "${YELLOW}Making scripts executable...${NC}"
find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || echo -e "${YELLOW}No .sh files to make executable${NC}"

echo -e "${GREEN}Successfully pulled latest changes!${NC}"

# Fix nginx configuration
echo -e "${YELLOW}Step 2: Fixing Nginx configuration...${NC}"

# Create backup of the original file if it exists
if [ -f "nginx.conf" ]; then
    cp nginx.conf nginx.conf.backup || {
        echo -e "${RED}Failed to create nginx.conf backup${NC}"
        exit 1
    }
    echo -e "${YELLOW}Backup created: nginx.conf.backup${NC}"
fi

# Create a new nginx.conf without the user directive
cat > nginx.conf << 'EOF' || {
    echo -e "${RED}Failed to create nginx.conf${NC}"
    exit 1
}
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # DNS resolution settings
    resolver 127.0.0.11 valid=30s;
    resolver_timeout 10s;

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name cloudtolocalllm.online www.cloudtolocalllm.online;
        return 301 https://$server_name$request_uri;
    }

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

        # Static files caching
        location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
            expires 30d;
            add_header Cache-Control "public, no-transform";
        }
    }
}
EOF

echo -e "${GREEN}Nginx configuration fixed!${NC}"

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if docker-compose.web.yml exists
if [ ! -f "docker-compose.web.yml" ]; then
    echo -e "${RED}Error: docker-compose.web.yml not found.${NC}"
    exit 1
fi

# Restart containers
echo -e "${YELLOW}Step 3: Restarting containers...${NC}"
docker-compose -f docker-compose.web.yml down || {
    echo -e "${RED}Failed to stop containers${NC}"
    exit 1
}

docker-compose -f docker-compose.web.yml up -d || {
    echo -e "${RED}Failed to start containers${NC}"
    exit 1
}

echo -e "${GREEN}====== Deployment Completed! ======${NC}"
echo -e "${GREEN}The portal should now be accessible at https://cloudtolocalllm.online${NC}"

# Check container status
echo -e "${YELLOW}Checking container status:${NC}"
docker-compose -f docker-compose.web.yml ps 