#!/bin/bash

# Script to build a specific service
# Usage: ./build_service.sh [webapp|fusionauth|tunnel|monitoring]

set -e  # Exit on error

# Check if a service name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 [webapp|fusionauth|tunnel|monitoring]"
  exit 1
fi

SERVICE="$1"
ADMIN_PORT=9001

echo "[STATUS] ==== $(date) Building $SERVICE service ===="

# Check if the admin daemon is running
if ! systemctl is-active --quiet cloudllm-daemon.service; then
  echo "[WARNING] Admin daemon not running. Starting it now..."
  systemctl start cloudllm-daemon.service
  sleep 3  # Give it time to start
fi

# Check admin daemon status
ADMIN_STATUS=$(curl -s http://localhost:$ADMIN_PORT/status || echo "Failed to connect")
if [[ "$ADMIN_STATUS" == *"Failed to connect"* ]]; then
  echo "[ERROR] Cannot connect to admin daemon at port $ADMIN_PORT"
  echo "[INFO] Checking daemon status with systemctl..."
  systemctl status cloudllm-daemon.service
  exit 1
fi

# Trigger deployment of the specific service
echo "[STATUS] Triggering deployment of $SERVICE service..."
RESULT=$(curl -s -X POST http://localhost:$ADMIN_PORT/deploy/$SERVICE)

# Check result
if [[ "$RESULT" == *"\"status\":\"Failed\""* ]]; then
  echo "[ERROR] Failed to deploy $SERVICE service"
  echo "[DEBUG] Deployment result: $RESULT"
  echo "[INFO] Check logs for more details: docker logs ${SERVICE}-service"
  exit 1
elif [[ "$RESULT" == *"Route not found"* ]]; then
  echo "[ERROR] Invalid service name: $SERVICE"
  echo "[INFO] Available services: webapp, fusionauth, tunnel, monitoring"
  exit 1
else
  echo "[SUCCESS] $SERVICE service deployment triggered"
  echo "[INFO] Deployment result: $RESULT"
fi

echo "[STATUS] ==== $(date) $SERVICE service build triggered ===="
echo "[TIP] To see live logs: docker logs -f ${SERVICE}-service" 