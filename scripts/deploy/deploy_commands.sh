#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting deployment...${NC}"

# Create deployment directory
mkdir -p /opt/cloudtolocalllm/portal
cd /opt/cloudtolocalllm/portal || {
    echo -e "${RED}Failed to change to deployment directory${NC}"
    exit 1
}

# Clone GitHub repository
if [[ -d ".git" ]]; then
    echo -e "${YELLOW}Pulling latest changes...${NC}"
    git pull origin master || {
        echo -e "${RED}Failed to pull latest changes${NC}"
        exit 1
    }
else
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone https://github.com/thrightguy/CloudToLocalLLM.git . || {
        echo -e "${RED}Failed to clone repository${NC}"
        exit 1
    }
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh || {
        echo -e "${RED}Failed to download Docker installation script${NC}"
        exit 1
    }
    sh get-docker.sh || {
        echo -e "${RED}Failed to install Docker${NC}"
        exit 1
    }
    rm get-docker.sh
    echo -e "${GREEN}Docker installed successfully${NC}"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || {
        echo -e "${RED}Failed to download Docker Compose${NC}"
        exit 1
    }
    chmod +x /usr/local/bin/docker-compose || {
        echo -e "${RED}Failed to make Docker Compose executable${NC}"
        exit 1
    }
    echo -e "${GREEN}Docker Compose installed successfully${NC}"
fi

# Create required directories
mkdir -p certbot/www
mkdir -p certbot/conf

# Check if init-ssl.sh exists
if [[ ! -f "init-ssl.sh" ]]; then
    echo -e "${RED}Error: init-ssl.sh not found.${NC}"
    exit 1
fi

# Make initialization script executable
chmod +x init-ssl.sh || {
    echo -e "${RED}Failed to make init-ssl.sh executable.${NC}"
    exit 1
}

# Make daemon installation scripts executable
if [[ -f "install_daemon.sh" ]]; then
    chmod +x install_daemon.sh || {
        echo -e "${RED}Failed to make install_daemon.sh executable.${NC}"
        exit 1
    }
fi

# Check if docker-compose.web.yml exists
if [[ ! -f "docker-compose.web.yml" ]]; then
    echo -e "${RED}Error: docker-compose.web.yml not found.${NC}"
    exit 1
fi

# Stop existing containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
docker-compose -f docker-compose.web.yml down 2>/dev/null || true

# Start services
echo -e "${YELLOW}Starting services...${NC}"
docker-compose -f docker-compose.web.yml up -d || {
    echo -e "${RED}Failed to start services${NC}"
    exit 1
}

# Start auth service if available
if [[ -f "docker-compose.auth.yml" ]]; then
    echo -e "${YELLOW}Starting authentication services...${NC}"
    docker-compose -f docker-compose.auth.yml up -d || {
        echo -e "${RED}Failed to start authentication services${NC}"
        exit 1
    }
fi

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Initialize SSL
echo -e "${YELLOW}Initializing SSL certificates...${NC}"
./init-ssl.sh || {
    echo -e "${RED}Failed to initialize SSL certificates${NC}"
    exit 1
}

# Install daemon if script exists
if [[ -f "install_daemon.sh" ]]; then
    echo -e "${YELLOW}Installing system daemon...${NC}"
    ./install_daemon.sh || {
        echo -e "${RED}Failed to install system daemon${NC}"
        echo -e "${YELLOW}Continuing without daemon...${NC}"
    }
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}The portal should now be accessible at https://cloudtolocalllm.online${NC}"

# If daemon was installed, show instructions
if [[ -f "/usr/local/bin/cloudctl" ]]; then
    echo -e "\n${GREEN}System daemon installed. You can manage the services with:${NC}"
    echo -e "  ${YELLOW}cloudctl${NC} {start|stop|restart|status|logs|update}"
fi 