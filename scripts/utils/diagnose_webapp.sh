#!/bin/bash

# Diagnostic script for CloudToLocalLLM webapp container issues

echo "--- Webapp Diagnostic Script ---"
echo ""

PROJECT_DIR="/opt/cloudtolocalllm"
WEB_COMPOSE_FILE="config/docker/docker-compose.web.yml"
CERT_BASE_PATH="$PROJECT_DIR/config/docker/certbot/conf/live/cloudtolocalllm.online"
FULLCHAIN_PATH="$CERT_BASE_PATH/fullchain.pem"
PRIVKEY_PATH="$CERT_BASE_PATH/privkey.pem"
WEBAPP_CONTAINER_NAME_GUESS="cloudtolocalllm_webapp_1" # Adjust if your container name is different

echo "--- 1. Checking SSL Certificate Paths ---"
if [ -f "$FULLCHAIN_PATH" ]; then
    echo "Found: $FULLCHAIN_PATH"
else
    echo "NOT FOUND: $FULLCHAIN_PATH"
fi

if [ -f "$PRIVKEY_PATH" ]; then
    echo "Found: $PRIVKEY_PATH"
else
    echo "NOT FOUND: $PRIVKEY_PATH"
fi
echo ""

echo "--- 2. Listing All Docker Containers (including stopped) ---"
docker ps -a
echo ""

echo "--- 3. Attempting to get logs for '$WEBAPP_CONTAINER_NAME_GUESS' (if it exists) ---"
# First, try to get the specific container ID if it's named based on the directory and service
CONTAINER_ID=$(docker ps -a --filter "name=${PROJECT_DIR##*/}_webapp_1" -q)

if [ -z "$CONTAINER_ID" ]; then
    # Fallback to common compose naming pattern if service is 'webapp' in compose file
    # (Docker compose often names containers <projectname>_<servicename>_1)
    # Assuming project directory name is used as projectname by compose
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    WEBAPP_CONTAINER_NAME_GUESS="${PROJECT_NAME}_webapp_1" # e.g., cloudtolocalllm_webapp_1
    
    # Try again with this guess
    CONTAINER_ID=$(docker ps -a --filter "name=$WEBAPP_CONTAINER_NAME_GUESS" -q)
fi


if [ ! -z "$CONTAINER_ID" ]; then
    echo "Found container ID: $CONTAINER_ID (for name guess: $WEBAPP_CONTAINER_NAME_GUESS)"
    echo "Displaying logs for container ID $CONTAINER_ID:"
    docker logs "$CONTAINER_ID"
else
    echo "Could not find a stopped container matching common names like '$WEBAPP_CONTAINER_NAME_GUESS'."
    echo "Please check the 'docker ps -a' output above for the correct container name/ID and run 'docker logs <name_or_id>' manually."
fi
echo ""

echo "--- 4. Attempting to Start Webapp in Foreground (Press Ctrl+C to stop) ---"
echo "This will show live logs. If it starts, great! If it errors, note the error."
echo "Navigating to $PROJECT_DIR"
cd "$PROJECT_DIR" || { echo "Failed to cd to $PROJECT_DIR. Aborting foreground test."; exit 1; }
echo "Running: docker-compose -f $WEB_COMPOSE_FILE up --build"
echo "If the command fails immediately, try it without '--build': docker-compose -f $WEB_COMPOSE_FILE up"
echo "--------------------------------------------------------------------------"
docker-compose -f "$WEB_COMPOSE_FILE" up --build

echo ""
echo "--- End of Diagnostic Script ---" 