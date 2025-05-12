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
set -x  # Enable bash debug output
trap 'echo -e "\033[1;31m[ERROR] Script interrupted or failed. Please check logs.\033[0m"; exit 1' INT TERM ERR

# Color helpers
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Function to log messages
log_info() { echo -e "${CYAN}[INFO] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }

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
read -r -p "$(echo -e "${YELLOW}Press Enter to continue, or Ctrl+C to abort...${NC}")"

log_info "Attempting to obtain certificates using DNS challenge for wildcards."
log_warn "You will be prompted by Certbot to add TXT records to your DNS."
log_warn "Open your DNS provider (e.g., Namecheap) and be ready to add or update TXT records."
log_warn "After adding each record, use a tool like https://dnschecker.org to confirm propagation before continuing."

CERTBOT_COMMAND_OPTIONS="--manual --preferred-challenges dns --email $YOUR_EMAIL $DOMAINS_REQUESTED --agree-tos --no-eff-email --keep-until-expiring --manual-public-ip-logging-ok"

echo -e "${CYAN}[DEBUG] docker compose -f \"$COMPOSE_FILE\" run --rm \"$CERTBOT_SERVICE_NAME\" certonly $CERTBOT_COMMAND_OPTIONS${NC}"
log_info "Running Certbot via Docker Compose..."

docker compose -f "$COMPOSE_FILE" run --rm "$CERTBOT_SERVICE_NAME" certonly $CERTBOT_COMMAND_OPTIONS
CERTBOT_EXIT_CODE=$?

echo -e "${CYAN}[DEBUG] Certbot exit code: $CERTBOT_EXIT_CODE${NC}"

if [ $CERTBOT_EXIT_CODE -eq 0 ]; then
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

log_info "All done! If you need to renew, just run this script again."
exit 0 