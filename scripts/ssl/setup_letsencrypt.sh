#!/bin/bash

# CloudToLocalLLM Let's Encrypt Certificate Setup Script
# This script sets up and manages Let's Encrypt certificates for cloudtolocalllm.online

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="cloudtolocalllm.online"
EMAIL="admin@cloudtolocalllm.online"
WEBROOT_PATH="/var/www/certbot"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Function to print colored output
echo_color() {
    echo -e "${1}${2}${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo_color "$RED" "This script should not be run as root for security reasons."
        echo_color "$YELLOW" "Please run as the cloudllm user."
        exit 1
    fi
}

# Function to check if Docker and Docker Compose are available
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo_color "$RED" "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        echo_color "$RED" "Docker Compose is not available"
        exit 1
    fi
}

# Function to check if the webapp container is running
check_webapp_running() {
    if ! docker compose ps | grep -q "cloudtolocalllm-webapp.*Up"; then
        echo_color "$YELLOW" "Starting webapp container for certificate validation..."
        docker compose up -d webapp
        sleep 10
    fi
}

# Function to obtain Let's Encrypt certificate
obtain_certificate() {
    echo_color "$BLUE" "Obtaining Let's Encrypt certificate for $DOMAIN..."
    
    # Ensure webroot directory exists
    docker compose exec webapp mkdir -p "$WEBROOT_PATH"
    
    # Run certbot to obtain certificate
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT_PATH" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN" \
        -d "www.$DOMAIN" \
        -d "app.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo_color "$GREEN" "Certificate obtained successfully!"
        return 0
    else
        echo_color "$RED" "Failed to obtain certificate"
        return 1
    fi
}

# Function to test certificate renewal
test_renewal() {
    echo_color "$BLUE" "Testing certificate renewal..."
    
    docker compose run --rm certbot renew --dry-run
    
    if [ $? -eq 0 ]; then
        echo_color "$GREEN" "Certificate renewal test passed!"
        return 0
    else
        echo_color "$RED" "Certificate renewal test failed"
        return 1
    fi
}

# Function to restart webapp to apply new certificates
restart_webapp() {
    echo_color "$BLUE" "Restarting webapp to apply new certificates..."
    docker compose restart webapp
    echo_color "$GREEN" "Webapp restarted successfully!"
}

# Function to check certificate status
check_certificate() {
    echo_color "$BLUE" "Checking certificate status..."
    
    if docker compose run --rm certbot certificates | grep -q "$DOMAIN"; then
        echo_color "$GREEN" "Certificate found for $DOMAIN"
        docker compose run --rm certbot certificates
        return 0
    else
        echo_color "$YELLOW" "No certificate found for $DOMAIN"
        return 1
    fi
}

# Function to setup automatic renewal
setup_renewal() {
    echo_color "$BLUE" "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > /tmp/renew_certs.sh << 'EOF'
#!/bin/bash
cd /opt/cloudtolocalllm
docker compose run --rm certbot renew --quiet
docker compose restart webapp
EOF
    
    # Move to proper location and set permissions
    sudo mv /tmp/renew_certs.sh /etc/cron.daily/renew-cloudtolocalllm-certs
    sudo chmod +x /etc/cron.daily/renew-cloudtolocalllm-certs
    
    echo_color "$GREEN" "Automatic renewal setup complete!"
    echo_color "$YELLOW" "Certificates will be renewed daily if needed."
}

# Main function
main() {
    echo_color "$BLUE" "CloudToLocalLLM Let's Encrypt Certificate Setup"
    echo_color "$BLUE" "=============================================="
    
    check_root
    check_docker
    
    case "${1:-setup}" in
        "setup")
            check_webapp_running
            obtain_certificate
            restart_webapp
            setup_renewal
            echo_color "$GREEN" "Certificate setup complete!"
            ;;
        "renew")
            obtain_certificate
            restart_webapp
            echo_color "$GREEN" "Certificate renewal complete!"
            ;;
        "test")
            test_renewal
            ;;
        "status")
            check_certificate
            ;;
        "help"|"-h"|"--help")
            echo_color "$BLUE" "Usage: $0 [setup|renew|test|status|help]"
            echo_color "$YELLOW" "  setup  - Initial certificate setup (default)"
            echo_color "$YELLOW" "  renew  - Force certificate renewal"
            echo_color "$YELLOW" "  test   - Test certificate renewal"
            echo_color "$YELLOW" "  status - Check certificate status"
            echo_color "$YELLOW" "  help   - Show this help message"
            ;;
        *)
            echo_color "$RED" "Unknown command: $1"
            echo_color "$YELLOW" "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
