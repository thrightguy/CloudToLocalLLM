#!/bin/bash
set -e

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
ADMIN_DAEMON_PORT="9001" # Default port for your admin daemon
NGINX_WEB_COMPOSE_FILE="config/docker/docker-compose.web.yml" # Relative to PROJECT_DIR
DOMAIN="cloudtolocalllm.online" # Added for verification instructions

# Output colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- VPS SSL Setup & Initial Cert Issuance Script ---${NC}"
echo -e "${YELLOW}NOTE: This script avoids using 'sudo'. Ensure the user running this script has necessary permissions for git, docker, docker-compose, file operations in $PROJECT_DIR, and that Certbot is pre-installed if needed.${NC}"

# 1. Navigate to Project Directory
echo -e "${YELLOW}Navigating to project directory: $PROJECT_DIR...${NC}"
cd "$PROJECT_DIR" || { echo -e "${RED}Failed to navigate to $PROJECT_DIR. Please ensure it exists and the script is run from a location with access.${NC}"; exit 1; }
echo -e "${GREEN}Successfully changed to $PROJECT_DIR.${NC}"

# 2. Pull Latest Changes
echo -e "${YELLOW}Pulling latest changes from Git (origin master)...${NC}"
if git pull origin master; then
    echo -e "${GREEN}Git pull successful.${NC}"
else
    echo -e "${RED}Git pull failed. Please check your Git configuration and connectivity.${NC}"
    # Decide if to exit or continue. For now, continue as other steps might still be useful.
fi

# 3. Make SSL Management Script Executable
SSL_SCRIPT_PATH="scripts/ssl/manage_ssl.sh"
echo -e "${YELLOW}Making SSL management script ($SSL_SCRIPT_PATH) executable...${NC}"
if [ -f "$SSL_SCRIPT_PATH" ]; then
    chmod +x "$SSL_SCRIPT_PATH"
    echo -e "${GREEN}$SSL_SCRIPT_PATH is now executable.${NC}"
else
    echo -e "${RED}Error: $SSL_SCRIPT_PATH not found. Git pull might have failed or the script is not at the expected location.${NC}"
    exit 1
fi

# 4. Check for Certbot
echo -e "${YELLOW}Checking if Certbot is installed...${NC}"
if ! command -v certbot &> /dev/null; then
    echo -e "${RED}Certbot could not be found.${NC}"
    echo -e "${YELLOW}Certbot needs to be installed manually by a user with appropriate privileges (e.g., sudo).${NC}"
    echo -e "${YELLOW}Example for Debian/Ubuntu: sudo apt update && sudo apt install certbot python3-certbot-nginx${NC}"
    echo -e "${YELLOW}After ensuring Certbot is installed, please re-run this script.${NC}"
    exit 1
else
    echo -e "${GREEN}Certbot is installed.${NC}"
fi

# 5. Recompile Admin Daemon
ADMIN_DAEMON_DIR="admin_control_daemon"
ADMIN_DAEMON_SOURCE="bin/server.dart"
ADMIN_DAEMON_OUTPUT="bin/admin_daemon"
echo -e "${YELLOW}Recompiling Admin Daemon...${NC}"
if [ -d "$ADMIN_DAEMON_DIR" ] && [ -f "$ADMIN_DAEMON_DIR/$ADMIN_DAEMON_SOURCE" ]; then
    cd "$ADMIN_DAEMON_DIR"
    if dart compile exe "$ADMIN_DAEMON_SOURCE" -o "$ADMIN_DAEMON_OUTPUT"; then
        echo -e "${GREEN}Admin Daemon compiled successfully ($ADMIN_DAEMON_OUTPUT).${NC}"
    else
        echo -e "${RED}Admin Daemon compilation failed. Please check Dart SDK and compilation errors.${NC}"
        cd "$PROJECT_DIR" # Go back to project root
        exit 1
    fi
    cd "$PROJECT_DIR" # Go back to project root
else
    echo -e "${RED}Admin Daemon directory or source file not found. Cannot compile.${NC}"
    exit 1
fi

