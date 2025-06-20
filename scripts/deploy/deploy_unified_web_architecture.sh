#!/bin/bash

# CloudToLocalLLM Unified Flutter Web Architecture Deployment Script
# Version: 3.4.0+ - Complete unified architecture deployment
# Deploys the unified Flutter web architecture to production VPS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
BACKUP_DIR="/opt/cloudtolocalllm-backup-$(date +%Y%m%d-%H%M%S)"
COMPOSE_FILE="docker-compose.multi.yml"
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"

# Flags
FORCE=false
VERBOSE=false
SKIP_BACKUP=false
DRY_RUN=false
LOCAL_DEPLOY=false

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

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Unified Flutter Web Architecture Deployment

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force             Skip all confirmation prompts
    --verbose           Enable detailed logging
    --skip-backup       Skip backup creation for faster deployment
    --dry-run           Simulate deployment without actual changes
    --local             Deploy locally (for testing)
    --help              Show this help message

EXAMPLES:
    $0                  # Interactive VPS deployment
    $0 --force          # Fully automated VPS deployment
    $0 --local          # Local deployment for testing
    $0 --dry-run        # Simulate deployment

DEPLOYMENT FEATURES:
    âœ… Unified Flutter web architecture
    âœ… Single container for all web content
    âœ… Static-site container elimination
    âœ… Marketing pages in Flutter
    âœ… Documentation in Flutter
    âœ… Platform-specific routing (kIsWeb)
    âœ… Zero external container dependencies

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --local)
                LOCAL_DEPLOY=true
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
}

