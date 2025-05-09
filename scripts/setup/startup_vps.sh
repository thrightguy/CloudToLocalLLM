#!/bin/bash
# CloudToLocalLLM VPS Startup Script
#
# This script rebuilds and restarts the admin daemon,
# and triggers a full stack deployment via the daemon API.
#
# Usage: Run as root (su - or sudo -i), then:
#   bash scripts/setup/startup_vps.sh
# Logs are written to /opt/cloudtolocalllm/startup.log

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Use 'su -' or 'sudo -i' to become root, then run the script." >&2
  exit 1
fi

LOGFILE="/opt/cloudtolocalllm/startup.log"
exec > >(tee -a "$LOGFILE") 2>&1

log_status() {
  echo -e "\033[1;34m[STATUS]\033[0m $1"
}
log_error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

trap 'log_error "Script interrupted."' ERR SIGINT SIGTERM

# MAIN EXECUTION
# ==============================================================================
log_status "==== $(date) Starting CloudToLocalLLM stack ===="

log_status "[1/3] Stopping admin daemon..."
if ! systemctl stop cloudllm-daemon; then
  log_error "Failed to stop admin daemon (may not be running)";
fi

log_status "[2/3] Rebuilding admin daemon..."
cd /opt/cloudtolocalllm/admin_control_daemon || { log_error "Failed to cd to admin_control_daemon"; exit 1; }
if ! dart compile exe bin/server.dart -o daemon; then
  log_error "Failed to compile admin daemon"; exit 1;
fi

cd /opt/cloudtolocalllm || { log_error "Failed to cd to /opt/cloudtolocalllm after build"; exit 1; }

log_status "[3/3] Starting admin daemon..."
if ! systemctl start cloudllm-daemon; then
  log_error "Failed to start admin daemon"; exit 1;
fi
systemctl status cloudllm-daemon --no-pager || log_error "Failed to get admin daemon status"

sleep 3
log_status "Triggering full stack deployment via daemon API..."
if ! curl -X POST http://localhost:9001/admin/deploy/all; then
  log_error "Failed to trigger full stack deployment via daemon API";
fi

log_status "==== $(date) Startup complete ====" 