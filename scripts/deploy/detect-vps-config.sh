#!/bin/bash

# Detect VPS Configuration for CloudToLocalLLM
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}CloudToLocalLLM VPS Configuration Detection${NC}"
echo -e "${BLUE}===========================================${NC}"

# Check SSH config for cloudtolocalllm hosts
echo -e "\n${YELLOW}Checking SSH configuration...${NC}"
if [ -f ~/.ssh/config ]; then
    echo "SSH config found. Checking for CloudToLocalLLM hosts:"
    grep -A 5 -B 1 -i "cloudtolocalllm\|Host.*app\|Host.*docs" ~/.ssh/config || echo "No CloudToLocalLLM hosts found in SSH config"
else
    echo "No SSH config found at ~/.ssh/config"
fi

# Check known_hosts for cloudtolocalllm domains
echo -e "\n${YELLOW}Checking known hosts...${NC}"
if [ -f ~/.ssh/known_hosts ]; then
    echo "Checking known_hosts for CloudToLocalLLM domains:"
    grep -i "cloudtolocalllm" ~/.ssh/known_hosts || echo "No CloudToLocalLLM entries found in known_hosts"
else
    echo "No known_hosts file found"
fi

# Check for existing deployment scripts
echo -e "\n${YELLOW}Checking existing deployment configuration...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check PowerShell scripts for VPS info
if ls "$SCRIPT_DIR"/*.ps1 &> /dev/null; then
    echo "Found PowerShell deployment scripts:"
    for script in "$SCRIPT_DIR"/*.ps1; do
        echo "  - $(basename "$script")"
        # Look for server/host configurations
        if grep -i "server\|host\|ip" "$script" | head -3; then
            echo "    Contains server configuration"
        fi
    done
fi

# Check bash scripts for VPS info
echo -e "\nChecking bash scripts for VPS configuration:"
for script in "$SCRIPT_DIR"/*.sh; do
    if [ -f "$script" ] && [ "$(basename "$script")" != "detect-vps-config.sh" ]; then
        echo "  - $(basename "$script")"
        # Look for SSH commands or server references
        if grep -n "ssh\|scp\|rsync" "$script" | head -2; then
            echo "    Contains remote commands"
        fi
    fi
done

# Try to resolve CloudToLocalLLM domains
echo -e "\n${YELLOW}Checking DNS resolution...${NC}"
for domain in cloudtolocalllm.online app.cloudtolocalllm.online docs.cloudtolocalllm.online; do
    echo -n "  $domain: "
    if ip=$(dig +short "$domain" 2>/dev/null) && [ -n "$ip" ]; then
        echo -e "${GREEN}$ip${NC}"
    else
        echo -e "${RED}Not resolved${NC}"
    fi
done

# Check if we can ping the domains
echo -e "\n${YELLOW}Checking connectivity...${NC}"
for domain in cloudtolocalllm.online app.cloudtolocalllm.online; do
    echo -n "  Ping $domain: "
    if ping -c 1 -W 3 "$domain" &> /dev/null; then
        echo -e "${GREEN}Reachable${NC}"
    else
        echo -e "${RED}Not reachable${NC}"
    fi
done

# Check current git remote
echo -e "\n${YELLOW}Checking git configuration...${NC}"
if git remote -v 2>/dev/null; then
    echo "Git remotes found"
else
    echo "No git remotes or not in a git repository"
fi

# Suggest next steps
echo -e "\n${BLUE}Suggested next steps:${NC}"
echo "1. Update VPS_HOST in scripts/deploy/push-to-live.sh with your actual VPS IP/hostname"
echo "2. Ensure SSH key authentication is set up for your VPS"
echo "3. Test SSH connection: ssh rightguy@YOUR_VPS_IP"
echo "4. Run deployment: ./scripts/deploy/push-to-live.sh --status"

echo -e "\n${YELLOW}If you need to find your VPS IP:${NC}"
echo "  - Check your VPS provider dashboard"
echo "  - Check DNS records: dig cloudtolocalllm.online"
echo "  - Check your SSH config or deployment scripts"
