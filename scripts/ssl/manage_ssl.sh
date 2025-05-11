#!/bin/bash
# This script manages the issuance and renewal of SSL certificates using Certbot
# with the webroot authenticator, and reloads Nginx upon successful certificate management.
# It is designed to be run within an environment (e.g., a Docker container like admin_control_daemon)
# that has Certbot, Docker, and Docker Compose installed and configured.

# --- IMPORTANT PERMISSIONS NOTE ---
# This script is intended to be run by a user or process that has:
#   1. Permission to execute 'certbot'.
#   2. Write permissions to the host directories mounted for Certbot configuration, webroot, and logs.
#   3. Permissions to execute 'docker-compose' and 'docker exec' commands (e.g., user is in 'docker' group or has root privileges).
#      This script uses 'sudo' for docker-compose commands to ensure permissions if not run as root,
#      assuming sudo access is configured for the executing user if necessary.
# --- END PERMISSIONS NOTE ---

set -euo pipefail # Exit on error, unset variable, or pipe failure

# --- Configuration ---
# These should match your environment and domain settings.
EMAIL="christopher.maltais@gmail.com" # Email for Let's Encrypt account
DOMAIN_NAME="cloudtolocalllm.online"    # The domain to issue the certificate for
PROJECT_DIR="/opt/cloudtolocalllm"    # Absolute path to your project's root on the host machine

# Certbot and Nginx related paths (relative to PROJECT_DIR on the host)
CERTBOT_CONFIG_SUBDIR="certbot/conf" # Align with docker-compose.yml volume for /etc/letsencrypt
CERTBOT_WEBROOT_SUBDIR="certbot/www" # Align with docker-compose.yml volume
CERTBOT_LOGS_SUBDIR="logs/certbot"
NGINX_COMPOSE_FILE_SUBDIR="config/docker/docker-compose.web.yml"
NGINX_SERVICE_NAME_IN_WEB_COMPOSE="webapp" # Service name in docker-compose.web.yml
EXPECTED_NGINX_CONTAINER_NAME="cloudtolocalllm-nginx" # Primary Nginx container name from main compose

# Construct full paths
CERT_CONFIG_DIR="$PROJECT_DIR/$CERTBOT_CONFIG_SUBDIR"
WEBROOT_PATH="$PROJECT_DIR/$CERTBOT_WEBROOT_SUBDIR"
CERTBOT_LOG_DIR="$PROJECT_DIR/$CERTBOT_LOGS_SUBDIR"
COMPOSE_FILE_WEB="$PROJECT_DIR/$NGINX_COMPOSE_FILE_SUBDIR"

# Output Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Helper Functions ---

echo_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

ensure_dependencies() {
    local missing_deps=0
    for dep in "$@"; do
        if [[ "$dep" == "docker compose" ]]; then # Special check for docker compose
            if ! docker compose version &>/dev/null; then
                echo_color "$RED" "Error: Dependency 'docker compose' not found or not working."
                missing_deps=$((missing_deps + 1))
            else
                echo_color "$GREEN" "Dependency 'docker compose' found."
            fi
        elif ! command -v "$dep" &>/dev/null; then
            echo_color "$RED" "Error: Dependency '$dep' not found."
            missing_deps=$((missing_deps + 1))
        else
            echo_color "$GREEN" "Dependency '$dep' found."
        fi
    done
    if [ "$missing_deps" -gt 0 ]; then
        echo_color "$RED" "Please install missing dependencies and try again."
        exit 1
    fi
}

ensure_certbot_dirs() {
    echo_color "$YELLOW" "Ensuring Certbot directories exist on host (mounted into containers):"
    echo_color "$YELLOW" "  Config dir: $CERT_CONFIG_DIR"
    echo_color "$YELLOW" "  Webroot dir: $WEBROOT_PATH/.well-known/acme-challenge"
    echo_color "$YELLOW" "  Logs dir: $CERTBOT_LOG_DIR"

    # Create directories with sudo to ensure they are owned by root,
    # which is typical for system-level configurations.
    # Docker volumes will handle permissions for containers.
    sudo mkdir -p "$CERT_CONFIG_DIR"
    sudo mkdir -p "$WEBROOT_PATH/.well-known/acme-challenge" # Certbot needs to write here via webroot plugin
    sudo mkdir -p "$CERTBOT_LOG_DIR"
    
    # Set appropriate permissions if needed, though Docker volume mounts often handle this.
    # For webroot, Nginx (inside container) needs to read, Certbot (this script) needs to write.
    # Host permissions for $WEBROOT_PATH should allow certbot (as root or via sudo) to write.
    # Nginx container user (usually nginx) will need read access via the volume mount.
    sudo chmod -R 755 "$WEBROOT_PATH"

    echo_color "$BLUE" "DEBUG: Listing contents of host webroot after mkdir/chmod: $WEBROOT_PATH"
    sudo ls -la "$WEBROOT_PATH"
    echo_color "$BLUE" "DEBUG: Listing contents of host ACME challenge dir after mkdir/chmod: $WEBROOT_PATH/.well-known/acme-challenge"
    sudo ls -la "$WEBROOT_PATH/.well-known/acme-challenge"

    echo_color "$GREEN" "Certbot directories checked/created."
}