# 6. Instruct to Restart Admin Daemon
echo -e ""
echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
echo -e "${YELLOW}IMPORTANT: You need to restart the Admin Control Daemon MANUALLY.${NC}"
echo -e "${YELLOW}This script cannot do it safely as it may require 'sudo' and knowledge of your service setup (e.g., systemd service name).${NC}"
echo -e "${YELLOW}Example for systemd: sudo systemctl restart your_admin_daemon_service_name${NC}"
echo -e "${YELLOW}Please restart the daemon in another terminal before continuing with this script, or this script will try to contact it and may fail.${NC}"
echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
read -p "Press [Enter] to continue AFTER you have restarted the admin daemon..."

# 7. Ensure Nginx (webapp) is Running
echo -e "${YELLOW}Attempting to start/restart the Nginx (webapp) service...${NC}"
echo -e "${YELLOW}This is needed for Certbot's HTTP-01 challenge.${NC}"
# Ensure the user running this script is part of the 'docker' group or has permissions for docker-compose
if docker-compose -f "$NGINX_WEB_COMPOSE_FILE" up -d --build; then
    echo -e "${GREEN}Nginx (webapp) service started/updated successfully.${NC}"
else
    echo -e "${RED}Failed to start/update Nginx (webapp) service using docker-compose.${NC}"
    echo -e "${YELLOW}Please check Docker and docker-compose setup. Ensure the current user has Docker permissions (e.g., is in the 'docker' group).${NC}"
    # Continue, as Certbot might still work if Nginx is running correctly despite errors here.
fi

# 8. Trigger Initial SSL Certificate Issuance/Renewal
SSL_ENDPOINT="http://localhost:$ADMIN_DAEMON_PORT/admin/ssl/issue-renew"
echo -e "${YELLOW}Attempting to trigger SSL certificate issuance/renewal via Admin Daemon endpoint: $SSL_ENDPOINT...${NC}"
echo -e "${YELLOW}This may take a few moments.${NC}"

if curl -X POST "$SSL_ENDPOINT"; then
    echo -e "${GREEN}Successfully called the SSL issuance/renewal endpoint.${NC}"
    echo -e "${YELLOW}Review the output from the endpoint above. It should indicate if Certbot was successful and if Nginx was reloaded.${NC}"
else
    echo -e "${RED}Failed to call the SSL issuance/renewal endpoint ($SSL_ENDPOINT).${NC}"
    echo -e "${YELLOW}Ensure the Admin Daemon is running, accessible, and was restarted with the latest code.${NC}"
    echo -e "${YELLOW}You might need to run 'scripts/ssl/manage_ssl.sh' manually if this continues to fail.${NC}"
fi

# 9. Final Instructions & Verification Steps
echo -e ""
echo -e "${GREEN}--- SSL Setup Script Finished ---${NC}"
echo -e "${YELLOW}Verification Steps:${NC}"
echo -e "  1. ${YELLOW}Check for SSL certificate files in:${NC} $PROJECT_DIR/config/docker/certbot/conf/live/$DOMAIN/"
echo -e "     (e.g., fullchain.pem, privkey.pem)"
echo -e "  2. ${YELLOW}Access your site via HTTPS:${NC} https://$DOMAIN"
echo -e "     Check if the browser shows a valid SSL certificate."
echo -e "  3. ${YELLOW}Check Nginx logs if issues persist:${NC} docker logs <your_nginx_container_name> (Get name from 'docker ps')"
echo -e ""
echo -e "${YELLOW}Next Step: Setup Automatic Renewal (Cron Job):${NC}"
echo -e "  For automatic renewals, set up a cron job on your VPS for the appropriate user."
echo -e "  The user whose crontab is used MUST have permissions to run 'manage_ssl.sh' successfully (including Certbot and Docker commands)."
echo -e "  1. Open user's crontab: ${GREEN}crontab -e${NC}"
echo -e "  2. Add this line (runs at 2:30 AM on the 1st of every month):"
echo -e "     ${GREEN}30 2 1 * * $PROJECT_DIR/scripts/ssl/manage_ssl.sh >> $PROJECT_DIR/logs/certbot/cron_renewal.log 2>&1${NC}"
echo -e "  Ensure $PROJECT_DIR/logs/certbot/ directory exists and is writable by the user running the cron job."

echo -e "${GREEN}Setup complete. Please perform verification and set up the cron job.${NC}" 