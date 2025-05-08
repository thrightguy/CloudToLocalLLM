#!/bin/bash
set -e

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
ADMIN_DAEMON_PORT="9001"
NGINX_WEB_COMPOSE_FILE="config/docker/docker-compose.web.yml" # Relative to PROJECT_DIR
DOMAIN="cloudtolocalllm.online"
APP_USER="cloudllm" # The non-root user that will run the application

# Output colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- VPS SSL Setup & Initial Cert Issuance Script (v2) ---${NC}"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}This script is designed to be run as root to correctly set up initial certificates and permissions for the $APP_USER user.${NC}"
  echo -e "${RED}Please run with root privileges (e.g., sudo ./scripts/vps_setup/setup_vps_ssl.sh).${NC}"
  exit 1
fi
echo -e "${GREEN}Running as root. Proceeding with setup...${NC}"

# 1. Navigate to Project Directory
echo -e "${YELLOW}Navigating to project directory: $PROJECT_DIR...${NC}"
cd "$PROJECT_DIR" || { echo -e "${RED}Failed to navigate to $PROJECT_DIR.${NC}"; exit 1; }
echo -e "${GREEN}Successfully changed to $PROJECT_DIR.${NC}"

# 2. Stop any existing Admin Daemon instance
echo -e "${YELLOW}Attempting to stop any running Admin Daemon instances...${NC}"
pkill -f admin_daemon || echo -e "${YELLOW}No admin_daemon process found to stop, or failed to stop (which is okay if not running).${NC}"
sleep 2 # Give a moment for the process to terminate

# 3. Pull Latest Changes
echo -e "${YELLOW}Pulling latest changes from Git (origin master)...${NC}"
# Ensure safe directory for root if not already set
git config --global --add safe.directory "$PROJECT_DIR" || echo -e "${YELLOW}Failed to set safe.directory, or already set. Continuing...${NC}"
if git pull origin master; then
    echo -e "${GREEN}Git pull successful.${NC}"
else
    echo -e "${RED}Git pull failed. Please check Git configuration/connectivity and repository ownership/permissions.${NC}"
    exit 1
fi

# 4. Make SSL Management Script Executable
SSL_SCRIPT_PATH="scripts/ssl/manage_ssl.sh"
echo -e "${YELLOW}Making SSL management script ($SSL_SCRIPT_PATH) executable...${NC}"
chmod +x "$SSL_SCRIPT_PATH"
echo -e "${GREEN}$SSL_SCRIPT_PATH is now executable.${NC}"

# 5. Check for Certbot (and install if missing - root can do this)
echo -e "${YELLOW}Checking if Certbot is installed...${NC}"
if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Certbot not found. Attempting to install...${NC}"
    apt update && apt install certbot python3-certbot-nginx -y
    if ! command -v certbot &> /dev/null; then
        echo -e "${RED}Certbot installation failed. Please install it manually and re-run.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Certbot installed successfully.${NC}"
else
    echo -e "${GREEN}Certbot is installed.${NC}"
fi

# 6. Recompile Admin Daemon (as root, will be chowned later)
ADMIN_DAEMON_DIR="admin_control_daemon"
ADMIN_DAEMON_SOURCE="bin/server.dart"
ADMIN_DAEMON_EXECUTABLE="$ADMIN_DAEMON_DIR/bin/admin_daemon"
echo -e "${YELLOW}Recompiling Admin Daemon (output: $ADMIN_DAEMON_EXECUTABLE)...${NC}"
cd "$ADMIN_DAEMON_DIR"
dart compile exe "$ADMIN_DAEMON_SOURCE" -o "bin/admin_daemon"
COMPILE_EXIT_CODE=$?
cd "$PROJECT_DIR" # Go back to project root
if [ $COMPILE_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}Admin Daemon compilation failed. Please check Dart SDK and compilation errors.${NC}"
    exit 1
fi
echo -e "${GREEN}Admin Daemon compiled successfully.${NC}"