ensure_nginx_running() {
    echo_color "$BLUE" "Checking if primary Nginx container ('$EXPECTED_NGINX_CONTAINER_NAME') is running..."
    local primary_nginx_container_id
    primary_nginx_container_id=$(docker ps -q --filter "name=^/${EXPECTED_NGINX_CONTAINER_NAME}$")

    if [ -n "$primary_nginx_container_id" ]; then
        # Check if it's healthy (simple check: is it running? more complex: docker inspect health status)
        # For now, if it exists, assume it's the one we want and it should be healthy or getting there.
        echo_color "$GREEN" "Primary Nginx container ('$EXPECTED_NGINX_CONTAINER_NAME') found and is running (ID: $primary_nginx_container_id)."
        echo_color "$BLUE" "Assuming it is configured for ACME challenges. Skipping attempt to start a new Nginx instance."
        # Optionally, wait a few seconds if we think it might be in the process of starting up from another command
        # sleep 3 
        return 0 # Indicate success, primary Nginx is running
    fi

    echo_color "$YELLOW" "Primary Nginx container ('$EXPECTED_NGINX_CONTAINER_NAME') not found or not running."
    echo_color "$YELLOW" "Attempting to start Nginx service ('$NGINX_SERVICE_NAME_IN_WEB_COMPOSE') using $COMPOSE_FILE_WEB as a fallback..."
    echo_color "$YELLOW" "WARNING: This might conflict if another Nginx is supposed to be running on standard ports."

    # Fallback logic (original logic, attempt to start Nginx using docker-compose.web.yml)
    # This might still cause port conflicts if the main `ctl_services-webapp-1` was just temporarily down but not removed.
    if ! docker compose -f "$COMPOSE_FILE_WEB" ps -q "$NGINX_SERVICE_NAME_IN_WEB_COMPOSE" 2>/dev/null | grep -q .; then
        echo_color "$YELLOW" "Nginx service ('$NGINX_SERVICE_NAME_IN_WEB_COMPOSE') from $COMPOSE_FILE_WEB is not running. Attempting to start it..."
        # Critical: Ensure this doesn't use a conflicting project name that also maps ports 80/443.
        # For now, we proceed with the original command, but this is a known risk area.
        docker compose -p ctl_temp_web_for_ssl -f "$COMPOSE_FILE_WEB" up -d --remove-orphans "$NGINX_SERVICE_NAME_IN_WEB_COMPOSE"
        sleep 5 # Give it a moment to start
        if ! docker compose -p ctl_temp_web_for_ssl -f "$COMPOSE_FILE_WEB" ps -q "$NGINX_SERVICE_NAME_IN_WEB_COMPOSE" 2>/dev/null | grep -q .; then
            echo_color "$RED" "Failed to start Nginx service ('$NGINX_SERVICE_NAME_IN_WEB_COMPOSE') from $COMPOSE_FILE_WEB."
            echo_color "$RED" "Attempting to get Nginx service logs (last 50 lines):"
            docker compose -p ctl_temp_web_for_ssl -f "$COMPOSE_FILE_WEB" logs --tail="50" "$NGINX_SERVICE_NAME_IN_WEB_COMPOSE" || echo_color "$YELLOW" "Could not retrieve logs for $NGINX_SERVICE_NAME_IN_WEB_COMPOSE."
            echo_color "$RED" "Aborting SSL issuance."
            exit 1
        else
            echo_color "$GREEN" "Fallback Nginx service ('$NGINX_SERVICE_NAME_IN_WEB_COMPOSE') started successfully."
            echo_color "$BLUE" "Waiting a few more seconds for Nginx to initialize..."
            sleep 5 # Allow Nginx to fully initialize
        fi
    else
        echo_color "$GREEN" "Fallback Nginx service ('$NGINX_SERVICE_NAME_IN_WEB_COMPOSE') from $COMPOSE_FILE_WEB is already running."
    fi
}

