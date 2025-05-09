#!/bin/bash
# CloudToLocalLLM VPS Startup Script
#
# This script pulls the latest code, rebuilds and restarts the admin daemon,
# and triggers a full stack deployment via the daemon API.
#
# Usage: Run as root (su - or sudo -i), then:
#   git pull
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

trap 'log_error "Script failed at line $LINENO. See $LOGFILE for details."' ERR

log_status "==== $(date) Starting CloudToLocalLLM stack ===="

cd /opt/cloudtolocalllm || { log_error "Failed to cd to /opt/cloudtolocalllm"; exit 1; }

log_status "[1/4] Pulling latest code from GitHub..."
# Stash local changes before pulling, then pop after
if ! git diff --quiet || ! git diff --cached --quiet; then
  log_status "Stashing local changes before git pull..."
  git stash --include-untracked
  STASHED=1
else
  STASHED=0
fi
if ! git pull; then
  log_error "git pull failed"; exit 1;
fi
if [[ $STASHED -eq 1 ]]; then
  log_status "Popping stashed changes after git pull..."
  git stash pop || log_status "No stashed changes to pop or merge conflicts occurred."
fi

log_status "[2/4] Stopping admin daemon..."
if ! systemctl stop cloudllm-daemon; then
  log_error "Failed to stop admin daemon (may not be running)";
fi

log_status "[3/4] Rebuilding admin daemon..."
cd /opt/cloudtolocalllm/admin_control_daemon || { log_error "Failed to cd to admin_control_daemon"; exit 1; }
if ! dart compile exe bin/server.dart -o daemon; then
  log_error "Failed to compile admin daemon"; exit 1;
fi

cd /opt/cloudtolocalllm || { log_error "Failed to cd to /opt/cloudtolocalllm after build"; exit 1; }

log_status "[4/4] Starting admin daemon..."
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