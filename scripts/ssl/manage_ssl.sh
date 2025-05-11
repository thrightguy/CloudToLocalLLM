#!/bin/bash
set -e

# --- IMPORTANT PERMISSIONS NOTE ---
# This script is intended to be run by a user or process (e.g., your admin_control_daemon)
# that has the following permissions:
#   1. Permission to execute 'certbot' (Certbot should be in PATH or called via absolute path).
#   2. Write permissions to the following directories (relative to PROJECT_DIR defined below):
#      - config/docker/certbot/conf (for Certbot configurations and certificates)
#      - config/docker/certbot/www (for ACME challenge files)
#      - logs/certbot (for Certbot logs)
#   3. Permissions to execute 'docker-compose' and 'docker exec' commands (e.g., user is in the 'docker' group).
# This script does NOT use 'sudo' internally.
# --- END PERMISSIONS NOTE ---

# Configuration
EMAIL="christopher.maltais@gmail.com"
DOMAIN="cloudtolocalllm.online"
PROJECT_DIR="/opt/cloudtolocalllm" # This should be the root of your project on the VPS

# Certbot paths - these align with docker-compose.web.yml volume mounts
CERT_PATH_BASE="$PROJECT_DIR/config/docker/certbot"
CERT_CONFIG_DIR="$CERT_PATH_BASE/conf" # Mounted to /etc/letsencrypt in container
WEBROOT_PATH="$CERT_PATH_BASE/www"    # Mounted to /var/www/certbot in container
CERTBOT_LOG_DIR="$PROJECT_DIR/logs/certbot"
COMPOSE_FILE_WEB="$PROJECT_DIR/config/docker/docker-compose.web.yml"
NGINX_SERVICE_NAME="webapp" # Service name in docker-compose.web.yml

# Output colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- SSL Certificate Management Script ---${NC}"

# Check if Certbot is installed
if ! command -v /usr/bin/certbot &> /dev/null; then
    echo -e "${RED}Certbot could not be found at /usr/bin/certbot. Please check installation.${NC}"
    exit 1
fi
echo -e "${GREEN}Certbot found at /usr/bin/certbot.${NC}"

# Create directories if they don't exist
echo -e "${YELLOW}Ensuring directories exist...${NC}"
mkdir -p "$CERT_CONFIG_DIR"
mkdir -p "$WEBROOT_PATH/.well-known/acme-challenge" # Certbot webroot needs .well-known/acme-challenge
mkdir -p "$CERTBOT_LOG_DIR"
# Ensure correct permissions if running as non-root and certbot needs to write here
# For simplicity, this script assumes it's run with sufficient permissions or certbot is configured to handle it.

echo -e "${YELLOW}Directories checked/created.${NC}"

echo -e "${YELLOW}Attempting to obtain/renew certificate for $DOMAIN...${NC}"
echo -e "${YELLOW}Webroot: $WEBROOT_PATH${NC}"
echo -e "${YELLOW}Config dir: $CERT_CONFIG_DIR${NC}"
echo -e "${YELLOW}Logs dir: $CERTBOT_LOG_DIR${NC}"

# Run Certbot
# --webroot: uses a webroot directory to place challenge files. Nginx must serve these.
# --agree-tos: Agrees to Let's Encrypt's Terms of Service.
# --non-interactive: Runs Certbot without user interaction.
# --keep-until-expiring: Tells Certbot to renew if the cert is nearing expiry.
#   For initial issuance, Certbot will obtain a new cert if one doesn't exist.
# --preferred-challenges http-01: Explicitly use HTTP-01 challenge.
/usr/bin/certbot certonly \
    --webroot \
    -w "$WEBROOT_PATH" \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --config-dir "$CERT_CONFIG_DIR" \
    --work-dir "$CERT_CONFIG_DIR/work" \
    --logs-dir "$CERTBOT_LOG_DIR" \
    --agree-tos \
    --non-interactive \
    --keep-until-expiring \
    --preferred-challenges http-01

CERTBOT_EXIT_CODE=$?

if [ $CERTBOT_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Certbot process completed successfully.${NC}"

    # Find the Nginx container ID using docker-compose
    echo -e "${YELLOW}Attempting to find Nginx container ($NGINX_SERVICE_NAME service)...${NC}"
    NGINX_CONTAINER_ID=$(docker-compose -f "$COMPOSE_FILE_WEB" ps -q "$NGINX_SERVICE_NAME" 2>/dev/null)

    if [ -z "$NGINX_CONTAINER_ID" ]; then
        echo -e "${RED}Could not find the Nginx container for service '$NGINX_SERVICE_NAME' using docker-compose.${NC}"
        echo -e "${YELLOW}You may need to reload Nginx manually if it's running.${NC}"
    else
        echo -e "${GREEN}Found Nginx container ID: $NGINX_CONTAINER_ID${NC}"
        echo -e "${YELLOW}Attempting to reload Nginx configuration...${NC}"
        docker exec "$NGINX_CONTAINER_ID" nginx -s reload
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Nginx reloaded successfully.${NC}"
        else
            echo -e "${RED}Failed to reload Nginx. Check container logs.${NC}"
        fi
    fi
else
    echo -e "${RED}Certbot process failed with exit code $CERTBOT_EXIT_CODE.${NC}"
    echo -e "${RED}Check logs in $CERTBOT_LOG_DIR for details.${NC}"
    exit 1
fi

echo -e "${GREEN}--- SSL Script Finished ---${NC}" 