#!/bin/bash

# CloudToLocalLLM Diagnostic Fix Deployment Script
# This script deploys the enhanced diagnostic version to help identify black screen issues

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
APP_DIR="/opt/CloudToLocalLLM"
CONTAINER_NAME="cloudtolocalllm-webapp"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CloudToLocalLLM Diagnostic Fix Deployment${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to run commands on VPS
run_on_vps() {
    ssh ${VPS_USER}@${VPS_HOST} "$1"
}

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}Step 1: Connecting to VPS and pulling latest changes...${NC}"
run_on_vps "cd ${APP_DIR} && git pull origin master"
check_success "Git pull completed"

echo -e "${YELLOW}Step 2: Verifying latest commit...${NC}"
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(run_on_vps "cd ${APP_DIR} && git rev-parse HEAD")

echo "Local commit:  ${LOCAL_COMMIT}"
echo "Remote commit: ${REMOTE_COMMIT}"

if [ "${LOCAL_COMMIT}" = "${REMOTE_COMMIT}" ]; then
    echo -e "${GREEN}✓ Commits match - deployment is up to date${NC}"
else
    echo -e "${RED}✗ Commit mismatch - deployment may have failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 3: Building Flutter web application...${NC}"
run_on_vps "cd ${APP_DIR} && flutter build web --release"
check_success "Flutter build completed"

echo -e "${YELLOW}Step 4: Stopping existing container...${NC}"
run_on_vps "docker stop ${CONTAINER_NAME} || true"
run_on_vps "docker rm ${CONTAINER_NAME} || true"
check_success "Container stopped and removed"

echo -e "${YELLOW}Step 5: Starting updated container...${NC}"
run_on_vps "cd ${APP_DIR} && docker-compose up -d --build"
check_success "Container started"

echo -e "${YELLOW}Step 6: Waiting for container to be ready...${NC}"
sleep 10

echo -e "${YELLOW}Step 7: Checking container health...${NC}"
CONTAINER_STATUS=$(run_on_vps "docker ps --filter name=${CONTAINER_NAME} --format '{{.Status}}'")
echo "Container status: ${CONTAINER_STATUS}"

if [[ "${CONTAINER_STATUS}" == *"Up"* ]]; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container is not running properly${NC}"
    echo -e "${YELLOW}Container logs:${NC}"
    run_on_vps "docker logs ${CONTAINER_NAME} --tail 20"
    exit 1
fi

echo -e "${YELLOW}Step 8: Testing web application accessibility...${NC}"
HTTP_STATUS=$(run_on_vps "curl -s -o /dev/null -w '%{http_code}' http://localhost:80/ || echo 'FAILED'")
echo "HTTP Status: ${HTTP_STATUS}"

if [ "${HTTP_STATUS}" = "200" ]; then
    echo -e "${GREEN}✓ Web application is accessible${NC}"
else
    echo -e "${RED}✗ Web application is not accessible (HTTP ${HTTP_STATUS})${NC}"
    echo -e "${YELLOW}Nginx logs:${NC}"
    run_on_vps "docker logs ${CONTAINER_NAME} --tail 10"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps for testing:${NC}"
echo "1. Open https://app.cloudtolocalllm.online in your browser"
echo "2. Open browser developer tools (F12) and check the Console tab"
echo "3. Look for diagnostic messages starting with 'CloudToLocalLLM:'"
echo "4. If the app doesn't load within 10 seconds, you'll see detailed diagnostic information"
echo "5. Check for any Auth0 initialization errors in the console"
echo ""
echo -e "${YELLOW}Key diagnostic features added:${NC}"
echo "• Enhanced error tracking and logging"
echo "• Fixed Auth0 redirect URI mismatch"
echo "• Diagnostic timeout screen with error details"
echo "• Better Auth0 configuration logging"
echo ""
echo -e "${BLUE}The diagnostic information will help identify the root cause of the black screen issue.${NC}"
