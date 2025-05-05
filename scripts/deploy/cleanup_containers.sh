#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting container cleanup...${NC}"

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
    docker rm $(docker ps -a -q)
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

echo -e "${GREEN}Cleanup completed! Cached images have been preserved.${NC}"
echo -e "${YELLOW}You can now proceed with deploying new containers.${NC}" 