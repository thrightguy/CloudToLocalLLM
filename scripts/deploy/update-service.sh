#!/bin/bash

# Service-Specific Update Script for CloudToLocalLLM Multi-Container Architecture
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
CloudToLocalLLM Service Update Script

Usage: $0 <service> [options]

Services:
  nginx-proxy       Update nginx reverse proxy
  static-site       Update static website and documentation
  flutter-app       Update Flutter web application
  api-backend       Update API backend

Options:
  --no-downtime     Use rolling update strategy (where possible)
  --backup          Create backup before update
  --rollback        Rollback to previous version
  --logs            Show logs after update
  --help            Show this help message

Examples:
  $0 flutter-app                    # Update Flutter app
  $0 static-site --no-downtime      # Update static site with minimal downtime
  $0 api-backend --backup           # Update API backend with backup
  $0 nginx-proxy --rollback         # Rollback nginx proxy

EOF
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

SERVICE="$1"
shift

NO_DOWNTIME=false
BACKUP=false
ROLLBACK=false
SHOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-downtime)
            NO_DOWNTIME=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
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
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate service name
case $SERVICE in
    nginx-proxy|static-site|flutter-app|api-backend)
        ;;
    *)
        log_error "Invalid service: $SERVICE"
        show_usage
        exit 1
        ;;
esac

# Check if service is running
check_service_status() {
    if ! docker-compose -f "$COMPOSE_FILE" ps "$SERVICE" | grep -q "Up"; then
        log_warning "Service $SERVICE is not currently running"
        return 1
    fi
    return 0
}

# Create backup
create_backup() {
    if [ "$BACKUP" = true ]; then
        log_info "Creating backup for $SERVICE..."
        
        local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        # Export current container
        local container_name="cloudtolocalllm-$SERVICE"
        if docker ps -q -f name="$container_name" | grep -q .; then
            docker commit "$container_name" "$container_name:backup-$(date +%Y%m%d_%H%M%S)"
            log_success "Backup created for $SERVICE"
        else
            log_warning "Container $container_name not found, skipping backup"
        fi
    fi
}

# Build application-specific assets
build_assets() {
    case $SERVICE in
        flutter-app)
            log_info "Building Flutter web application..."
            cd "$PROJECT_ROOT"
            flutter pub get
            flutter build web --release --web-renderer html
            log_success "Flutter web application built"
            ;;
        static-site)
            log_info "Building documentation site..."
            if [ -d "$PROJECT_ROOT/docs-site" ] && [ -f "$PROJECT_ROOT/docs-site/package.json" ]; then
                cd "$PROJECT_ROOT/docs-site"
                npm ci
                npm run build
                log_success "Documentation site built"
            else
                log_warning "Documentation site not found, skipping build"
            fi
            ;;
        api-backend)
            log_info "Installing API backend dependencies..."
            if [ -f "$PROJECT_ROOT/api-backend/package.json" ]; then
                cd "$PROJECT_ROOT/api-backend"
                npm ci --only=production
                log_success "API backend dependencies installed"
            fi
            ;;
        nginx-proxy)
            log_info "No build step required for nginx-proxy"
            ;;
    esac
}

# Update service with zero-downtime strategy
update_with_zero_downtime() {
    log_info "Updating $SERVICE with zero-downtime strategy..."
    
    case $SERVICE in
        nginx-proxy)
            # For nginx, we need to be careful as it's the entry point
            log_warning "Zero-downtime update for nginx-proxy requires careful coordination"
            log_info "Reloading nginx configuration..."
            docker-compose -f "$COMPOSE_FILE" exec nginx-proxy nginx -s reload
            ;;
        static-site|flutter-app)
            # These can be updated with minimal downtime
            local temp_service="${SERVICE}-temp"
            
            # Start temporary container
            log_info "Starting temporary container..."
            docker-compose -f "$COMPOSE_FILE" up -d --scale "$SERVICE"=2 "$SERVICE"
            
            # Wait for health check
            sleep 10
            
            # Stop old container
            log_info "Stopping old container..."
            docker-compose -f "$COMPOSE_FILE" up -d --scale "$SERVICE"=1 "$SERVICE"
            ;;
        api-backend)
            # API backend can be updated with rolling restart
            log_info "Performing rolling restart..."
            docker-compose -f "$COMPOSE_FILE" restart "$SERVICE"
            ;;
    esac
}

