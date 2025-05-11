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
CERTBOT_CONFIG_SUBDIR="config/docker/certbot/conf"
CERTBOT_WEBROOT_SUBDIR="config/docker/certbot/www"
CERTBOT_LOGS_SUBDIR="logs/certbot"
NGINX_COMPOSE_FILE_SUBDIR="config/docker/docker-compose.web.yml"
NGINX_SERVICE_NAME="webapp" # Nginx service name in its docker-compose file

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
    sudo chmod -R 755 "$WEBROOT_PATH" # Ensure nginx can read, certbot (as root/sudo) can write.

    echo_color "$GREEN" "Certbot directories checked/created."
}

ensure_nginx_running() {
    echo_color "$BLUE" "Checking if Nginx service ('$NGINX_SERVICE_NAME') is running..."
    # No sudo needed for docker compose as admin_control_daemon has docker.sock mounted
    if ! docker compose -f "$COMPOSE_FILE_WEB" ps -q "$NGINX_SERVICE_NAME" 2>/dev/null | grep -q .; then
        echo_color "$YELLOW" "Nginx service ('$NGINX_SERVICE_NAME') is not running. Attempting to start it..."
        docker compose -f "$COMPOSE_FILE_WEB" up -d --remove-orphans "$NGINX_SERVICE_NAME"
        sleep 5 # Give it a moment to start
        if ! docker compose -f "$COMPOSE_FILE_WEB" ps -q "$NGINX_SERVICE_NAME" 2>/dev/null | grep -q .; then
            echo_color "$RED" "Failed to start Nginx service ('$NGINX_SERVICE_NAME') from $COMPOSE_FILE_WEB."
            echo_color "$RED" "Attempting to get Nginx service logs (last 50 lines):"
            docker compose -f "$COMPOSE_FILE_WEB" logs --tail="50" "$NGINX_SERVICE_NAME" || echo_color "$YELLOW" "Could not retrieve logs for $NGINX_SERVICE_NAME."
            echo_color "$RED" "Aborting SSL issuance."
            exit 1
        else
            echo_color "$GREEN" "Nginx service ('$NGINX_SERVICE_NAME') started successfully."
            echo_color "$BLUE" "Waiting a few more seconds for Nginx to initialize..."
            sleep 5 # Allow Nginx to fully initialize
        fi
    else
        echo_color "$GREEN" "Nginx service ('$NGINX_SERVICE_NAME') is already running."
    fi
}

run_certbot_command() {
    echo_color "$BLUE" "Attempting to obtain/renew certificate for $DOMAIN_NAME using webroot $WEBROOT_PATH..."
    
    # Note: Certbot is run with sudo because it needs to write to $CERT_CONFIG_DIR and potentially
    # other system paths depending on its plugins and hooks.
    # The webroot path ($WEBROOT_PATH) must be writable by root (or user running sudo certbot).
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
        --preferred-challenges http-01
        # Add --staging for testing to avoid hitting rate limits:
        # --staging

    # Return Certbot's exit code
    return $?
}

reload_nginx_config() {
    echo_color "$BLUE" "Attempting to reload Nginx configuration for service '$NGINX_SERVICE_NAME'..."
    local nginx_container_id
    # No sudo needed for docker compose
    nginx_container_id=$(docker compose -f "$COMPOSE_FILE_WEB" ps -q "$NGINX_SERVICE_NAME" 2>/dev/null)

    if [ -z "$nginx_container_id" ]; then
        echo_color "$RED" "Could not find the Nginx container for service '$NGINX_SERVICE_NAME'."
        echo_color "$YELLOW" "Nginx reload skipped. You may need to do this manually."
        return 1
    fi

    echo_color "$GREEN" "Found Nginx container ID: $nginx_container_id. Testing configuration..."
    # No sudo needed for docker exec
    if docker exec "$nginx_container_id" nginx -t; then
        echo_color "$GREEN" "Nginx configuration test successful. Reloading Nginx..."
        if docker exec "$nginx_container_id" nginx -s reload; then
            echo_color "$GREEN" "Nginx reloaded successfully."
        else
            echo_color "$RED" "Failed to reload Nginx. Check Nginx container logs."
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
    ensure_nginx_running # Critical step to ensure Nginx is ready for webroot challenge

    if run_certbot_command; then
        echo_color "$GREEN" "Certbot process completed successfully for $DOMAIN_NAME."
        if ! reload_nginx_config; then
            echo_color "$YELLOW" "Nginx reload failed or was skipped. Please check Nginx status and configuration."
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