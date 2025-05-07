#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}===========================================================${NC}"
echo -e "${YELLOW}CloudToLocalLLM Deployment with Monitoring${NC}"
echo -e "${YELLOW}===========================================================${NC}"

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Pull latest changes if this is a Git repository
if [ -d ".git" ]; then
    echo -e "${YELLOW}Pulling latest changes from Git repository...${NC}"
    git stash
    git pull
    chmod +x *.sh
    echo -e "${GREEN}Repository updated.${NC}"
fi

# Step 1: Create .htpasswd file for monitoring authentication
echo -e "${YELLOW}Setting up monitoring authentication...${NC}"
echo -e 'admin:$apr1$zrXoWCvp$AuERJYPWY9SAkmS22S6.I1' > .htpasswd
echo -e "${GREEN}Monitoring credentials created:${NC}"
echo -e "${GREEN}Username: admin${NC}"
echo -e "${GREEN}Password: cloudtolocalllm${NC}"
echo -e "${YELLOW}Please change these credentials for production use!${NC}"

# Step 2: Set up SSL certificates
if [ ! -d "certbot/conf/live/cloudtolocalllm.online" ]; then
    echo -e "${YELLOW}Setting up SSL certificates...${NC}"
    
    # Stop containers to free port 80
    docker-compose -f docker-compose.monitoring.yml down || true
    
    # Create certbot directories
    mkdir -p certbot/conf certbot/www
    
    # Get SSL certificate using standalone mode
    docker run --rm -p 80:80 -p 443:443 \
      -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
      -v "$(pwd)/certbot/www:/var/www/certbot" \
      certbot/certbot certonly --standalone \
      --agree-tos --no-eff-email \
      --email admin@cloudtolocalllm.online \
      -d cloudtolocalllm.online -d www.cloudtolocalllm.online -d beta.cloudtolocalllm.online
      
    echo -e "${GREEN}SSL certificates generated.${NC}"
else
    echo -e "${GREEN}SSL certificates already exist.${NC}"
fi

# Step 3: Create or update server.conf
echo -e "${YELLOW}Setting up Nginx configuration...${NC}"

cat > server.conf << 'EOF'
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

    # Netdata monitoring dashboard
    location /monitor/ {
        proxy_pass http://netdata:19999/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Basic authentication
        auth_basic "Monitoring Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
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
EOF

echo -e "${GREEN}Nginx configuration created.${NC}"

# Optional: Ask for Netdata Cloud token if user wants cloud monitoring
echo -e "${YELLOW}Would you like to connect to Netdata Cloud for remote monitoring? (y/n)${NC}"
read -r use_cloud

if [[ "$use_cloud" == "y" || "$use_cloud" == "Y" ]]; then
    echo -e "${YELLOW}Please get a claim token from https://app.netdata.cloud${NC}"
    echo -e "${YELLOW}Enter your Netdata claim token (or press Enter to skip):${NC}"
    read -r claim_token
    
    if [[ -n "$claim_token" ]]; then
        echo -e "${YELLOW}Enter your Netdata room ID (or press Enter to use default):${NC}"
        read -r claim_rooms
        
        # Export the variables
        export NETDATA_CLAIM_TOKEN="$claim_token"
        if [[ -n "$claim_rooms" ]]; then
            export NETDATA_CLAIM_ROOMS="$claim_rooms"
        fi
    fi
fi

# Step 4: Build and start containers
echo -e "${YELLOW}Building and starting containers...${NC}"
docker-compose -f docker-compose.monitoring.yml build
docker-compose -f docker-compose.monitoring.yml up -d

# Step 5: Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
sleep 10

# Check if containers are running
if docker ps | grep -q "webapp" && docker ps | grep -q "auth" && docker ps | grep -q "cloudtolocalllm_monitor"; then
    echo -e "${GREEN}All services are running!${NC}"
    
    # Get host IP
    host_ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}===========================================================${NC}"
    echo -e "${GREEN}Deployment Successful!${NC}"
    echo -e "${GREEN}===========================================================${NC}"
    echo -e "${GREEN}Main website: https://cloudtolocalllm.online${NC}"
    echo -e "${GREEN}Beta site with auth: https://beta.cloudtolocalllm.online${NC}"
    echo -e "${GREEN}Monitoring dashboard: https://cloudtolocalllm.online/monitor/${NC}"
    echo -e "${YELLOW}Monitoring credentials: admin / cloudtolocalllm${NC}"
    
    if [[ -n "${NETDATA_CLAIM_TOKEN:-}" ]]; then
        echo -e "${GREEN}Your system has been claimed to Netdata Cloud.${NC}"
        echo -e "${GREEN}Visit https://app.netdata.cloud to view your dashboard remotely.${NC}"
    fi
    
    echo -e "${GREEN}===========================================================${NC}"
else
    echo -e "${RED}Some services failed to start. Check the logs:${NC}"
    echo -e "${YELLOW}docker-compose -f docker-compose.monitoring.yml logs${NC}"
fi 