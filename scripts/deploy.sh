#!/bin/bash

# Exit on error
set -e

# Configuration
VPS_USER="cloudadmin"
VPS_HOST="cloudtolocalllm.online"
SSH_KEY="~/.ssh/cloudtolocalllm"
APP_DIR="~/cloudtolocalllm"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting deployment...${NC}"

# Create remote directory if it doesn't exist
echo -e "${GREEN}Setting up remote directory...${NC}"
ssh -i $SSH_KEY $VPS_USER@$VPS_HOST "mkdir -p $APP_DIR/web"

# Copy the built web app
echo -e "${GREEN}Copying web app to server...${NC}"
scp -i $SSH_KEY -r web/* $VPS_USER@$VPS_HOST:$APP_DIR/web/

# Copy Docker configuration files
echo -e "${GREEN}Copying Docker configuration...${NC}"
scp -i $SSH_KEY docker-compose.yml Dockerfile.web $VPS_USER@$VPS_HOST:$APP_DIR/

# Build and start Docker containers
echo -e "${GREEN}Building and starting Docker containers...${NC}"
ssh -i $SSH_KEY $VPS_USER@$VPS_HOST "cd $APP_DIR && docker-compose up -d --build"

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Your application should now be available at https://cloudtolocalllm.online${NC}" 