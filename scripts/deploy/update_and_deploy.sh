#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Updating CloudToLocalLLM portal...${NC}"

# Pull latest changes
git pull origin master

# Stop running containers
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker-compose -f docker-compose.web.yml down

# Make scripts executable
chmod +x init-ssl.sh
chmod +x deploy_commands.sh

# Check if SSL certs exist
if [ -d "certbot/conf/live/cloudtolocalllm.online" ]; then
    echo -e "${YELLOW}SSL certificates already exist. Starting services...${NC}"
    docker-compose -f docker-compose.web.yml up -d
else
    echo -e "${YELLOW}SSL certificates not found. Running SSL initialization...${NC}"
    ./init-ssl.sh
fi

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}The portal should now be accessible at https://cloudtolocalllm.online${NC}" 