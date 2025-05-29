#!/bin/bash

# CloudToLocalLLM Deployment with SSL Script
# This script deploys the application with self-signed certificates initially,
# then helps set up Let's Encrypt certificates for production use.

set -e  # Exit on any error

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} ${1}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ${1}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ${1}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ${1}"
}

# Function to display help
show_help() {
    echo "CloudToLocalLLM Deployment with SSL Script"
    echo ""
    echo "This script deploys the application with self-signed certificates initially,"
    echo "then helps set up Let's Encrypt certificates for production use."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --skip-ssl     Skip Let's Encrypt certificate setup"
    echo ""
    echo "Example:"
    echo "  $0             # Deploy with self-signed certs and attempt Let's Encrypt setup"
    echo "  $0 --skip-ssl  # Deploy with self-signed certs only"
}

# Parse command line arguments
SKIP_SSL=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --skip-ssl)
            SKIP_SSL=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main function
main() {
    log_info "Starting CloudToLocalLLM deployment with SSL..."
    
    # Step 1: Run the main deployment script
    log_info "Running main deployment script..."
    "${PROJECT_DIR}/scripts/deploy_vps.sh"
    
    # Check if deployment was successful
    if [ $? -ne 0 ]; then
        log_error "Deployment failed. Please check the logs for errors."
        exit 1
    fi
    
    log_success "Initial deployment completed successfully!"
    
    # Step 2: Set up Let's Encrypt certificates if not skipped
    if [ "$SKIP_SSL" = false ]; then
        log_info "Setting up Let's Encrypt certificates..."
        log_warning "This requires your domain to be properly configured with DNS pointing to this server."
        log_warning "If DNS is not yet configured, the certificate setup will fail."
        
        read -p "Do you want to continue with Let's Encrypt setup? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "${PROJECT_DIR}/scripts/ssl/setup_letsencrypt.sh" setup
            
            if [ $? -eq 0 ]; then
                log_success "Let's Encrypt certificates set up successfully!"
                log_info "Restarting containers to apply new certificates..."
                cd "${PROJECT_DIR}"
                docker compose restart webapp
                log_success "Deployment with Let's Encrypt SSL completed successfully!"
            else
                log_warning "Let's Encrypt certificate setup failed."
                log_warning "The application will continue to use self-signed certificates."
                log_info "You can run the certificate setup again later with:"
                log_info "  ${PROJECT_DIR}/scripts/ssl/setup_letsencrypt.sh setup"
            fi
        else
            log_info "Skipping Let's Encrypt setup."
            log_info "The application will use self-signed certificates."
            log_info "You can set up Let's Encrypt certificates later with:"
            log_info "  ${PROJECT_DIR}/scripts/ssl/setup_letsencrypt.sh setup"
        fi
    else
        log_info "Let's Encrypt certificate setup skipped."
        log_info "The application will use self-signed certificates."
        log_info "You can set up Let's Encrypt certificates later with:"
        log_info "  ${PROJECT_DIR}/scripts/ssl/setup_letsencrypt.sh setup"
    fi
    
    log_success "CloudToLocalLLM deployment completed!"
    log_info "Application URLs:"
    log_info "- HTTP: http://cloudtolocalllm.online"
    log_info "- HTTPS: https://cloudtolocalllm.online (using self-signed or Let's Encrypt certificates)"
    log_info "- Web App: https://app.cloudtolocalllm.online"
}

# Run main function
main