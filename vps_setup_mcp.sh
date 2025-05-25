#!/bin/bash
# VPS setup script for MCP Flutter Inspector remote debugging
# Run this script on cloudtolocalllm.online after pushing changes from local machine

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              VPS MCP Setup for CloudToLocalLLM               ║${NC}"
echo -e "${BLUE}║                Remote Debugging Configuration                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if we're on the VPS
if [ "$(whoami)" != "cloudllm" ]; then
    echo -e "${YELLOW}Warning: This script should be run as the cloudllm user on the VPS${NC}"
    echo -e "${YELLOW}Current user: $(whoami)${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Navigate to the project directory
PROJECT_DIR="/var/www/html"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Project directory not found at $PROJECT_DIR${NC}"
    echo -e "${YELLOW}Please specify the correct project directory:${NC}"
    read -p "Project Directory: " PROJECT_DIR
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}Directory still not found. Exiting.${NC}"
        exit 1
    fi
fi

cd "$PROJECT_DIR"
echo -e "${GREEN}✓ Working in: $(pwd)${NC}"

# Pull latest changes
echo -e "${YELLOW}📥 Pulling latest changes from repository...${NC}"
git pull origin master

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    if [ -f "/opt/flutter/bin/flutter" ]; then
        echo -e "${YELLOW}Using Flutter from /opt/flutter/bin/flutter${NC}"
        FLUTTER_CMD="/opt/flutter/bin/flutter"
    else
        echo -e "${RED}Flutter not found. Please install Flutter first.${NC}"
        exit 1
    fi
else
    FLUTTER_CMD="flutter"
fi

# Add MCP toolkit dependency if not present
echo -e "${YELLOW}📦 Checking MCP toolkit dependency...${NC}"
if ! grep -q "mcp_toolkit:" pubspec.yaml; then
    echo -e "${YELLOW}Adding MCP toolkit dependency...${NC}"
    $FLUTTER_CMD pub add mcp_toolkit
else
    echo -e "${GREEN}✓ MCP toolkit already present${NC}"
fi

# Get Flutter dependencies
echo -e "${YELLOW}📦 Getting Flutter dependencies...${NC}"
$FLUTTER_CMD pub get

# Make scripts executable
echo -e "${YELLOW}🔧 Making scripts executable...${NC}"
chmod +x deploy_mcp_debug.sh
chmod +x deploy_mcp_cleanup.sh
chmod +x setup_remote_mcp.sh
chmod +x scripts/setup_mcp_tunnel.sh
chmod +x scripts/stop_mcp_tunnel.sh

# Check Docker status
echo -e "${YELLOW}🐳 Checking Docker status...${NC}"
if ! docker ps &> /dev/null; then
    echo -e "${RED}Docker is not running or accessible. Please check Docker installation.${NC}"
    exit 1
fi

# Check if webapp container exists
if docker ps -a | grep -q "cloudtolocalllm-webapp"; then
    echo -e "${GREEN}✓ Found existing webapp container${NC}"
else
    echo -e "${YELLOW}⚠️  Webapp container not found. You may need to deploy the app first.${NC}"
fi

echo ""
echo -e "${GREEN}✅ VPS setup complete!${NC}"
echo ""
echo -e "${BLUE}📋 Available Commands:${NC}"
echo -e "${YELLOW}1. Enable debug mode:${NC}"
echo -e "${CYAN}   ./deploy_mcp_debug.sh${NC}"
echo ""
echo -e "${YELLOW}2. Disable debug mode (restore production):${NC}"
echo -e "${CYAN}   ./deploy_mcp_cleanup.sh${NC}"
echo ""
echo -e "${YELLOW}3. Regular deployment update:${NC}"
echo -e "${CYAN}   ./deploy_update.sh${NC}"
echo ""
echo -e "${YELLOW}4. Debug deployment with MCP support:${NC}"
echo -e "${CYAN}   MCP_DEBUG_MODE=true ./deploy_update.sh${NC}"
echo ""
echo -e "${BLUE}🔒 Security Notes:${NC}"
echo -e "${RED}• Debug mode exposes debugging services on ports 8182, 8181, 3334${NC}"
echo -e "${RED}• Only enable debug mode when actively debugging${NC}"
echo -e "${RED}• Always run cleanup script after debugging${NC}"
echo -e "${GREEN}• Use SSH tunnels from local machine for secure access${NC}"
echo ""
echo -e "${BLUE}📖 For detailed instructions, see:${NC}"
echo -e "${CYAN}docs/MCP_REMOTE_DEBUGGING_GUIDE.md${NC}"
