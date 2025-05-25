#!/bin/bash
# Stop MCP Flutter Inspector SSH tunnels
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Stopping MCP Flutter Inspector SSH Tunnels ===${NC}"

# Stop tunnels by PID if available
if [ -f "/tmp/mcp_vm_tunnel.pid" ]; then
    VM_PID=$(cat /tmp/mcp_vm_tunnel.pid)
    if kill -0 "$VM_PID" 2>/dev/null; then
        kill "$VM_PID"
        echo -e "${GREEN}✓ Stopped VM Service tunnel (PID: $VM_PID)${NC}"
    fi
    rm -f /tmp/mcp_vm_tunnel.pid
fi

if [ -f "/tmp/mcp_dds_tunnel.pid" ]; then
    DDS_PID=$(cat /tmp/mcp_dds_tunnel.pid)
    if kill -0 "$DDS_PID" 2>/dev/null; then
        kill "$DDS_PID"
        echo -e "${GREEN}✓ Stopped DDS tunnel (PID: $DDS_PID)${NC}"
    fi
    rm -f /tmp/mcp_dds_tunnel.pid
fi

if [ -f "/tmp/mcp_server_tunnel.pid" ]; then
    MCP_PID=$(cat /tmp/mcp_server_tunnel.pid)
    if kill -0 "$MCP_PID" 2>/dev/null; then
        kill "$MCP_PID"
        echo -e "${GREEN}✓ Stopped MCP Server tunnel (PID: $MCP_PID)${NC}"
    fi
    rm -f /tmp/mcp_server_tunnel.pid
fi

# Kill any remaining SSH tunnels to cloudtolocalllm.online
echo -e "${YELLOW}Cleaning up any remaining tunnels...${NC}"
pkill -f "ssh.*cloudtolocalllm.online.*8182" || true
pkill -f "ssh.*cloudtolocalllm.online.*8181" || true
pkill -f "ssh.*cloudtolocalllm.online.*3334" || true

echo -e "${GREEN}All MCP tunnels stopped successfully!${NC}"
