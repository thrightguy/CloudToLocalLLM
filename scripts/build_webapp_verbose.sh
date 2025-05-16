#!/bin/bash
set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

function step() {
  echo -e "${YELLOW}==> $1${NC}"
}

step "Showing Dockerfile (first 20 lines):"
if [ -f Dockerfile ]; then
  head -20 Dockerfile
else
  echo -e "${RED}Dockerfile not found!${NC}"
fi

step "Showing docker-compose.web.yml (first 20 lines):"
if [ -f docker-compose.web.yml ]; then
  head -20 docker-compose.web.yml
else
  echo -e "${RED}docker-compose.web.yml not found!${NC}"
fi

step "Cleaning up old containers, images, and volumes..."
docker-compose -f docker-compose.web.yml down --remove-orphans -v || true
docker system prune -af || true

step "Removing any old nginx config files from build context..."
rm -f ./build/web/etc/nginx/conf.d/default.conf
rm -f ./build/web/etc/nginx/nginx.conf

step "Building webapp container with verbose output..."
BUILD_COMMAND="docker-compose -f docker-compose.web.yml build --no-cache webapp"
if command -v docker buildx &> /dev/null; then
  export DOCKER_BUILDKIT=1
  ${BUILD_COMMAND}
else
  echo -e "${YELLOW}Buildx not found, building without BuildKit...${NC}"
  ${BUILD_COMMAND}
fi

step "Starting webapp container..."
docker-compose -f docker-compose.web.yml up -d

step "Checking container status..."
docker-compose -f docker-compose.web.yml ps

step "Showing webapp logs (last 50 lines):"
docker-compose -f docker-compose.web.yml logs --tail=50 webapp

step "Done. If the container is not running, check the logs above for errors." 