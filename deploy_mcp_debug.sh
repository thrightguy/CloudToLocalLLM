#!/bin/bash
# Deploy CloudToLocalLLM with MCP Flutter Inspector support
# This script enables remote debugging capabilities for the production app
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VM_SERVICE_PORT=${VM_SERVICE_PORT:-8182}
DDS_PORT=${DDS_PORT:-8181}
MCP_SERVER_PORT=${MCP_SERVER_PORT:-3334}
TUNNEL_PORT=${TUNNEL_PORT:-2222}

echo -e "${BLUE}=== CloudToLocalLLM MCP Debug Deployment ===${NC}"
echo -e "${YELLOW}This will enable remote Flutter debugging capabilities${NC}"
echo -e "${RED}WARNING: This exposes debugging services. Use only in secure environments.${NC}"
echo ""

# Confirm deployment
read -p "Continue with MCP debug deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi

echo -e "${YELLOW}Starting MCP debug deployment...${NC}"

# Pull latest code
echo -e "${YELLOW}Pulling latest code...${NC}"
git pull

# Ensure MCP toolkit is added
echo -e "${YELLOW}Ensuring MCP toolkit dependency...${NC}"
if ! grep -q "mcp_toolkit:" pubspec.yaml; then
    echo -e "${YELLOW}Adding MCP toolkit dependency...${NC}"
    /opt/flutter/bin/flutter pub add mcp_toolkit
    git add pubspec.yaml pubspec.lock
    git commit -m "Add MCP toolkit for remote debugging" || true
fi

# Build Flutter web app with debug support
echo -e "${YELLOW}Building Flutter web app with debug support...${NC}"
/opt/flutter/bin/flutter clean
/opt/flutter/bin/flutter pub get
/opt/flutter/bin/flutter build web --debug --dart-define=FLUTTER_WEB_USE_SKIA=true --source-maps

# Stop existing container
echo -e "${YELLOW}Stopping existing webapp container...${NC}"
docker stop cloudtolocalllm-webapp || true

# Create debug-enabled Docker container
echo -e "${YELLOW}Creating debug-enabled container...${NC}"
docker run -d \
    --name cloudtolocalllm-webapp-debug \
    --restart unless-stopped \
    -p 80:80 \
    -p 443:443 \
    -p ${VM_SERVICE_PORT}:${VM_SERVICE_PORT} \
    -p ${DDS_PORT}:${DDS_PORT} \
    -v $(pwd)/build/web:/usr/share/nginx/html:ro \
    -v $(pwd)/static_homepage:/usr/share/nginx/landing:ro \
    -v $(pwd)/config/nginx/nginx-webapp-internal.conf:/etc/nginx/conf.d/default.conf:ro \
    nginx:alpine

# Configure firewall for debug ports (temporary)
echo -e "${YELLOW}Configuring firewall for debug access...${NC}"
ufw allow ${VM_SERVICE_PORT}/tcp comment "Flutter VM Service (temporary)"
ufw allow ${DDS_PORT}/tcp comment "Flutter DDS (temporary)"
ufw allow ${MCP_SERVER_PORT}/tcp comment "MCP Server (temporary)"

echo -e "${GREEN}MCP debug deployment complete!${NC}"
echo ""
echo -e "${BLUE}=== Connection Information ===${NC}"
echo -e "${YELLOW}Flutter VM Service:${NC} https://cloudtolocalllm.online:${VM_SERVICE_PORT}"
echo -e "${YELLOW}Flutter DDS:${NC} https://cloudtolocalllm.online:${DDS_PORT}"
echo -e "${YELLOW}MCP Server Port:${NC} ${MCP_SERVER_PORT}"
echo ""
echo -e "${BLUE}=== Security Notes ===${NC}"
echo -e "${RED}• Debug ports are now exposed to the internet${NC}"
echo -e "${RED}• Use strong SSH keys and limit access by IP if possible${NC}"
echo -e "${RED}• Run 'deploy_mcp_cleanup.sh' when debugging is complete${NC}"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Configure your local MCP server to connect to the remote endpoints${NC}"
echo -e "${YELLOW}2. Set up SSH tunnel for secure access (recommended)${NC}"
echo -e "${YELLOW}3. Test the connection with Augment${NC}"