# Standard update (with brief downtime)
update_standard() {
    log_info "Updating $SERVICE with standard strategy..."
    
    # Stop service
    docker-compose -f "$COMPOSE_FILE" stop "$SERVICE"
    
    # Rebuild and start
    docker-compose -f "$COMPOSE_FILE" build "$SERVICE"
    docker-compose -f "$COMPOSE_FILE" up -d "$SERVICE"
}

# Rollback service
rollback_service() {
    log_info "Rolling back $SERVICE..."
    
    # Find latest backup
    local backup_image=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "cloudtolocalllm-$SERVICE:backup-" | head -n 1)
    
    if [ -z "$backup_image" ]; then
        log_error "No backup found for $SERVICE"
        exit 1
    fi
    
    log_info "Rolling back to: $backup_image"
    
    # Stop current service
    docker-compose -f "$COMPOSE_FILE" stop "$SERVICE"
    
    # Tag backup as latest
    docker tag "$backup_image" "cloudtolocalllm-$SERVICE:latest"
    
    # Start service
    docker-compose -f "$COMPOSE_FILE" up -d "$SERVICE"
    
    log_success "Rollback completed"
}

# Check service health after update
check_health() {
    log_info "Checking service health..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps "$SERVICE" | grep -q "Up (healthy)"; then
            log_success "$SERVICE is healthy"
            return 0
        elif docker-compose -f "$COMPOSE_FILE" ps "$SERVICE" | grep -q "Up"; then
            log_info "Waiting for health check... (attempt $attempt/$max_attempts)"
        else
            log_error "$SERVICE failed to start"
            return 1
        fi
        
        sleep 5
        ((attempt++))
    done
    
    log_warning "$SERVICE health check timed out"
    return 1
}

# Show service logs
show_logs() {
    if [ "$SHOW_LOGS" = true ]; then
        log_info "Showing logs for $SERVICE..."
        docker-compose -f "$COMPOSE_FILE" logs -f --tail=50 "$SERVICE"
    fi
}

# Show update summary
show_summary() {
    log_info "Update Summary for $SERVICE"
    log_info "============================"
    
    echo ""
    log_info "Service Status:"
    docker-compose -f "$COMPOSE_FILE" ps "$SERVICE"
    
    echo ""
    log_info "Recent Logs:"
    docker-compose -f "$COMPOSE_FILE" logs --tail=10 "$SERVICE"
    
    echo ""
    case $SERVICE in
        nginx-proxy)
            log_info "Nginx proxy updated. All traffic routing should be working."
            ;;
        static-site)
            log_info "Static site updated. Documentation and homepage are refreshed."
            log_info "Visit: https://cloudtolocalllm.online and https://docs.cloudtolocalllm.online"
            ;;
        flutter-app)
            log_info "Flutter app updated. Web application has been refreshed."
            log_info "Visit: https://app.cloudtolocalllm.online"
            ;;
        api-backend)
            log_info "API backend updated. Bridge communication should be working."
            ;;
    esac
}

# Main update process
main() {
    log_info "CloudToLocalLLM Service Update: $SERVICE"
    log_info "========================================"
    
    cd "$PROJECT_ROOT"
    
    if [ "$ROLLBACK" = true ]; then
        rollback_service
    else
        create_backup
        build_assets
        
        if [ "$NO_DOWNTIME" = true ]; then
            update_with_zero_downtime
        else
            update_standard
        fi
    fi
    
    check_health
    show_summary
    show_logs
    
    log_success "Service update completed successfully!"
}

# Run main function
main "$@"
