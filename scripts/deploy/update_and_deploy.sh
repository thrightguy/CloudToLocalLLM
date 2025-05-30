#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}Updating CloudToLocalLLM portal...${NC}"

# Pull latest changes
echo -e "${BLUE}Pulling latest changes from git...${NC}"
git pull origin master

# Build Flutter web application
echo -e "${BLUE}Building Flutter web application...${NC}"
flutter clean
flutter pub get
flutter build web --no-tree-shake-icons

# Stop running containers
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker compose -f docker-compose.yml down

# Check if SSL certs exist and start services
if [ -d "certbot/live/cloudtolocalllm.online" ]; then
    echo -e "${YELLOW}SSL certificates already exist. Starting services...${NC}"
    docker compose -f docker-compose.yml up -d
else
    echo -e "${RED}SSL certificates not found. Please set up SSL certificates first.${NC}"
    echo -e "${YELLOW}You can use: certbot certonly --webroot -w /var/www/html -d cloudtolocalllm.online -d app.cloudtolocalllm.online${NC}"
    exit 1
fi

# Wait for containers to start
echo -e "${BLUE}Waiting for containers to start...${NC}"
sleep 10

# Check container health
echo -e "${BLUE}Checking container health...${NC}"
docker compose -f docker-compose.yml ps

# Verify web app accessibility
echo -e "${BLUE}Verifying web app accessibility...${NC}"
if curl -s -o /dev/null -w "%{http_code}" https://app.cloudtolocalllm.online | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ Web app is accessible at https://app.cloudtolocalllm.online${NC}"
else
    echo -e "${RED}✗ Web app may not be accessible. Check logs with: docker compose -f docker-compose.yml logs${NC}"
fi

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}The portal should now be accessible at:${NC}"
echo -e "${GREEN}  - Main site: https://cloudtolocalllm.online${NC}"
echo -e "${GREEN}  - Web app: https://app.cloudtolocalllm.online${NC}"