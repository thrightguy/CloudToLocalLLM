#!/bin/bash
# Script to obtain initial Let's Encrypt certificates using Certbot and Docker Compose.
#
# IMPORTANT:
# 1. Run this script from the root of your project (e.g., /opt/cloudtolocalllm).
# 2. Ensure your DNS records for the specified domains are pointing to this server's IP.
# 3. Ensure Nginx (or another web server on port 80) is running and configured
#    to serve ACME challenges from the webroot path.
# 4. You must be logged in as a user with Docker permissions (e.g., root, or a user in the 'docker' group).

# --- Configuration ---
# !!! EDIT THESE VALUES BELOW !!!
YOUR_EMAIL="christopher.maltais@gmail.com"
# List your domains with -d for each. e.g., "-d example.com -d www.example.com"
DOMAINS_REQUESTED="-d *.cloudtolocalllm.online -d cloudtolocalllm.online"
# --- End Configuration ---

# Path to your docker-compose.yml file
COMPOSE_FILE="docker-compose.yml"
# Name of the Certbot service in your docker-compose.yml
CERTBOT_SERVICE_NAME="certbot"
# Webroot path used by Certbot for domain validation (must match Nginx and Certbot volume mounts)
WEBROOT_PATH="/var/www/certbot"

# --- Script Logic ---
set -e # Exit immediately if a command exits with a non-zero status.
trap 'echo "[ERROR] Script interrupted or failed. Please check logs."; exit 1' INT TERM ERR

# Function to log messages
log_info() {
    echo "[INFO] $1"
}
log_error() {
    echo "[ERROR] $1" >&2
}
log_success() {
    echo "[SUCCESS] $1"
}

log_info "Starting Let's Encrypt certificate acquisition process..."

if [[ "$YOUR_EMAIL" == "your_email@example.com" ]]; then
    log_error "Please edit this script and set your actual email address in the YOUR_EMAIL variable."
    exit 1
fi

if [[ -z "$DOMAINS_REQUESTED" ]]; then
    log_error "Please edit this script and set the DOMAINS_REQUESTED variable."
    exit 1
fi

log_info "Domains to request certificates for: $DOMAINS_REQUESTED"
log_info "Email for registration and recovery: $YOUR_EMAIL"
log_info "Using Certbot service: $CERTBOT_SERVICE_NAME"
log_info "Using Docker Compose file: $COMPOSE_FILE"

echo ""
log_info "Before proceeding, please ensure:"
log_info "  1. DNS records for the domain(s) above point to this server's public IP address."
log_info "  2. You are ready to add TXT records to your DNS for domain validation."
echo ""
read -r -p "Press Enter to continue, or Ctrl+C to abort..."

log_info "Attempting to obtain certificates..."

# Using DNS challenge for wildcard certificates
CERTBOT_COMMAND_OPTIONS="--manual --preferred-challenges dns --email $YOUR_EMAIL $DOMAINS_REQUESTED --agree-tos --no-eff-email --keep-until-expiring --manual-public-ip-logging-ok"

# The old webroot method (does not work for wildcards)
# CERTBOT_COMMAND_OPTIONS="--webroot -w $WEBROOT_PATH --email $YOUR_EMAIL $DOMAINS_REQUESTED --agree-tos --no-eff-email --force-renewal"

docker compose -f "$COMPOSE_FILE" run --rm "$CERTBOT_SERVICE_NAME" certonly $CERTBOT_COMMAND_OPTIONS

if [ $? -eq 0 ]; then
    log_success "Certbot process completed successfully!"
    log_info "Certificates should now be available in the volume mounted to '/etc/letsencrypt' by the Certbot container (typically './certbot/conf/live/YOUR_DOMAIN')."
    log_info "To make Nginx use the new certificates, you should restart it."
    log_info "Suggested command: docker compose restart nginx"
else
    log_error "Certbot process failed. Please check the output above for detailed error messages."
    log_error "Common troubleshooting steps:"
    log_error "  - Verify DNS propagation for your domain(s)."
    log_error "  - Ensure the TXT records were correctly added with the values provided."
    log_error "  - You can use online DNS checking tools to verify TXT record propagation."
    exit 1
fi

exit 0 