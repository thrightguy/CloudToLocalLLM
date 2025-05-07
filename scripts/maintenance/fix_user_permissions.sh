#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Fixing container user permissions...${NC}"

# Stop containers
docker-compose -f docker-compose.web.yml down

# Create a modified Dockerfile.web with correct user handling
cat > Dockerfile.web.fixed << 'EOF'
FROM nginx:alpine

# Create necessary directories with correct permissions
RUN mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp \
    /var/run \
    /etc/letsencrypt \
    && chmod -R 755 /var/cache/nginx \
    && chmod -R 755 /var/run \
    && chmod -R 755 /etc/letsencrypt \
    && touch /var/run/nginx.pid \
    && chmod 644 /var/run/nginx.pid

# Copy the built web files
COPY . /usr/share/nginx/html
RUN chmod -R 755 /usr/share/nginx/html

# Copy nginx configuration
COPY server.conf /etc/nginx/conf.d/default.conf
RUN chmod 644 /etc/nginx/conf.d/default.conf

# Expose ports
EXPOSE 80 443

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

# Check if server.conf exists, if not, create it
if [ ! -f "server.conf" ]; then
  echo -e "${YELLOW}Creating server.conf...${NC}"
  cat > server.conf << 'EOF'
# HTTP redirect for all domains
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

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}

# Beta subdomain with auth service integration
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
        return 200 'OK';
        add_header Content-Type text/plain;
    }
    
    # Auth service proxy for login/register endpoints
    location /auth/ {
        proxy_pass http://auth:8080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Handle SPA routing
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        
        # Add header to indicate beta environment to the client app
        add_header X-Environment "beta";
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF
fi

# Replace Dockerfile.web with fixed version
mv Dockerfile.web.fixed Dockerfile.web
chmod +x Dockerfile.web

echo -e "${YELLOW}Building and starting containers with fixed permissions...${NC}"

# Create modified docker-compose.yml with proper security settings
cat > docker-compose.web.fixed.yml << 'EOF'
version: '3'
services:
  webapp:
    build:
      context: .
      dockerfile: Dockerfile.web
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
    volumes:
      - ./certbot/www:/var/www/certbot:ro
      - ./certbot/conf:/etc/letsencrypt:ro
    environment:
      - NGINX_HOST=cloudtolocalllm.online
      - NGINX_SSL_CERT=/etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem
      - NGINX_SSL_KEY=/etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
      - CHOWN
      - SETGID
      - SETUID
    depends_on:
      - auth
    networks:
      - webnet
      
  auth:
    build:
      context: ./auth_service
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      - PORT=8080
      - JWT_SECRET=your_jwt_secret_key_here
    volumes:
      - ./auth_service/data:/app/data
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    networks:
      - webnet

networks:
  webnet:
    driver: bridge
EOF

# Use the modified docker-compose file
docker-compose -f docker-compose.web.fixed.yml build --no-cache
docker-compose -f docker-compose.web.fixed.yml up -d

echo -e "${GREEN}Container rebuilt with proper user permissions!${NC}"
echo -e "${GREEN}Check container status:${NC}"
docker ps

echo -e "${YELLOW}Checking container logs:${NC}"
sleep 5
docker-compose -f docker-compose.web.fixed.yml logs webapp 