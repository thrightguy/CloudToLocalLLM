#!/bin/bash

# CloudToLocalLLM VPS Deployment Script (Non-Root)
# This script deploys the CloudToLocalLLM application using Docker without requiring root privileges
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
readonly LOG_FILE="${PROJECT_DIR}/deployment.log"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging function
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "${BLUE}[INFO ${TIMESTAMP}]${NC} ${1}"
}

log_success() {
    log "${GREEN}[SUCCESS ${TIMESTAMP}]${NC} ${1}"
}

log_warning() {
    log "${YELLOW}[WARNING ${TIMESTAMP}]${NC} ${1}"
}

log_error() {
    log "${RED}[ERROR ${TIMESTAMP}]${NC} ${1}"
}

# Function to check system requirements (non-root)
check_requirements() {
    log_info "Checking system requirements..."

    # Check Docker access (non-root)
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not accessible. Please ensure user is in docker group."
        log_error "Run: sudo usermod -aG docker \$USER && newgrp docker"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker Compose is not installed."
        exit 1
    fi

    # Check minimum disk space (5GB free for application)
    local free_space
    free_space=$(df -BG "${PROJECT_DIR}" | awk 'NR==2 {print $4}' | sed 's/G//')
    if ! [[ "$free_space" =~ ^[0-9]+$ ]]; then
        log_error "Could not determine free disk space."
        exit 1
    fi
    if [ "$free_space" -lt 5 ]; then
        log_error "Insufficient disk space. Need at least 5GB free. Found: ${free_space}G"
        exit 1
    fi

    # Check if Let's Encrypt certificates exist
    if [ ! -d "${PROJECT_DIR}/certbot/live" ]; then
        log_warning "Let's Encrypt certificates not found. SSL may not work properly."
    fi

    log_success "System requirements met."
}

# Function to backup existing build
backup_build() {
    log_info "Backing up existing build..."
    local backup_dir="${PROJECT_DIR}/backup_$(date +%Y%m%d_%H%M%S)"

    if [ -d "${PROJECT_DIR}/build" ]; then
        cp -r "${PROJECT_DIR}/build" "${backup_dir}"
        log_success "Build backup created at ${backup_dir}"
    fi
}

# Function to clean up Docker containers (non-root)
cleanup_containers() {
    log_info "Cleaning up existing containers..."

    # Stop and remove containers if they exist
    if docker ps -q --filter "name=cloudtolocalllm" | grep -q .; then
        log_info "Stopping existing CloudToLocalLLM containers..."
        docker stop $(docker ps -q --filter "name=cloudtolocalllm") 2>/dev/null || true
        docker rm $(docker ps -aq --filter "name=cloudtolocalllm") 2>/dev/null || true
    fi

    # Clean up unused Docker resources
    log_info "Cleaning up unused Docker resources..."
    docker system prune -f --volumes 2>/dev/null || true

    log_success "Container cleanup completed."
}

# Function to build Flutter web application
build_flutter_app() {
    log_info "Building Flutter web application..."

    # Check if Flutter is available
    if ! command -v flutter >/dev/null 2>&1; then
        log_error "Flutter is not installed or not in PATH."
        exit 1
    fi

    # Clean previous build
    if [ -d "${PROJECT_DIR}/build" ]; then
        rm -rf "${PROJECT_DIR}/build"
    fi

    # Get dependencies
    log_info "Getting Flutter dependencies..."
    cd "${PROJECT_DIR}"
    flutter pub get || {
        log_error "Failed to get Flutter dependencies"
        exit 1
    }

    # Build web application
    log_info "Building Flutter web application for production..."
    flutter build web --release || {
        log_error "Failed to build Flutter web application"
        exit 1
    }

    log_success "Flutter web application built successfully."
}

# Function to setup Let's Encrypt certificates
setup_certificates() {
    log_info "Setting up Let's Encrypt certificates..."

    # Check if certificate setup script exists
    if [ -f "${PROJECT_DIR}/scripts/ssl/setup_letsencrypt.sh" ]; then
        cd "${PROJECT_DIR}"

        # Run SSL setup with timeout to prevent hanging
        timeout 600 ./scripts/ssl/setup_letsencrypt.sh setup
        local ssl_result=$?

        if [ $ssl_result -eq 0 ]; then
            log_success "SSL certificates configured successfully!"
        elif [ $ssl_result -eq 124 ]; then
            log_warning "SSL setup timed out after 10 minutes. Continuing without SSL."
            log_warning "You can run it manually later: ./scripts/ssl/setup_letsencrypt.sh setup"
        else
            log_warning "Certificate setup failed. You can run it manually later:"
            log_warning "./scripts/ssl/setup_letsencrypt.sh setup"
        fi
    else
        log_warning "Certificate setup script not found."
        log_info "You can obtain certificates manually with:"
        log_info "docker compose run --rm certbot certonly --webroot -w /var/www/certbot --email admin@cloudtolocalllm.online --agree-tos --no-eff-email -d cloudtolocalllm.online -d app.cloudtolocalllm.online"
    fi
}

# Main deployment function
main() {
    log_info "Starting CloudToLocalLLM VPS deployment..."

    # Check system requirements
    check_requirements

    # Backup existing build
    backup_build

    # Clean up existing containers
    cleanup_containers

    # Build Flutter application
    build_flutter_app

    # Deploy with Docker
    deploy_docker

    # Verify deployment
    verify_deployment

    # Setup Let's Encrypt certificates
    setup_certificates

    log_success "CloudToLocalLLM deployment completed successfully!"
}

# Function to deploy using Docker Compose
deploy_docker() {
    log_info "Deploying application with Docker Compose..."

    cd "${PROJECT_DIR}"

    # Ensure required directories exist
    mkdir -p certbot/www certbot/live certbot/archive ssl config/nginx

    # Ensure Flutter build directory exists (built on host, not in container)
    if [ ! -d "${PROJECT_DIR}/build/web" ]; then
        log_error "Flutter build directory not found. Please run 'flutter build web --release' first."
        exit 1
    fi

    # Build and start containers (nginx only, no Flutter build)
    log_info "Building and starting Docker containers..."
    docker compose up -d --build || {
        log_error "Failed to start Docker containers"
        exit 1
    }

    log_success "Docker containers started successfully."
}

# Function to verify deployment
verify_deployment() {
    log_info "Verifying deployment..."

    # Wait for containers to start
    sleep 10

    # Check if containers are running
    if ! docker ps --filter "name=cloudtolocalllm" --format "table {{.Names}}\t{{.Status}}" | grep -q "Up"; then
        log_error "Containers are not running properly"
        docker ps --filter "name=cloudtolocalllm"
        exit 1
    fi

    # Check if web application is responding
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:80/ >/dev/null 2>&1; then
            log_success "Web application is responding."
            break
        fi

        log_info "Waiting for web application to start... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        log_error "Web application failed to start within expected time"
        docker logs cloudtolocalllm-webapp --tail 50
        exit 1
    fi

    # Display deployment status
    log_success "Deployment verification completed."
    log_info "Container Status:"
    docker ps --filter "name=cloudtolocalllm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    log_info "Application URLs:"
    log_info "- Homepage: http://cloudtolocalllm.online"
    log_info "- Web App: http://app.cloudtolocalllm.online"
    log_info "- HTTPS URLs available if Let's Encrypt certificates are configured"
}

# Run main function
main "$@"