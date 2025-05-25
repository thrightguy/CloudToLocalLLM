#!/bin/bash
# Cleanup MCP debug deployment and restore production configuration
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VM_SERVICE_PORT=${VM_SERVICE_PORT:-8182}
DDS_PORT=${DDS_PORT:-8181}
MCP_SERVER_PORT=${MCP_SERVER_PORT:-3334}

echo -e "${BLUE}=== CloudToLocalLLM MCP Debug Cleanup ===${NC}"
echo -e "${YELLOW}This will disable remote debugging and restore production configuration${NC}"
echo ""

# Confirm cleanup
read -p "Continue with MCP debug cleanup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 0
fi

echo -e "${YELLOW}Starting MCP debug cleanup...${NC}"

# Stop debug container
echo -e "${YELLOW}Stopping debug container...${NC}"
docker stop cloudtolocalllm-webapp-debug || true
docker rm cloudtolocalllm-webapp-debug || true

# Rebuild production version
echo -e "${YELLOW}Building production Flutter web app...${NC}"
/opt/flutter/bin/flutter clean
/opt/flutter/bin/flutter pub get
/opt/flutter/bin/flutter build web --release

# Restart production container
echo -e "${YELLOW}Restarting production container...${NC}"
docker start cloudtolocalllm-webapp || {
    echo -e "${YELLOW}Production container not found, creating new one...${NC}"
    docker run -d \
        --name cloudtolocalllm-webapp \
        --restart unless-stopped \
        -p 80:80 \
        -p 443:443 \
        -v $(pwd)/build/web:/usr/share/nginx/html:ro \
        -v $(pwd)/static_homepage:/usr/share/nginx/landing:ro \
        -v $(pwd)/config/nginx/nginx-webapp-internal.conf:/etc/nginx/conf.d/default.conf:ro \
        nginx:alpine
}

# Update container with latest build
docker cp build/web/. cloudtolocalllm-webapp:/usr/share/nginx/html/
docker cp static_homepage/. cloudtolocalllm-webapp:/usr/share/nginx/landing/
docker cp config/nginx/nginx-webapp-internal.conf cloudtolocalllm-webapp:/etc/nginx/conf.d/default.conf
docker exec cloudtolocalllm-webapp nginx -s reload

# Remove firewall rules for debug ports
echo -e "${YELLOW}Removing firewall rules for debug ports...${NC}"
ufw delete allow ${VM_SERVICE_PORT}/tcp || true
ufw delete allow ${DDS_PORT}/tcp || true
ufw delete allow ${MCP_SERVER_PORT}/tcp || true

echo -e "${GREEN}MCP debug cleanup complete!${NC}"
echo ""
echo -e "${BLUE}=== Status ===${NC}"
echo -e "${GREEN}• Production configuration restored${NC}"
echo -e "${GREEN}• Debug ports closed${NC}"
echo -e "${GREEN}• Security hardened${NC}"
echo ""
echo -e "${YELLOW}Your application is now running in production mode at:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