# 7. Ensure Nginx (webapp) is Running for Challenge
echo -e "${YELLOW}Attempting to start/restart the Nginx (webapp) service via docker-compose...${NC}"
echo -e "${YELLOW}This is needed for Certbot's HTTP-01 challenge.${NC}"
# Prune docker system to avoid potential 'ContainerConfig' errors
echo -e "${YELLOW}Running docker system prune to prevent potential compose errors...${NC}"
docker system prune -af # -a for all unused, -f for no prompt
if docker-compose -f "$NGINX_WEB_COMPOSE_FILE" up -d --build; then
    echo -e "${GREEN}Nginx (webapp) service started/updated successfully.${NC}"
else
    echo -e "${RED}Failed to start/update Nginx (webapp) service. Certbot might fail if Nginx isn't serving HTTP correctly.${NC}"
    # Not exiting, as certbot might still work if HTTP is somehow available
fi

# 8. Start Temporary Admin Daemon as root to get SSL certs
echo -e "${YELLOW}Starting temporary Admin Daemon as root to obtain SSL certificates...${NC}"
"$PROJECT_DIR/$ADMIN_DAEMON_EXECUTABLE" &
DAEMON_PID=$!
echo -e "${GREEN}Temporary Admin Daemon started with PID $DAEMON_PID. Waiting a few seconds for it to initialize...${NC}"
sleep 5 # Wait for daemon to start

# 9. Trigger SSL Certificate Issuance/Renewal via the temporary root daemon
SSL_ENDPOINT="http://localhost:$ADMIN_DAEMON_PORT/admin/ssl/issue-renew"
echo -e "${YELLOW}Attempting to trigger SSL certificate issuance/renewal via temporary root daemon: $SSL_ENDPOINT...${NC}"

CURL_OUTPUT_FILE=$(mktemp)
CURL_STATUS_FILE=$(mktemp)
# Write HTTP status code to a separate file, and body to another.
if curl -X POST "$SSL_ENDPOINT" --output "$CURL_OUTPUT_FILE" --silent --write-out "%{http_code}" > "$CURL_STATUS_FILE"; then
    HTTP_CODE=$(cat "$CURL_STATUS_FILE")
    RESPONSE_BODY=$(cat "$CURL_OUTPUT_FILE")
    rm "$CURL_OUTPUT_FILE" "$CURL_STATUS_FILE"

    echo -e "${YELLOW}Daemon Response Body:${NC}
$RESPONSE_BODY"
    # Check if RESPONSE_BODY contains the success marker, as HTTP_CODE might be 200 even for app-level errors if JSON is returned
    if echo "$RESPONSE_BODY" | grep -q '"status":"Success"'; then # Grep directly on response
        echo -e "${GREEN}SSL issuance/renewal endpoint reported success (HTTP $HTTP_CODE).${NC}"
    else
        echo -e "${RED}SSL issuance/renewal endpoint reported failure or non-success status (HTTP $HTTP_CODE). Check daemon logs and Certbot logs within $PROJECT_DIR/logs/certbot/.${NC}"
        # Even if it failed, proceed to stop daemon and set permissions, then user can debug.
    fi
else
    # Curl command itself failed (e.g., connection refused to daemon)
    HTTP_CODE="N/A (curl command failed)"
    RESPONSE_BODY="$(cat "$CURL_OUTPUT_FILE")"
    rm "$CURL_OUTPUT_FILE" "$CURL_STATUS_FILE"
    echo -e "${RED}Failed to call the SSL issuance/renewal endpoint ($SSL_ENDPOINT). HTTP Code: $HTTP_CODE. Ensure temporary daemon started correctly.${NC}"
    echo -e "${YELLOW}Partial output (if any):${NC}
$RESPONSE_BODY"
fi

