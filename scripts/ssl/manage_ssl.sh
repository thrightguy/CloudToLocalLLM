#!/bin/bash
# This script manages the issuance and renewal of SSL certificates using Certbot
# with DNS validation for both the main domain and wildcard certificate.
# It is designed to be run within an environment that has Certbot installed.

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
EMAIL="christopher.maltais@gmail.com" # Email for Let's Encrypt account
DOMAIN_NAME="cloudtolocalllm.online"    # The domain to issue the certificate for
PROJECT_DIR="/opt/cloudtolocalllm"    # Absolute path to your project's root on the host machine

# Certbot related paths
CERTBOT_CONFIG_SUBDIR="certbot/conf"
CERTBOT_LOGS_SUBDIR="logs/certbot"

# Construct full paths
CERT_CONFIG_DIR="$PROJECT_DIR/$CERTBOT_CONFIG_SUBDIR"
CERTBOT_LOG_DIR="$PROJECT_DIR/$CERTBOT_LOGS_SUBDIR"

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
        if ! command -v "$dep" &>/dev/null; then
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
    echo_color "$YELLOW" "Ensuring Certbot directories exist:"
    echo_color "$YELLOW" "  Config dir: $CERT_CONFIG_DIR"
    echo_color "$YELLOW" "  Logs dir: $CERTBOT_LOG_DIR"

    mkdir -p "$CERT_CONFIG_DIR"
    mkdir -p "$CERTBOT_LOG_DIR"
    
    # Ensure the user has write permissions
    if [ ! -w "$CERT_CONFIG_DIR" ] || [ ! -w "$CERTBOT_LOG_DIR" ]; then
        echo_color "$RED" "Error: You don't have write permissions to the certbot directories."
        echo_color "$YELLOW" "Please run: sudo chown -R $(whoami):$(whoami) $CERT_CONFIG_DIR $CERTBOT_LOG_DIR"
        exit 1
    fi
    
    echo_color "$GREEN" "Certbot directories checked/created."
}

run_dns_certbot() {
    echo_color "$BLUE" "Obtaining certificate using DNS validation..."
    echo_color "$YELLOW" "This will require you to add a TXT record to your DNS provider."
    echo_color "$YELLOW" "The script will pause and wait for you to add the TXT record."

    set +e
    certbot certonly \
        --manual \
        --preferred-challenges dns \
        --email "$EMAIL" \
        --config-dir "$CERT_CONFIG_DIR" \
        --work-dir "$CERT_CONFIG_DIR/work" \
        --logs-dir "$CERTBOT_LOG_DIR" \
        --agree-tos \
        --staging \
        -d "$DOMAIN_NAME" \
        -d "*.${DOMAIN_NAME}" \
        "$@"
    local certbot_exit_code=$?
    set -e

    if [ $certbot_exit_code -eq 0 ]; then
        echo_color "$GREEN" "Certificate obtained successfully!"
        echo_color "$YELLOW" "To obtain production certificates, run this script again with --production flag."
    else
        echo_color "$RED" "Failed to obtain certificate. Check the logs in $CERTBOT_LOG_DIR"
    fi
    return $certbot_exit_code
}

# --- Main Script Logic ---
main() {
    echo_color "$GREEN" "--- SSL Certificate Management Script (Staging Mode) ---"
    echo_color "$YELLOW" "[DEBUG] This is the latest manage_ssl.sh version: $(date)"

    # --- Certbot Symlink Structure Cleanup ---
    LIVE_DIR="$CERT_CONFIG_DIR/live/$DOMAIN_NAME"
    ARCHIVE_DIR="$CERT_CONFIG_DIR/archive/$DOMAIN_NAME"
    RENEWAL_CONF="$CERT_CONFIG_DIR/../renewal/$DOMAIN_NAME.conf"

    # --- Remove ALL existing certificates before doing anything ---
    echo_color "$YELLOW" "[CLEANUP] Removing all existing cert, archive, and renewal files for $DOMAIN_NAME before requesting a new certificate."
    rm -rf "$CERT_CONFIG_DIR/live/$DOMAIN_NAME"*
    rm -rf "$CERT_CONFIG_DIR/archive/$DOMAIN_NAME"*
    rm -f "$CERT_CONFIG_DIR/../renewal/$DOMAIN_NAME"*.conf

    ensure_dependencies "certbot"
    ensure_certbot_dirs

    # Get certificate for main domain and wildcard using DNS validation
    if run_dns_certbot "$@"; then
        # --- Normalize Cert Directory Name and Clean Up Old Certs ---
        # Find the latest cert directory (with -0001, -0002, etc. if present, but not _backup_)
        LATEST_CERT_DIR=$(ls -d $CERT_CONFIG_DIR/live/${DOMAIN_NAME}* | grep -v _backup_ | sort | tail -n 1)
        if [[ "$LATEST_CERT_DIR" != "$CERT_CONFIG_DIR/live/$DOMAIN_NAME" ]]; then
            echo_color "$YELLOW" "[AUTO-FIX] Moving new certs from $LATEST_CERT_DIR to $CERT_CONFIG_DIR/live/$DOMAIN_NAME for Nginx compatibility."
            rm -rf "$CERT_CONFIG_DIR/live/$DOMAIN_NAME"
            cp -a "$LATEST_CERT_DIR" "$CERT_CONFIG_DIR/live/$DOMAIN_NAME"
        fi
        # Remove any symlinks in the canonical directory and replace with real files from the latest cert dir
        for file in cert.pem chain.pem fullchain.pem privkey.pem; do
            CANONICAL_FILE="$CERT_CONFIG_DIR/live/$DOMAIN_NAME/$file"
            LATEST_FILE="$LATEST_CERT_DIR/$file"
            if [ -L "$CANONICAL_FILE" ]; then
                echo_color "$YELLOW" "[AUTO-FIX] Removing symlink $CANONICAL_FILE and copying real file from $LATEST_FILE."
                rm -f "$CANONICAL_FILE"
                cp "$LATEST_FILE" "$CANONICAL_FILE"
            fi
        done
        # Delete all other cert directories except the canonical one
        for dir in $CERT_CONFIG_DIR/live/${DOMAIN_NAME}*; do
            if [[ "$dir" != "$CERT_CONFIG_DIR/live/$DOMAIN_NAME" ]]; then
                echo_color "$YELLOW" "[CLEANUP] Deleting old or backup cert directory: $dir"
                rm -rf "$dir"
            fi
        done
        # Also clean up archive and renewal files
        LATEST_ARCHIVE_DIR=$(ls -d $CERT_CONFIG_DIR/archive/${DOMAIN_NAME}* | grep -v _backup_ | sort | tail -n 1)
        if [[ "$LATEST_ARCHIVE_DIR" != "$CERT_CONFIG_DIR/archive/$DOMAIN_NAME" ]]; then
            rm -rf "$CERT_CONFIG_DIR/archive/$DOMAIN_NAME"
            mv "$LATEST_ARCHIVE_DIR" "$CERT_CONFIG_DIR/archive/$DOMAIN_NAME"
        fi
        for dir in $CERT_CONFIG_DIR/archive/${DOMAIN_NAME}*; do
            if [[ "$dir" != "$CERT_CONFIG_DIR/archive/$DOMAIN_NAME" ]]; then
                echo_color "$YELLOW" "[CLEANUP] Deleting old or backup archive directory: $dir"
                rm -rf "$dir"
            fi
        done
    fi
}

# Run the main function
main "$@" 