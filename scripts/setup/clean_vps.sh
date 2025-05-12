#!/bin/bash
# Clean up Docker system on the VPS, keeping all general images and only removing unused data.
# Stops all containers, prunes unused containers, networks, build cache, and unused volumes.
# Does NOT remove images in use or with the 'cloudtolocalllm-' prefix.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function echo_color() {
  local color="$1"
  local msg="$2"
  echo -e "${color}${msg}${NC}"
}

echo_color "$YELLOW" "[CLEANUP] Stopping all running containers..."
docker ps -q | xargs -r docker stop

echo_color "$YELLOW" "[CLEANUP] Pruning unused containers, networks, build cache, and volumes (keeping all images in use)..."
docker system prune -a --volumes -f

echo_color "$YELLOW" "[CLEANUP] Pruning Docker builder cache..."
docker builder prune -af

echo_color "$GREEN" "[CLEANUP] VPS Docker cleanup complete. All unused data removed, images in use retained." 