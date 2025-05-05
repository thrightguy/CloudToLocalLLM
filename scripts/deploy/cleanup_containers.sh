#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting deep cleanup process...${NC}"

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Docker is not running. Please start Docker first.${NC}"
        exit 1
    fi
}

# Check Docker status
check_docker

# Stop all running containers
echo -e "${YELLOW}Stopping all running containers...${NC}"
if [ "$(docker ps -q)" ]; then
    docker stop $(docker ps -q)
    echo -e "${GREEN}All containers stopped${NC}"
else
    echo -e "${GREEN}No running containers found${NC}"
fi

# Remove all containers (not images)
echo -e "${YELLOW}Removing all containers...${NC}"
if [ "$(docker ps -a -q)" ]; then
    docker rm $(docker ps -a -q) -f
    echo -e "${GREEN}All containers removed${NC}"
else
    echo -e "${GREEN}No containers to remove${NC}"
fi

# Remove unused networks
echo -e "${YELLOW}Cleaning up unused networks...${NC}"
docker network prune -f

# Remove unused volumes
echo -e "${YELLOW}Cleaning up unused volumes...${NC}"
docker volume prune -f

# Remove dangling images (unused and untagged)
echo -e "${YELLOW}Removing dangling images...${NC}"
if [ "$(docker images -f "dangling=true" -q)" ]; then
    docker rmi $(docker images -f "dangling=true" -q) -f
    echo -e "${GREEN}Dangling images removed${NC}"
else
    echo -e "${GREEN}No dangling images found${NC}"
fi

# Clean up Docker build cache
echo -e "${YELLOW}Cleaning Docker build cache...${NC}"
docker builder prune -f

# Clean system
echo -e "${YELLOW}Performing system cleanup...${NC}"
if command -v apt-get &> /dev/null; then
    echo -e "${YELLOW}Cleaning apt cache...${NC}"
    sudo apt-get clean
    sudo apt-get autoremove -y
fi

# Remove old logs
echo -e "${YELLOW}Cleaning old Docker logs...${NC}"
if [ -d "/var/lib/docker/containers" ]; then
    sudo find /var/lib/docker/containers -type f -name "*.log" -delete
fi

echo -e "${GREEN}Deep cleanup completed!${NC}"
echo -e "${YELLOW}System is ready for fresh deployment.${NC}"
echo -e "${GREEN}Important cached images have been preserved.${NC}"

# Print system status
echo -e "\n${YELLOW}Current system status:${NC}"
echo -e "Docker disk usage:"
docker system df
echo -e "\nAvailable disk space:"
df -h / 