# 10. Stop Temporary Admin Daemon
echo -e "${YELLOW}Stopping temporary Admin Daemon (PID $DAEMON_PID)...${NC}"
kill "$DAEMON_PID" || echo -e "${YELLOW}Failed to kill temporary daemon PID $DAEMON_PID, it might have already exited or failed to start.${NC}"
wait "$DAEMON_PID" 2>/dev/null # Wait for it to actually stop, suppress errors if already gone
echo -e "${GREEN}Temporary Admin Daemon stopped.${NC}"

# 11. Set Correct Ownership and Permissions for APP_USER
echo -e "${YELLOW}Setting ownership of Certbot dirs, logs, and admin daemon executable to $APP_USER...${NC}"
# Ensure $APP_USER user exists (informative, actual creation should be admin's task)
if ! id "$APP_USER" &>/dev/null; then
    echo -e "${YELLOW}Warning: User $APP_USER does not exist. Please create it. Skipping chown for this user.${NC}"
else
    echo -e "${YELLOW}Ensuring certbot and log directories exist and are owned by $APP_USER...${NC}"
    mkdir -p "$PROJECT_DIR/config/docker/certbot/conf"
    mkdir -p "$PROJECT_DIR/config/docker/certbot/www"
    mkdir -p "$PROJECT_DIR/logs/certbot"

    chown -R "$APP_USER:$APP_USER" "$PROJECT_DIR/config/docker/certbot"
    chown -R "$APP_USER:$APP_USER" "$PROJECT_DIR/logs/certbot"
    chown "$APP_USER:$APP_USER" "$PROJECT_DIR/$ADMIN_DAEMON_EXECUTABLE"
    chmod u+x "$PROJECT_DIR/$ADMIN_DAEMON_EXECUTABLE" # Ensure app_user can execute
    echo -e "${GREEN}Ownership set for $APP_USER.${NC}"
fi

# 12. Final Instructions & Verification Steps
echo -e ""
echo -e "${GREEN}--- SSL Setup Script Finished ---${NC}"
echo -e "${YELLOW}Verification Steps:${NC}"
echo -e "  1. ${YELLOW}Check for SSL certificate files in:${NC} $PROJECT_DIR/config/docker/certbot/conf/live/$DOMAIN/"
echo -e "  2. ${YELLOW}Access your site via HTTPS:${NC} https://$DOMAIN"
echo -e "     (You may need to deploy Nginx again: curl -X POST http://localhost:$ADMIN_DAEMON_PORT/admin/deploy/web - if daemon is running as $APP_USER)"
echo -e "  3. ${YELLOW}Check Nginx logs:${NC} docker logs <your_nginx_container_name> (Get name from 'docker ps')"
echo -e ""
echo -e "${YELLOW}IMPORTANT NEXT STEPS:${NC}"
echo -e "  1. ${YELLOW}Start the Admin Control Daemon AS THE '$APP_USER' USER.${NC}"
echo -e "     Example: su - $APP_USER -c "cd $PROJECT_DIR/$ADMIN_DAEMON_DIR && ./bin/admin_daemon &""
echo -e "     Or configure your systemd service to run as User=$APP_USER and Group=$APP_USER, then: systemctl restart your_admin_daemon.service"
echo -e "  2. ${YELLOW}Once the daemon is running as $APP_USER, ensure Nginx is deployed:${NC}"
echo -e "     (Run as $APP_USER or call from a system that can reach it): curl -X POST http://localhost:$ADMIN_DAEMON_PORT/admin/deploy/web"
echo -e "  3. ${YELLOW}Setup Automatic Renewal Cron Job (as $APP_USER):${NC}"
echo -e "     Log in or 'su - $APP_USER', then run 'crontab -e' and add:"
echo -e "     ${GREEN}30 2 1 * * $PROJECT_DIR/scripts/ssl/manage_ssl.sh >> $PROJECT_DIR/logs/certbot/cron_renewal.log 2>&1${NC}"
echo -e ""
echo -e "${GREEN}Setup complete. Please follow the important next steps to run the application as $APP_USER.${NC}" 