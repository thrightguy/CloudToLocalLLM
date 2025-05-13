#!/bin/bash
# Unified CloudToLocalLLM VPS Management Script
# Usage: ./scripts/setup/main_vps.sh [deploy|ssl-dns|ssl-webroot|monitor|fix-docker|clean|help]
#
# NOTE: This script must be run as root (sudo or su -).

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo -e "\033[0;31m[ERROR] This script must be run as root. Please run with sudo or as root.\033[0m"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
  echo -e "${YELLOW}CloudToLocalLLM VPS Management${NC}"
  echo -e "Usage: $0 [option]"
  echo -e "  ${GREEN}deploy${NC}      - Build and deploy Docker stack (with prompt for full flush)"
  echo -e "  ${GREEN}ssl-dns${NC}     - Run DNS-based SSL certbot (interactive, wildcard)"
  echo -e "  ${GREEN}ssl-webroot${NC} - Run webroot-based SSL certbot (automated, for Nginx)"
  echo -e "  ${GREEN}monitor${NC}     - Setup Netdata monitoring"
  echo -e "  ${GREEN}fix-docker${NC}  - Run Docker/Flutter build fixes"
  echo -e "  ${GREEN}clean${NC}       - Aggressively prune Docker system"
  echo -e "  ${GREEN}help${NC}        - Show this help message"
}

case "${1:-}" in
  deploy)
    bash "$SCRIPT_DIR/docker_startup_vps.sh"
    ;;
  ssl-dns)
    # bash "$SCRIPT_DIR/../ssl/obtain_initial_certs.sh"
    ;;
  ssl-webroot)
    bash "$SCRIPT_DIR/../ssl/manage_ssl.sh"
    ;;
  monitor)
    bash "$SCRIPT_DIR/setup_monitoring.sh"
    ;;
  fix-docker)
    bash "$SCRIPT_DIR/fix_docker_build.sh"
    ;;
  clean)
    echo -e "${YELLOW}Pruning Docker system (all unused containers, images, volumes, build cache)...${NC}"
    docker system prune -a --volumes
    ;;
  help|--help|-h|"")
    show_help
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    show_help
    exit 1
    ;;
esac 