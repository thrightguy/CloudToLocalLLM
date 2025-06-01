#!/bin/bash

# Multi-Container Deployment Script for CloudToLocalLLM
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.multi.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
CloudToLocalLLM Multi-Container Deployment Script

Usage: $0 [options] [services...]

Options:
  --build           Force rebuild of containers
  --no-cache        Build without using cache
  --pull            Pull latest base images
  --ssl-setup       Set up SSL certificates
  --logs            Show logs after deployment
  --help            Show this help message

Services (deploy specific services only):
  nginx-proxy       Nginx reverse proxy
  static-site       Static website and documentation
  flutter-app       Flutter web application
  api-backend       API backend for bridge communication
  all               Deploy all services (default)

Examples:
  $0                          # Deploy all services
  $0 --build                  # Rebuild and deploy all services
  $0 flutter-app              # Deploy only Flutter app
  $0 --build static-site      # Rebuild and deploy static site
  $0 --ssl-setup              # Set up SSL certificates

EOF
}

# Parse command line arguments
BUILD=false
NO_CACHE=false
PULL=false
SSL_SETUP=false
SHOW_LOGS=false
SERVICES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --pull)
            PULL=true
            shift
            ;;
        --ssl-setup)
            SSL_SETUP=true
            shift
            ;;
        --logs)
            SHOW_LOGS=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        nginx-proxy|static-site|flutter-app|api-backend|all)
            SERVICES+=("$1")
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Default to all services if none specified
if [ ${#SERVICES[@]} -eq 0 ]; then
    SERVICES=("all")
fi

# Check if docker and docker compose are available
check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    # Check for docker compose (v2) or docker-compose (v1)
    if ! (docker compose version &> /dev/null || command -v docker-compose &> /dev/null); then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi

    # Check if user is in docker group or has sudo access
    if ! docker ps &> /dev/null; then
        log_error "Cannot access Docker. Please ensure you're in the docker group or run with sudo."
        exit 1
    fi

    log_success "Dependencies check passed"
}

# Helper function to run docker compose with correct command
docker_compose() {
    if command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    
    mkdir -p "$PROJECT_ROOT/logs/nginx"
    mkdir -p "$PROJECT_ROOT/logs/static"
    mkdir -p "$PROJECT_ROOT/logs/flutter"
    mkdir -p "$PROJECT_ROOT/logs/api"
    mkdir -p "$PROJECT_ROOT/certbot/www"
    mkdir -p "$PROJECT_ROOT/certbot/live"
    mkdir -p "$PROJECT_ROOT/certbot/archive"
    mkdir -p "$PROJECT_ROOT/certbot/logs"
    
    log_success "Directories created"
}

# Build Flutter web application on host (pre-build phase)
build_flutter_web() {
    log_info "Building Flutter web application on host..."

    cd "$PROJECT_ROOT"

    if [ ! -f "pubspec.yaml" ]; then
        log_error "pubspec.yaml not found. Please run this script from the Flutter project root."
        exit 1
    fi

    # Clean previous build
    log_info "Cleaning previous Flutter build..."
    flutter clean

    # Get dependencies
    log_info "Getting Flutter dependencies..."
    flutter pub get

    # Build for web (host-based build)
    log_info "Building Flutter web application..."
    flutter build web --release

    # Verify build output
    if [ ! -d "build/web" ]; then
        log_error "Flutter web build failed - build/web directory not found"
        exit 1
    fi

    log_success "Flutter web application built successfully on host"
    log_info "Build output available in: $PROJECT_ROOT/build/web/"
}

# Build documentation site (optional)
build_docs() {
    log_info "Building documentation site (optional)..."

    if [ -d "$PROJECT_ROOT/docs-site" ]; then
        cd "$PROJECT_ROOT/docs-site"

        if [ -f "package.json" ]; then
            # Check if package-lock.json exists, if not run npm install first
            if [ ! -f "package-lock.json" ]; then
                log_info "No package-lock.json found, running npm install..."
                npm install || {
                    log_warning "npm install failed, skipping docs build"
                    return 0
                }
            fi
            npm ci && npm run build || {
                log_warning "Documentation build failed, continuing without docs"
                return 0
            }
            log_success "Documentation site built"
        else
            log_warning "Documentation package.json not found, skipping docs build"
        fi
    else
        log_warning "Documentation site directory not found, skipping docs build"
    fi
}

# Set up SSL certificates
setup_ssl() {
    log_info "Setting up SSL certificates..."

    cd "$PROJECT_ROOT"

    # Run certbot container
    docker_compose -f "$COMPOSE_FILE" --profile ssl-setup run --rm certbot

    log_success "SSL certificates set up"
}

# Pull latest images
pull_images() {
    if [ "$PULL" = true ]; then
        log_info "Pulling latest base images..."
        docker_compose -f "$COMPOSE_FILE" pull
        log_success "Images pulled"
    fi
}

# Build containers
build_containers() {
    local build_args=""

    if [ "$NO_CACHE" = true ]; then
        build_args="--no-cache"
    fi

    if [ "$BUILD" = true ] || [ "$NO_CACHE" = true ]; then
        log_info "Building containers..."

        if [ "${SERVICES[0]}" = "all" ]; then
            docker_compose -f "$COMPOSE_FILE" build $build_args
        else
            docker_compose -f "$COMPOSE_FILE" build $build_args "${SERVICES[@]}"
        fi

        log_success "Containers built"
    fi
}

# Deploy services
deploy_services() {
    log_info "Deploying services..."

    cd "$PROJECT_ROOT"

    if [ "${SERVICES[0]}" = "all" ]; then
        docker_compose -f "$COMPOSE_FILE" up -d
    else
        docker_compose -f "$COMPOSE_FILE" up -d "${SERVICES[@]}"
    fi

    log_success "Services deployed"
}

# Check service health
check_health() {
    log_info "Checking service health..."
    
    # Wait a moment for services to start
    sleep 10
    
    # Check each service
    local services_to_check=("nginx-proxy" "static-site" "flutter-app" "api-backend")
    
    if [ "${SERVICES[0]}" != "all" ]; then
        services_to_check=("${SERVICES[@]}")
    fi
    
    for service in "${services_to_check[@]}"; do
        if docker_compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up (healthy)"; then
            log_success "$service is healthy"
        elif docker_compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            log_warning "$service is running but health check pending"
        else
            log_error "$service is not running properly"
        fi
    done
}

# Show logs
show_logs() {
    if [ "$SHOW_LOGS" = true ]; then
        log_info "Showing service logs..."

        if [ "${SERVICES[0]}" = "all" ]; then
            docker_compose -f "$COMPOSE_FILE" logs -f --tail=50
        else
            docker_compose -f "$COMPOSE_FILE" logs -f --tail=50 "${SERVICES[@]}"
        fi
    fi
}

# Show deployment summary
show_summary() {
    log_info "Deployment Summary"
    log_info "=================="
    
    echo ""
    log_info "Services Status:"
    docker_compose -f "$COMPOSE_FILE" ps

    echo ""
    log_info "URLs:"
    log_info "  Main Website: https://cloudtolocalllm.online"
    log_info "  Documentation: https://docs.cloudtolocalllm.online"
    log_info "  Web Application: https://app.cloudtolocalllm.online"
    log_info "  API Backend: https://app.cloudtolocalllm.online/api/"

    echo ""
    log_info "Architecture:"
    log_info "  ✓ Host-based Flutter build (optimized)"
    log_info "  ✓ Lightweight nginx containers (runtime only)"
    log_info "  ✓ Dedicated API backend for bridge communication"
    log_info "  ✓ Reverse proxy with SSL termination"

    echo ""
    log_info "Useful Commands:"
    log_info "  View logs: docker_compose -f $COMPOSE_FILE logs -f [service]"
    log_info "  Restart service: docker_compose -f $COMPOSE_FILE restart [service]"
    log_info "  Stop all: docker_compose -f $COMPOSE_FILE down"
    log_info "  Update service: $0 --build [service]"
    log_info "  Rebuild Flutter: flutter build web --release && $0 --build flutter-app"
}

# Main deployment process
main() {
    log_info "CloudToLocalLLM Multi-Container Deployment"
    log_info "=========================================="
    
    check_dependencies
    create_directories
    
    # Build applications if needed
    if [[ " ${SERVICES[@]} " =~ " flutter-app " ]] || [[ " ${SERVICES[@]} " =~ " all " ]]; then
        build_flutter_web
    fi
    
    if [[ " ${SERVICES[@]} " =~ " static-site " ]] || [[ " ${SERVICES[@]} " =~ " all " ]]; then
        build_docs
    fi
    
    # Set up SSL if requested
    if [ "$SSL_SETUP" = true ]; then
        setup_ssl
    fi
    
    pull_images
    build_containers
    deploy_services
    check_health
    show_summary
    show_logs
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"
