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
head -20 Dockerfile || echo -e "${RED}Dockerfile not found!${NC}"

step "Showing docker-compose.web.yml (first 20 lines):"
head -20 docker-compose.web.yml || echo -e "${RED}docker-compose.web.yml not found!${NC}"

step "Cleaning up old containers, images, and volumes..."
docker-compose -f docker-compose.web.yml down --remove-orphans -v || true
docker system prune -af || true

step "Removing any old nginx config files from build context..."
rm -f ./build/web/etc/nginx/conf.d/default.conf || true
rm -f ./build/web/etc/nginx/nginx.conf || true

step "Building webapp container with verbose output..."
if command -v docker buildx &> /dev/null; then
  export DOCKER_BUILDKIT=1
  docker-compose -f docker-compose.web.yml build --no-cache webapp
else
  echo -e "${YELLOW}Buildx not found, building without BuildKit...${NC}"
  docker-compose -f docker-compose.web.yml build --no-cache webapp
fi

step "Starting webapp container..."
docker-compose -f docker-compose.web.yml up -d

step "Checking container status..."
docker-compose -f docker-compose.web.yml ps

step "Showing webapp logs (last 50 lines):"
docker-compose -f docker-compose.web.yml logs --tail=50 webapp

step "Done. If the container is not running, check the logs above for errors." 