#!/bin/bash
# Setup secure SSH tunnel for MCP Flutter Inspector remote debugging
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VPS_HOST=${VPS_HOST:-"cloudllm@cloudtolocalllm.online"}
SSH_KEY=${SSH_KEY:-"~/.ssh/id_rsa"}
VM_SERVICE_PORT=${VM_SERVICE_PORT:-8182}
DDS_PORT=${DDS_PORT:-8181}
MCP_SERVER_PORT=${MCP_SERVER_PORT:-3334}
LOCAL_VM_PORT=${LOCAL_VM_PORT:-18182}
LOCAL_DDS_PORT=${LOCAL_DDS_PORT:-18181}
LOCAL_MCP_PORT=${LOCAL_MCP_PORT:-13334}

echo -e "${BLUE}=== MCP Flutter Inspector SSH Tunnel Setup ===${NC}"
echo -e "${YELLOW}This will create secure tunnels to the remote Flutter debug services${NC}"
echo ""

# Check if SSH key exists
if [ ! -f "${SSH_KEY}" ]; then
    echo -e "${RED}SSH key not found at ${SSH_KEY}${NC}"
    echo -e "${YELLOW}Please specify the correct SSH key path:${NC}"
    read -p "SSH Key Path: " SSH_KEY
    if [ ! -f "${SSH_KEY}" ]; then
        echo -e "${RED}SSH key still not found. Exiting.${NC}"
        exit 1
    fi
fi

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection to VPS...${NC}"
if ! ssh -i "${SSH_KEY}" -o ConnectTimeout=10 "${VPS_HOST}" "echo 'SSH connection successful'"; then
    echo -e "${RED}Failed to connect to VPS. Please check your SSH configuration.${NC}"
    exit 1
fi

echo -e "${GREEN}SSH connection successful!${NC}"

# Check if remote debug services are running
echo -e "${YELLOW}Checking remote debug services...${NC}"
if ! ssh -i "${SSH_KEY}" "${VPS_HOST}" "netstat -ln | grep :${VM_SERVICE_PORT}"; then
    echo -e "${RED}Flutter VM Service not detected on remote port ${VM_SERVICE_PORT}${NC}"
    echo -e "${YELLOW}Make sure you've run 'deploy_mcp_debug.sh' on the VPS first${NC}"
    exit 1
fi

# Kill existing tunnels
echo -e "${YELLOW}Stopping any existing tunnels...${NC}"
pkill -f "ssh.*${VPS_HOST}.*${VM_SERVICE_PORT}" || true
pkill -f "ssh.*${VPS_HOST}.*${DDS_PORT}" || true
pkill -f "ssh.*${VPS_HOST}.*${MCP_SERVER_PORT}" || true

# Create SSH tunnels
echo -e "${YELLOW}Creating SSH tunnels...${NC}"

# Flutter VM Service tunnel
ssh -i "${SSH_KEY}" -f -N -L ${LOCAL_VM_PORT}:localhost:${VM_SERVICE_PORT} "${VPS_HOST}" &
VM_TUNNEL_PID=$!

# Flutter DDS tunnel
ssh -i "${SSH_KEY}" -f -N -L ${LOCAL_DDS_PORT}:localhost:${DDS_PORT} "${VPS_HOST}" &
DDS_TUNNEL_PID=$!

# MCP Server tunnel (for future use)
ssh -i "${SSH_KEY}" -f -N -L ${LOCAL_MCP_PORT}:localhost:${MCP_SERVER_PORT} "${VPS_HOST}" &
MCP_TUNNEL_PID=$!

# Wait a moment for tunnels to establish
sleep 3

# Verify tunnels
echo -e "${YELLOW}Verifying tunnels...${NC}"
if netstat -ln | grep ":${LOCAL_VM_PORT}" > /dev/null; then
    echo -e "${GREEN}✓ VM Service tunnel active (local:${LOCAL_VM_PORT} -> remote:${VM_SERVICE_PORT})${NC}"
else
    echo -e "${RED}✗ VM Service tunnel failed${NC}"
fi

if netstat -ln | grep ":${LOCAL_DDS_PORT}" > /dev/null; then
    echo -e "${GREEN}✓ DDS tunnel active (local:${LOCAL_DDS_PORT} -> remote:${DDS_PORT})${NC}"
else
    echo -e "${RED}✗ DDS tunnel failed${NC}"
fi

if netstat -ln | grep ":${LOCAL_MCP_PORT}" > /dev/null; then
    echo -e "${GREEN}✓ MCP Server tunnel active (local:${LOCAL_MCP_PORT} -> remote:${MCP_SERVER_PORT})${NC}"
else
    echo -e "${RED}✗ MCP Server tunnel failed${NC}"
fi

# Save tunnel PIDs for cleanup
echo "${VM_TUNNEL_PID}" > /tmp/mcp_vm_tunnel.pid
echo "${DDS_TUNNEL_PID}" > /tmp/mcp_dds_tunnel.pid
echo "${MCP_TUNNEL_PID}" > /tmp/mcp_server_tunnel.pid

echo ""
echo -e "${GREEN}SSH tunnels established successfully!${NC}"
echo ""
echo -e "${BLUE}=== Local Connection Information ===${NC}"
echo -e "${YELLOW}Flutter VM Service:${NC} http://localhost:${LOCAL_VM_PORT}"
echo -e "${YELLOW}Flutter DDS:${NC} http://localhost:${LOCAL_DDS_PORT}"
echo -e "${YELLOW}MCP Server:${NC} http://localhost:${LOCAL_MCP_PORT}"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Update your local MCP server configuration to use these local ports${NC}"
echo -e "${YELLOW}2. Test the connection with Augment${NC}"
echo -e "${YELLOW}3. Run 'scripts/stop_mcp_tunnel.sh' when finished${NC}"
echo ""
echo -e "${RED}Note: Keep this terminal open or run in background to maintain tunnels${NC}"