run_certbot_command() {
    echo_color "$BLUE" "Attempting to obtain/renew certificate for $DOMAIN_NAME using webroot $WEBROOT_PATH..."
    
    # Note: Certbot is run with sudo because it needs to write to $CERT_CONFIG_DIR and potentially
    # other system paths depending on its plugins and hooks.
    # The webroot path ($WEBROOT_PATH) must be writable by root (or user running sudo certbot).
    
    # Temporary: Add a small delay BEFORE certbot tells LE to verify, to allow inspection of the challenge file
    # This is not ideal as certbot might create the file just as it calls LE, but it's a point to try.
    # A better way would be to modify certbot's webroot plugin or use a manual hook,
    # but for now, let's try a simple pre-sleep before the main certbot command that triggers verification.
    # Actually, certbot creates the file THEN asks for verification. So we need a way to pause it *during* perform.
    # For now, the script will run certbot, and you'll have to be quick to check during its "Waiting for verification..." phase.
    # Let's add a log here that points to the challenge file path to make it easier to check.
    echo_color "$YELLOW" "Certbot will attempt to place a challenge file in: $WEBROOT_PATH/.well-known/acme-challenge/"
    echo_color "$YELLOW" "Please monitor this directory and inside the Nginx container at /var/www/certbot/.well-known/acme-challenge/ during the 'Waiting for verification...' step."

    sudo certbot certonly \
        --webroot \
        -w "$WEBROOT_PATH" \
        -d "$DOMAIN_NAME" \
        --email "$EMAIL" \
        --config-dir "$CERT_CONFIG_DIR" \
        --work-dir "$CERT_CONFIG_DIR/work" \
        --logs-dir "$CERTBOT_LOG_DIR" \
        --agree-tos \
        --non-interactive \
        --keep-until-expiring \
        --preferred-challenges http-01 \
        --staging # Use Let's Encrypt staging server to avoid rate limits during debugging

    # Return Certbot's exit code
    return $?
}

reload_nginx_config() {
    echo_color "$BLUE" "Attempting to reload Nginx configuration..."
    local nginx_container_id_to_reload

    # First, try to find the primary expected Nginx container
    nginx_container_id_to_reload=$(docker ps -q --filter "name=^/${EXPECTED_NGINX_CONTAINER_NAME}$")

    if [ -z "$nginx_container_id_to_reload" ]; then
        echo_color "$YELLOW" "Primary Nginx container ('$EXPECTED_NGINX_CONTAINER_NAME') not found."
        echo_color "$YELLOW" "Attempting to find Nginx container from fallback compose file ($COMPOSE_FILE_WEB service '$NGINX_SERVICE_NAME_IN_WEB_COMPOSE')..."
        # This assumes the fallback might be running if the primary isn't.
        # The project name for the fallback needs to be consistent if we want to find it this way.
        nginx_container_id_to_reload=$(docker compose -p ctl_temp_web_for_ssl -f "$COMPOSE_FILE_WEB" ps -q "$NGINX_SERVICE_NAME_IN_WEB_COMPOSE" 2>/dev/null)
    fi

    if [ -z "$nginx_container_id_to_reload" ]; then
        echo_color "$RED" "Could not find any suitable Nginx container to reload (checked for '$EXPECTED_NGINX_CONTAINER_NAME' and fallback)."
        echo_color "$YELLOW" "Nginx reload skipped. You may need to do this manually if a certificate was issued."
        return 1
    fi

    echo_color "$GREEN" "Found Nginx container to reload: $nginx_container_id_to_reload. Testing configuration..."
    # No sudo needed for docker exec
    if docker exec "$nginx_container_id_to_reload" nginx -t; then
        echo_color "$GREEN" "Nginx configuration test successful. Reloading Nginx..."
        if docker exec "$nginx_container_id_to_reload" nginx -s reload; then
            echo_color "$GREEN" "Nginx reloaded successfully."
        else
            echo_color "$RED" "Failed to reload Nginx. Check Nginx container logs ('$nginx_container_id_to_reload')."
            return 1
        fi
    else
        echo_color "$RED" "Nginx configuration test failed. Nginx not reloaded. Check Nginx configuration files and container logs."
        return 1
    fi
    return 0
}

# --- Main Script Logic ---
main() {
    echo_color "$GREEN" "--- SSL Certificate Management Script ---"

    ensure_dependencies "certbot" "docker" "docker compose"
    ensure_certbot_dirs
    ensure_nginx_running # Critical step to ensure Nginx is ready

    # Attempt to reload Nginx *before* running Certbot to ensure latest config is loaded
    # especially the ACME challenge location block.
    echo_color "$BLUE" "Attempting to reload Nginx to ensure latest configuration for ACME challenge..."
    if ! reload_nginx_config; then
        echo_color "$YELLOW" "Nginx reload before Certbot attempt failed or was skipped. Proceeding with Certbot, but this might be an issue."
        # Depending on strictness, you might choose to exit here if Nginx reload fails.
    else
        echo_color "$GREEN" "Nginx reloaded successfully before Certbot attempt."
    fi

    if run_certbot_command; then
        echo_color "$GREEN" "Certbot process completed successfully for $DOMAIN_NAME."
        echo_color "$BLUE" "Attempting final Nginx reload after successful Certbot run..."
        if ! reload_nginx_config; then
            echo_color "$YELLOW" "Nginx reload after successful Certbot run failed or was skipped. Please check Nginx status and configuration manually."
        fi
    else
        local certbot_exit_code=$?
        echo_color "$RED" "Certbot process failed with exit code $certbot_exit_code for $DOMAIN_NAME."
        echo_color "$RED" "Please check Certbot logs in: $CERTBOT_LOG_DIR (these logs are on the host)."
        exit "$certbot_exit_code"
    fi

    echo_color "$GREEN" "--- SSL Script Finished Successfully ---"
}

# Execute main function with all script arguments
main "$@" 