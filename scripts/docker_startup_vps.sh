#!/bin/bash

# CloudToLocalLLM Docker Startup Script (Non-Root)
# This script starts the CloudToLocalLLM application using existing Let's Encrypt certificates
# Requires: Docker group membership, existing Let's Encrypt certificates

set -e  # Exit on any error
set -u  # Exit on undefined variables

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

# Function to create required directories
create_directories() {
    log_info "Creating required directories..."

    cd "${PROJECT_DIR}"

    # Create directories with proper permissions
    mkdir -p certbot/www certbot/live certbot/archive
    mkdir -p ssl config/nginx

    # Ensure proper permissions for certbot directories
    chmod -R 755 certbot/www

    log_success "Directories created successfully."
}

# Function to check Let's Encrypt certificates
check_certificates() {
    log_info "Checking Let's Encrypt certificates..."

    if [ -d "${PROJECT_DIR}/certbot/live/cloudtolocalllm.online" ]; then
        log_success "Let's Encrypt certificates found."
        return 0
    else
        log_warning "Let's Encrypt certificates not found."
        log_warning "Application will start but HTTPS may not work properly."
        log_warning "Run certbot to obtain certificates if needed."
        return 1
    fi
}

# Function to start Docker containers
start_containers() {
    log_info "Starting Docker Compose..."

    cd "${PROJECT_DIR}"

    # Pull latest images if needed
    docker compose pull --ignore-pull-failures || true

    # Build and start containers
    docker compose up -d --build || {
        log_error "Failed to start Docker containers"
        log_error "Check docker-compose.yml and Dockerfile.web for issues"
        exit 1
    }

    log_success "Docker containers started successfully."
}

# Function to verify containers are running
verify_containers() {
    log_info "Verifying containers are running..."

    # Wait a moment for containers to start
    sleep 5

    # Check container status
    if docker ps --filter "name=cloudtolocalllm" --format "table {{.Names}}\t{{.Status}}" | grep -q "Up"; then
        log_success "Containers are running."
        docker ps --filter "name=cloudtolocalllm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        log_error "Containers failed to start properly."
        docker ps --filter "name=cloudtolocalllm"
        log_error "Check logs with: docker logs cloudtolocalllm-webapp"
        exit 1
    fi
}

# Main function
main() {
    log_info "Starting CloudToLocalLLM Docker containers..."

    # Create required directories
    create_directories

    # Check certificates (non-blocking)
    check_certificates

    # Start containers
    start_containers

    # Verify containers
    verify_containers

    log_success "CloudToLocalLLM startup completed successfully!"
    log_info "Application should be available at:"
    log_info "- Homepage: http://cloudtolocalllm.online"
    log_info "- Web App: http://app.cloudtolocalllm.online"

    if [ -d "${PROJECT_DIR}/certbot/live/cloudtolocalllm.online" ]; then
        log_info "- HTTPS Homepage: https://cloudtolocalllm.online"
        log_info "- HTTPS Web App: https://app.cloudtolocalllm.online"
    fi
}

# Run main function
main "$@"