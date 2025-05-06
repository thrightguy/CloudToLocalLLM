#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Pulling latest changes from GitHub...${NC}"

# Navigate to the project directory
cd /opt/cloudtolocalllm/portal || {
  echo -e "${RED}Error: Could not navigate to /opt/cloudtolocalllm/portal${NC}"
  exit 1
}

# Save any local changes
if [[ -n $(git status --porcelain) ]]; then
  echo -e "${YELLOW}Local changes detected. Stashing them...${NC}"
  git stash
fi

# Pull the latest changes
git pull origin master || git pull origin main

# Make scripts executable
chmod +x *.sh 2>/dev/null || echo -e "${YELLOW}No .sh files to make executable${NC}"

echo -e "${GREEN}Successfully pulled latest changes from GitHub!${NC}"
echo -e "${YELLOW}To deploy these changes, run: ./update_and_deploy.sh${NC}" 