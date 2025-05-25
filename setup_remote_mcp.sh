#!/bin/bash
# Complete setup script for MCP Flutter Inspector remote debugging
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
VPS_HOST=${VPS_HOST:-"cloudllm@cloudtolocalllm.online"}
SSH_KEY=${SSH_KEY:-"~/.ssh/id_rsa"}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           MCP Flutter Inspector Remote Setup                 ║${NC}"
echo -e "${BLUE}║              CloudToLocalLLM Production Debugging           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${CYAN}🔍 Checking prerequisites...${NC}"

# Check if SSH key exists
if [ ! -f "${SSH_KEY}" ]; then
    echo -e "${RED}❌ SSH key not found at ${SSH_KEY}${NC}"
    echo -e "${YELLOW}Please specify the correct SSH key path:${NC}"
    read -p "SSH Key Path: " SSH_KEY
    if [ ! -f "${SSH_KEY}" ]; then
        echo -e "${RED}SSH key still not found. Exiting.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ SSH key found${NC}"

# Check if MCP server is built
if [ ! -f "~/Dev/Tools/MCP/mcp_flutter/mcp_server/build/index.js" ]; then
    echo -e "${RED}❌ MCP server not found. Please run the local installation first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Local MCP server found${NC}"

# Test SSH connection
echo -e "${YELLOW}🔗 Testing SSH connection to VPS...${NC}"
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=10 "${VPS_HOST}" "echo 'SSH connection successful'" > /dev/null 2>&1; then
    echo -e "${RED}❌ Failed to connect to VPS. Please check your SSH configuration.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection successful${NC}"

echo ""
echo -e "${BLUE}📋 Setup Options:${NC}"
echo -e "${YELLOW}1. Full Setup (Deploy debug + Create tunnels + Configure MCP)${NC}"
echo -e "${YELLOW}2. Deploy Debug Mode Only${NC}"
echo -e "${YELLOW}3. Setup Tunnels Only${NC}"
echo -e "${YELLOW}4. Configure MCP Only${NC}"
echo -e "${YELLOW}5. Cleanup Everything${NC}"
echo ""

read -p "Choose an option (1-5): " -n 1 -r
echo ""

case $REPLY in
    1)
        echo -e "${CYAN}🚀 Starting full setup...${NC}"
        
        # Step 1: Deploy debug mode on VPS
        echo -e "${YELLOW}📤 Uploading debug deployment script to VPS...${NC}"
        scp -i "${SSH_KEY}" deploy_mcp_debug.sh "${VPS_HOST}:~/deploy_mcp_debug.sh"
        
        echo -e "${YELLOW}🔧 Deploying debug mode on VPS...${NC}"
        ssh -i "${SSH_KEY}" "${VPS_HOST}" "chmod +x ~/deploy_mcp_debug.sh && cd /var/www/html && ~/deploy_mcp_debug.sh"
        
        # Step 2: Setup tunnels
        echo -e "${YELLOW}🌐 Setting up SSH tunnels...${NC}"
        ./scripts/setup_mcp_tunnel.sh
        
        # Step 3: Configure MCP
        echo -e "${YELLOW}⚙️ Configuring local MCP server...${NC}"
        # Enable remote MCP server
        sed -i 's/"disabled": true/"disabled": false/' config/mcp_servers.json
        
        echo -e "${GREEN}✅ Full setup complete!${NC}"
        ;;
        
    2)
        echo -e "${CYAN}🔧 Deploying debug mode only...${NC}"
        scp -i "${SSH_KEY}" deploy_mcp_debug.sh "${VPS_HOST}:~/deploy_mcp_debug.sh"
        ssh -i "${SSH_KEY}" "${VPS_HOST}" "chmod +x ~/deploy_mcp_debug.sh && cd /var/www/html && ~/deploy_mcp_debug.sh"
        echo -e "${GREEN}✅ Debug mode deployed!${NC}"
        ;;
        
    3)
        echo -e "${CYAN}🌐 Setting up tunnels only...${NC}"
        ./scripts/setup_mcp_tunnel.sh
        echo -e "${GREEN}✅ Tunnels established!${NC}"
        ;;
        
    4)
        echo -e "${CYAN}⚙️ Configuring MCP only...${NC}"
        sed -i 's/"disabled": true/"disabled": false/' config/mcp_servers.json
        echo -e "${GREEN}✅ MCP configured!${NC}"
        ;;
        
    5)
        echo -e "${CYAN}🧹 Cleaning up everything...${NC}"
        
        # Stop local tunnels
        ./scripts/stop_mcp_tunnel.sh
        
        # Disable remote MCP server
        sed -i 's/"disabled": false/"disabled": true/' config/mcp_servers.json
        
        # Cleanup VPS
        scp -i "${SSH_KEY}" deploy_mcp_cleanup.sh "${VPS_HOST}:~/deploy_mcp_cleanup.sh"
        ssh -i "${SSH_KEY}" "${VPS_HOST}" "chmod +x ~/deploy_mcp_cleanup.sh && cd /var/www/html && ~/deploy_mcp_cleanup.sh"
        
        echo -e "${GREEN}✅ Cleanup complete!${NC}"
        ;;
        
    *)
        echo -e "${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}📖 Next Steps:${NC}"

if [[ $REPLY == "1" || $REPLY == "2" || $REPLY == "3" ]]; then
    echo -e "${YELLOW}1. Open Augment in VSCode${NC}"
    echo -e "${YELLOW}2. Try these commands:${NC}"
    echo -e "${CYAN}   • 'Take a screenshot of the CloudToLocalLLM production app'${NC}"
    echo -e "${CYAN}   • 'Show me the widget tree of the live application'${NC}"
    echo -e "${CYAN}   • 'What's the current performance of the production app?'${NC}"
    echo ""
    echo -e "${YELLOW}3. When finished, run:${NC}"
    echo -e "${CYAN}   ./setup_remote_mcp.sh${NC} (choose option 5 for cleanup)"
fi

if [[ $REPLY == "5" ]]; then
    echo -e "${GREEN}All remote debugging has been disabled.${NC}"
    echo -e "${GREEN}Your production app is now running in normal mode.${NC}"
fi

echo ""
echo -e "${BLUE}📚 For detailed information, see:${NC}"
echo -e "${CYAN}docs/MCP_REMOTE_DEBUGGING_GUIDE.md${NC}"
