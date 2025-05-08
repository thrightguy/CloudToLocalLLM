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

echo "==== $(date) Starting CloudToLocalLLM stack ===="

cd /opt/cloudtolocalllm

echo "[1/4] Pulling latest code from GitHub..."
git pull

echo "[2/4] Stopping admin daemon..."
systemctl stop cloudllm-daemon || true

echo "[3/4] Rebuilding admin daemon..."
cd /opt/cloudtolocalllm/admin_control_daemon
dart compile exe bin/server.dart -o daemon

cd /opt/cloudtolocalllm

echo "[4/4] Starting admin daemon..."
systemctl start cloudllm-daemon
systemctl status cloudllm-daemon --no-pager

sleep 3
echo "Triggering full stack deployment via daemon API..."
curl -X POST http://localhost:9001/admin/deploy/all || true

echo "==== $(date) Startup complete ====" 