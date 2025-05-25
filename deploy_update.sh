#!/bin/bash
# NOTE: Do NOT run git push on the VPS. Only run this script after you have pushed your changes from your local machine and pulled them on the VPS.
# This script expects the Flutter web build output to be in build/web/ in your repo root.
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
MCP_DEBUG_MODE=${MCP_DEBUG_MODE:-false}
VM_SERVICE_PORT=${VM_SERVICE_PORT:-8182}
DDS_PORT=${DDS_PORT:-8181}

echo -e "${YELLOW}Starting CloudToLocalLLM deployment update...${NC}"

# Pull latest code
echo -e "${YELLOW}Pulling latest code...${NC}"
git pull

# Check if MCP toolkit is in pubspec.yaml
echo -e "${YELLOW}Checking MCP toolkit dependency...${NC}"
if ! grep -q "mcp_toolkit:" pubspec.yaml; then
    echo -e "${YELLOW}Adding MCP toolkit dependency...${NC}"
    /opt/flutter/bin/flutter pub add mcp_toolkit
fi

# Rebuild Flutter web app as user (not root)
if [ "$MCP_DEBUG_MODE" = "true" ]; then
    echo -e "${YELLOW}Building Flutter web app with debug support...${NC}"
    /opt/flutter/bin/flutter build web --debug --dart-define=FLUTTER_WEB_USE_SKIA=true
else
    echo -e "${YELLOW}Building Flutter web app for production...${NC}"
    /opt/flutter/bin/flutter build web
fi

# Copy static homepage
echo -e "${YELLOW}Copying static homepage to container...${NC}"
docker cp static_homepage/. cloudtolocalllm-webapp:/usr/share/nginx/landing/

# Copy Flutter build (from build/web)
echo -e "${YELLOW}Copying Flutter build to container...${NC}"
docker cp build/web/. cloudtolocalllm-webapp:/usr/share/nginx/html/

# Copy nginx config
echo -e "${YELLOW}Copying nginx config to container...${NC}"
docker cp config/nginx/nginx-webapp-internal.conf cloudtolocalllm-webapp:/etc/nginx/conf.d/default.conf

# Reload nginx
echo -e "${YELLOW}Reloading nginx...${NC}"
docker exec cloudtolocalllm-webapp nginx -s reload

echo -e "${GREEN}Update complete!${NC}"

if [ "$MCP_DEBUG_MODE" = "true" ]; then
    echo -e "${YELLOW}Debug mode enabled. VM Service will be available on port ${VM_SERVICE_PORT}${NC}"
    echo -e "${YELLOW}DDS will be available on port ${DDS_PORT}${NC}"
    echo -e "${RED}WARNING: Debug mode exposes debugging services. Use only in secure environments.${NC}"
fi