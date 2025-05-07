#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting CloudToLocalLLM Portal deployment...${NC}"

# Create deployment directory
DEPLOY_DIR="/opt/cloudtolocalllm/portal"
echo -e "${YELLOW}Creating deployment directory at ${DEPLOY_DIR}...${NC}"
sudo mkdir -p ${DEPLOY_DIR}
sudo chown -R $USER:$USER ${DEPLOY_DIR}

# Copy necessary files
echo -e "${YELLOW}Copying configuration files...${NC}"
cp nginx.conf ${DEPLOY_DIR}/
cp docker-compose.web.yml ${DEPLOY_DIR}/
cp init-ssl.sh ${DEPLOY_DIR}/
cp Dockerfile.web ${DEPLOY_DIR}/

# Create required directories
echo -e "${YELLOW}Creating required directories...${NC}"
mkdir -p ${DEPLOY_DIR}/certbot/www
mkdir -p ${DEPLOY_DIR}/certbot/conf

# Make scripts executable
chmod +x ${DEPLOY_DIR}/init-ssl.sh

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Stop any existing containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
cd ${DEPLOY_DIR}
docker-compose -f docker-compose.web.yml down

# Start the services
echo -e "${YELLOW}Starting services...${NC}"
docker-compose -f docker-compose.web.yml up -d

# Initialize SSL
echo -e "${YELLOW}Initializing SSL certificates...${NC}"
./init-ssl.sh

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}The portal should now be accessible at https://cloudtolocalllm.online${NC}" 