# Pre-deployment validation
validate_environment() {
    log_info "Validating deployment environment..."
    
    # Check if we're in the right directory
    if [[ ! -f "pubspec.yaml" ]] || [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Not in CloudToLocalLLM project directory"
        exit 1
    fi
    
    # Check required tools
    local required_tools=("flutter" "docker" "docker-compose")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
        log_verbose "âœ“ Tool available: $tool"
    done
    
    # Check unified architecture files
    local required_files=(
        "lib/screens/marketing/homepage_screen.dart"
        "lib/screens/marketing/download_screen.dart"
        "lib/screens/marketing/documentation_screen.dart"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required unified architecture file not found: $file"
            exit 1
        fi
        log_verbose "âœ“ Unified architecture file: $file"
    done
    
    # Check for static-site container removal
    if grep -q "container_name: cloudtolocalllm-static-site" "$COMPOSE_FILE" && ! grep -q "DEPRECATED" "$COMPOSE_FILE"; then
        log_error "Static-site container not properly deprecated in $COMPOSE_FILE"
        exit 1
    fi
    
    log_success "Environment validation completed"
}

# Build Flutter web application
build_flutter_web() {
    log_info "Building Flutter web application..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would build Flutter web application"
        return 0
    fi
    
    # Clean previous build
    log_verbose "Cleaning previous Flutter build..."
    flutter clean
    
    # Get dependencies
    log_verbose "Getting Flutter dependencies..."
    flutter pub get
    
    # Build web application
    log_verbose "Building Flutter web application..."
    if [[ "$VERBOSE" == "true" ]]; then
        flutter build web --release --no-tree-shake-icons
    else
        flutter build web --release --no-tree-shake-icons > /dev/null 2>&1
    fi
    
    # Verify build output
    if [[ ! -f "build/web/main.dart.js" ]]; then
        log_error "Flutter web build failed - main.dart.js not found"
        exit 1
    fi
    
    log_success "Flutter web application built successfully"
}

# Deploy locally (for testing)
deploy_local() {
    log_info "Deploying unified architecture locally..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would deploy locally"
        return 0
    fi
    
    # Stop existing containers
    log_verbose "Stopping existing containers..."
    docker-compose -f "$COMPOSE_FILE" down --timeout 30 || true
    
    # Build and start containers
    log_verbose "Building and starting containers..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for containers to be ready
    sleep 10
    
    # Verify deployment
    verify_local_deployment
    
    log_success "Local deployment completed"
}

# Deploy to VPS
deploy_vps() {
    log_info "Deploying unified architecture to VPS..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would deploy to VPS"
        return 0
    fi
    
    # Test SSH connection
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS_USER@$VPS_HOST" "echo 'SSH test'" &> /dev/null; then
        log_error "SSH connection to VPS failed"
        exit 1
    fi
    
    # Execute deployment on VPS
    log_verbose "Executing deployment on VPS..."
    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        set -e
        cd /opt/cloudtolocalllm
        
        echo "ðŸ”„ Pulling latest changes..."
        git pull origin master
        
        echo "ðŸ—ï¸ Building Flutter web application..."
        flutter clean
        flutter pub get
        flutter build web --release --no-tree-shake-icons
        
        echo "ðŸ³ Restarting Docker containers..."
        docker-compose -f docker-compose.multi.yml down --timeout 30
        docker-compose -f docker-compose.multi.yml build --no-cache
        docker-compose -f docker-compose.multi.yml up -d
        
        echo "â³ Waiting for containers to be ready..."
        sleep 15
        
        echo "âœ… VPS deployment completed"
EOF
    
    # Verify VPS deployment
    verify_vps_deployment
    
    log_success "VPS deployment completed"
}

# Verify local deployment
verify_local_deployment() {
    log_info "Verifying local deployment..."
    
    # Check container status
    local running_containers=$(docker-compose -f "$COMPOSE_FILE" ps --services --filter "status=running" | wc -l)
    local total_containers=$(docker-compose -f "$COMPOSE_FILE" ps --services | wc -l)
    
    if [[ "$running_containers" -eq "$total_containers" ]]; then
        log_success "All containers are running ($running_containers/$total_containers)"
    else
        log_error "Some containers are not running ($running_containers/$total_containers)"
        docker-compose -f "$COMPOSE_FILE" ps
        return 1
    fi
    
    # Test Flutter app accessibility
    if docker exec cloudtolocalllm-flutter-app curl -s -f http://localhost/ > /dev/null 2>&1; then
        log_success "Flutter app is accessible"
    else
        log_error "Flutter app is not accessible"
        return 1
    fi
    
    log_success "Local deployment verification passed"
}

# Verify VPS deployment
verify_vps_deployment() {
    log_info "Verifying VPS deployment..."
    
    # Test main domain (Flutter homepage)
    local main_response=$(curl -s -o /dev/null -w "%{http_code}" "https://$VPS_HOST" || echo "000")
    if [[ "$main_response" =~ ^(200|301|302)$ ]]; then
        log_success "Main domain accessible (HTTP $main_response)"
    else
        log_error "Main domain not accessible (HTTP $main_response)"
        return 1
    fi
    
    # Test app subdomain (Flutter chat interface)
    local app_response=$(curl -s -o /dev/null -w "%{http_code}" "https://app.$VPS_HOST" || echo "000")
    if [[ "$app_response" =~ ^(200|301|302)$ ]]; then
        log_success "App subdomain accessible (HTTP $app_response)"
    else
        log_error "App subdomain not accessible (HTTP $app_response)"
        return 1
    fi
    
    # Test docs subdomain (Flutter documentation)
    local docs_response=$(curl -s -o /dev/null -w "%{http_code}" "https://docs.$VPS_HOST" || echo "000")
    if [[ "$docs_response" =~ ^(200|301|302)$ ]]; then
        log_success "Docs subdomain accessible (HTTP $docs_response)"
    else
        log_error "Docs subdomain not accessible (HTTP $docs_response)"
        return 1
    fi
    
    log_success "VPS deployment verification passed"
}

# Show deployment summary
show_summary() {
    echo ""
    echo -e "${GREEN}ðŸŽ‰ CloudToLocalLLM Unified Flutter Web Architecture Deployed!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo -e "${BLUE}ðŸ“‹ Deployment Summary:${NC}"
    echo "  âœ… Architecture: Unified Flutter Web"
    echo "  âœ… Static-site container: Eliminated"
    echo "  âœ… Marketing pages: Flutter-native"
    echo "  âœ… Documentation: Flutter-native"
    echo "  âœ… Platform detection: kIsWeb routing"
    echo ""
    
    if [[ "$LOCAL_DEPLOY" == "true" ]]; then
        echo -e "${BLUE}ðŸ“‹ Local Endpoints:${NC}"
        echo "  â€¢ Flutter App: http://localhost (via Docker)"
        echo "  â€¢ Container Status: docker-compose -f $COMPOSE_FILE ps"
        echo "  â€¢ Logs: docker-compose -f $COMPOSE_FILE logs -f"
    else
        echo -e "${BLUE}ðŸ“‹ Production Endpoints:${NC}"
        echo "  â€¢ Homepage: https://$VPS_HOST (Flutter marketing)"
        echo "  â€¢ Web App: https://app.$VPS_HOST (Flutter chat)"
        echo "  â€¢ Documentation: https://docs.$VPS_HOST (Flutter docs)"
        echo "  â€¢ API Health: https://app.$VPS_HOST/api/health"
    fi
    
    echo ""
    echo -e "${BLUE}ðŸ“‹ Architecture Benefits:${NC}"
    echo "  â€¢ Single Flutter application for all web content"
    echo "  â€¢ Consistent Material Design 3 theming"
    echo "  â€¢ Simplified deployment and maintenance"
    echo "  â€¢ Reduced infrastructure complexity"
    echo "  â€¢ Zero external container dependencies"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}CloudToLocalLLM Unified Flutter Web Architecture Deployment${NC}"
    echo -e "${BLUE}==========================================================${NC}"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Confirmation prompt (unless force or dry-run)
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        if [[ "$LOCAL_DEPLOY" == "true" ]]; then
            echo -e "${YELLOW}âš ï¸  About to deploy unified architecture locally${NC}"
        else
            echo -e "${YELLOW}âš ï¸  About to deploy unified architecture to production VPS${NC}"
        fi
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Execute deployment
    validate_environment
    build_flutter_web
    
    if [[ "$LOCAL_DEPLOY" == "true" ]]; then
        deploy_local
    else
        deploy_vps
    fi
    
    show_summary
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO. Check logs above for details."' ERR

# Execute main function
main "$@"
