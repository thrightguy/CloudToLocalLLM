#!/bin/bash

# Script to build a specific service
# Usage: ./build_service.sh [web|fusionauth|all]

set -e  # Exit on error

# Check if a service name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 [web|fusionauth|all]"
  exit 1
fi

SERVICE="$1"
ADMIN_PORT=9001

# Map service name to API endpoint
case "$SERVICE" in
  "web")
    API_ENDPOINT="/admin/deploy/web"
    ;;
  "fusionauth")
    API_ENDPOINT="/admin/deploy/fusionauth"
    ;;
  "all")
    API_ENDPOINT="/admin/deploy/all"
    ;;
  *)
    echo "[ERROR] Invalid service name: $SERVICE"
    echo "[INFO] Available services: web, fusionauth, all"
    exit 1
    ;;
esac

echo "[STATUS] ==== $(date) Building $SERVICE service ===="

# Check if the admin daemon is running
if ! systemctl is-active --quiet cloudllm-daemon.service; then
  echo "[WARNING] Admin daemon not running. Starting it now..."
  systemctl start cloudllm-daemon.service
  sleep 3  # Give it time to start
fi

# Check admin daemon status by trying a simple health check
ADMIN_STATUS=$(curl -s http://localhost:$ADMIN_PORT/admin/health || echo "Failed to connect")
if [[ "$ADMIN_STATUS" == *"Failed to connect"* ]]; then
  echo "[ERROR] Cannot connect to admin daemon at port $ADMIN_PORT"
  echo "[INFO] Checking daemon status with systemctl..."
  systemctl status cloudllm-daemon.service
  exit 1
fi

# Trigger deployment of the specific service
echo "[STATUS] Triggering deployment of $SERVICE service..."
RESULT=$(curl -s -X POST http://localhost:$ADMIN_PORT$API_ENDPOINT)

# Check result
if [[ "$RESULT" == *"\"status\":\"Failed\""* ]]; then
  echo "[ERROR] Failed to deploy $SERVICE service"
  echo "[DEBUG] Deployment result: $RESULT"
  echo "[INFO] Check logs for more details: docker logs ${SERVICE}-service"
  exit 1
elif [[ "$RESULT" == *"Not Found"* || "$RESULT" == *"Route not found"* ]]; then
  echo "[ERROR] API route not found: $API_ENDPOINT"
  echo "[INFO] Check if admin_daemon server.dart is up to date"
  exit 1
else
  echo "[SUCCESS] $SERVICE service deployment triggered"
  echo "[INFO] Deployment result: $RESULT"
fi

echo "[STATUS] ==== $(date) $SERVICE service build triggered ===="
echo "[TIP] To see live logs: docker logs -f ${SERVICE}-service" 