#!/bin/bash

# Push CloudToLocalLLM Multi-Container Architecture to Live - Automated Mode
# This script runs in fully automated mode without interactive prompts
# All deployment decisions must be made through command-line arguments

set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PATH="/opt/cloudtolocalllm"

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
CloudToLocalLLM Live Deployment Script - Automated Mode

Usage: $0 [options]

Options:
  -f, --force           Skip all safety checks and proceed with deployment
  -s, --skip-backup     Skip backup creation to speed up deployment
  -v, --verbose         Enable detailed logging output
  -d, --dry-run         Show what would be deployed without executing
  --ssl-renew           Renew SSL certificates during deployment
  --rollback            Rollback to previous deployment
  --status              Check current deployment status only
  -h, --help            Show this help message

Deployment Modes:
  $0                    # Standard automated deployment (includes backup)
  $0 --force            # Fast deployment, skip safety checks
  $0 --skip-backup      # Deploy without creating backup
  $0 --dry-run          # Preview deployment actions
  $0 --verbose          # Detailed logging for troubleshooting

Examples:
  $0                                    # Standard automated deployment
  $0 --force --skip-backup              # Fastest deployment
  $0 --verbose --dry-run                # Preview with detailed output
  $0 --status                           # Check current status
  $0 --rollback --force                 # Emergency rollback

Note: This script runs in fully automated mode without interactive prompts.
All deployment decisions must be made through command-line arguments.

EOF
}

# Parse command line arguments
BACKUP=true          # Default to creating backup for safety
FORCE=false
SKIP_BACKUP=false
VERBOSE=false
DRY_RUN=false
SSL_RENEW=false
ROLLBACK=false
STATUS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -s|--skip-backup)
            SKIP_BACKUP=true
            BACKUP=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --ssl-renew)
            SSL_RENEW=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        --status)
            STATUS_ONLY=true
            shift
            ;;
        -h|--help)
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

# Apply verbose logging if requested
if [ "$VERBOSE" = true ]; then
    set -x
    log_info "Verbose logging enabled"
fi

# Show dry-run notice
if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN MODE: No actual changes will be made"
    log_info "This will show what would be deployed without executing"
fi

# Validate prerequisites
validate_prerequisites() {
    local errors=0

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would validate prerequisites"
        return 0
    fi

    log_info "Validating prerequisites..."

    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a Git repository"
        ((errors++))
    fi

    # Check if we have uncommitted changes (unless force mode)
    if [ "$FORCE" = false ] && ! git diff --quiet; then
        log_warning "You have uncommitted changes"
        if [ "$VERBOSE" = true ]; then
            git status --porcelain
        fi
    fi

    # Check required commands
    for cmd in git ssh curl docker; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            ((errors++))
        fi
    done

    # Check if we can reach GitHub
    if ! curl -s --connect-timeout 5 https://github.com > /dev/null; then
        log_warning "Cannot reach GitHub - network connectivity may be limited"
    fi

    if [ $errors -gt 0 ]; then
        log_error "Prerequisites validation failed with $errors errors"
        exit 1
    fi

    log_success "Prerequisites validation passed"
}

# Check if we can connect to VPS
check_vps_connection() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would check VPS connection to $VPS_USER@$VPS_HOST"
        return 0
    fi

    log_info "Checking VPS connection..."

    if ! ssh -o ConnectTimeout=10 "$VPS_USER@$VPS_HOST" "echo 'Connection successful'" &> /dev/null; then
        log_error "Cannot connect to VPS: $VPS_USER@$VPS_HOST"
        log_error "Please check your SSH configuration and VPS status"
        exit 1
    fi

    log_success "VPS connection verified"
}

# Check current deployment status
check_deployment_status() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would check current deployment status on VPS"
        return 0
    fi

    log_info "Checking current deployment status..."

    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        cd /opt/cloudtolocalllm
        
        echo "=== Git Status ==="
        git status --porcelain
        git log --oneline -5
        
        echo -e "\n=== Docker Status ==="
        if [ -f "docker-compose.multi.yml" ]; then
            echo "Multi-container architecture detected"
            docker compose -f docker-compose.multi.yml ps 2>/dev/null || docker-compose -f docker-compose.multi.yml ps 2>/dev/null || echo "Could not check multi-container status"
        elif [ -f "docker-compose.yml" ]; then
            echo "Legacy single container detected"
            docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null || echo "Could not check container status"
        else
            echo "No docker-compose configuration found"
        fi
        
        echo -e "\n=== System Resources ==="
        df -h /opt/cloudtolocalllm
        free -h
        
        echo -e "\n=== SSL Certificates ==="
        if [ -d "certbot/live/cloudtolocalllm.online" ]; then
            ls -la certbot/live/cloudtolocalllm.online/
            openssl x509 -in certbot/live/cloudtolocalllm.online/fullchain.pem -noout -dates 2>/dev/null || echo "Certificate check failed"
        else
            echo "SSL certificates not found"
        fi
EOF
}

# Create backup on VPS
create_backup() {
    if [ "$SKIP_BACKUP" = true ]; then
        log_info "Skipping backup creation (--skip-backup specified)"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create backup on VPS"
        return 0
    fi

    if [ "$BACKUP" = true ]; then
        log_info "Creating backup on VPS..."

        ssh "$VPS_USER@$VPS_HOST" << 'EOF'
            cd /opt/cloudtolocalllm
            
            # Create backup directory
            BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            
            # Backup current containers
            if docker-compose ps -q | grep -q .; then
                echo "Backing up running containers..."
                docker-compose ps --format "table {{.Name}}\t{{.Image}}\t{{.Status}}" > "$BACKUP_DIR/containers.txt"
                
                # Export container images
                for container in $(docker-compose ps -q); do
                    container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
                    echo "Backing up container: $container_name"
                    docker commit "$container" "$container_name:backup-$(date +%Y%m%d_%H%M%S)" || true
                done
            fi
            
            # Backup configuration files
            cp -r config/ "$BACKUP_DIR/" 2>/dev/null || true
            cp docker-compose*.yml "$BACKUP_DIR/" 2>/dev/null || true
            cp -r certbot/ "$BACKUP_DIR/" 2>/dev/null || true
            
            echo "Backup created in: $BACKUP_DIR"
            ls -la "$BACKUP_DIR"
EOF
        
        log_success "Backup created on VPS"
    fi
}

# Push code to VPS
push_code() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would push code to VPS:"
        log_info "  - Commit local changes"
        log_info "  - Push to GitHub"
        log_info "  - Pull changes on VPS"
        log_info "  - Make scripts executable"
        return 0
    fi

    log_info "Pushing code to VPS..."

    # First, commit and push to GitHub
    cd "$PROJECT_ROOT"

    log_info "Committing changes locally..."
    git add .
    git commit -m "Deploy v3.3.1 unified settings interface to production" || log_warning "No changes to commit"

    log_info "Pushing to GitHub..."
    git push origin master
    
    # Pull on VPS
    log_info "Pulling changes on VPS..."
    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        cd /opt/cloudtolocalllm
        
        # Stash any local changes
        git stash push -m "Auto-stash before deployment $(date)"
        
        # Pull latest changes
        git pull origin master
        
        # Make scripts executable
        chmod +x scripts/deploy/*.sh
        chmod +x scripts/desktop/*.sh
        
        echo "Code updated on VPS"
EOF
    
    log_success "Code pushed to VPS"
}

# Deploy multi-container architecture
deploy_multi_container() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would deploy multi-container architecture:"
        log_info "  - Stop existing containers"
        log_info "  - Build Flutter web application"
        log_info "  - Build documentation (if exists)"
        log_info "  - Install API backend dependencies"
        log_info "  - Deploy with multi-container script"
        return 0
    fi

    log_info "Deploying multi-container architecture..."

    ssh "$VPS_USER@$VPS_HOST" << EOF
        cd /opt/cloudtolocalllm
        
        # Stop existing containers
        if [ -f "docker-compose.yml" ]; then
            echo "Stopping legacy containers..."
            docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
        fi

        if [ -f "docker-compose.multi.yml" ]; then
            echo "Stopping existing multi-container deployment..."
            docker compose -f docker-compose.multi.yml down 2>/dev/null || docker-compose -f docker-compose.multi.yml down 2>/dev/null || true
        fi
        
        # Build Flutter web application
        echo "Building Flutter web application..."
        flutter pub get
        flutter build web --release
        
        # Build documentation if it exists
        if [ -d "docs-site" ] && [ -f "docs-site/package.json" ]; then
            echo "Building documentation..."
            cd docs-site
            npm ci
            npm run build
            cd ..
        fi
        
        # Install API backend dependencies
        if [ -f "api-backend/package.json" ]; then
            echo "Installing API backend dependencies..."
            cd api-backend
            npm ci --only=production
            cd ..
        fi
        
        # Deploy with multi-container script
        echo "Deploying multi-container architecture..."
        ./scripts/deploy/deploy-multi-container.sh --build $([ "$SSL_RENEW" = true ] && echo "--ssl-setup")
        
        echo "Deployment completed"
EOF
    
    log_success "Multi-container architecture deployed"
}

# Verify deployment
verify_deployment() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would verify deployment:"
        log_info "  - Check container status"
        log_info "  - Verify service health"
        log_info "  - Test URL accessibility"
        return 0
    fi

    log_info "Verifying deployment..."

    # Wait for services to start
    sleep 30
    
    # Check service health
    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        cd /opt/cloudtolocalllm
        
        echo "=== Container Status ==="
        docker compose -f docker-compose.multi.yml ps 2>/dev/null || docker-compose -f docker-compose.multi.yml ps 2>/dev/null || echo "Could not check container status"

        echo -e "\n=== Health Checks ==="
        for service in nginx-proxy static-site flutter-app api-backend; do
            if (docker compose -f docker-compose.multi.yml ps "$service" 2>/dev/null || docker-compose -f docker-compose.multi.yml ps "$service" 2>/dev/null) | grep -q "Up (healthy)"; then
                echo "✓ $service: Healthy"
            elif (docker compose -f docker-compose.multi.yml ps "$service" 2>/dev/null || docker-compose -f docker-compose.multi.yml ps "$service" 2>/dev/null) | grep -q "Up"; then
                echo "⚠ $service: Running (health check pending)"
            else
                echo "✗ $service: Not running"
            fi
        done

        echo -e "\n=== Service Logs (last 10 lines each) ==="
        for service in nginx-proxy static-site flutter-app api-backend; do
            echo "--- $service ---"
            docker compose -f docker-compose.multi.yml logs --tail=10 "$service" 2>/dev/null || docker-compose -f docker-compose.multi.yml logs --tail=10 "$service" 2>/dev/null || echo "No logs available for $service"
        done
EOF
    
    # Test URLs
    log_info "Testing URLs..."
    
    local urls=(
        "https://cloudtolocalllm.online"
        "https://docs.cloudtolocalllm.online"
        "https://app.cloudtolocalllm.online"
        "https://app.cloudtolocalllm.online/api/health"
    )
    
    for url in "${urls[@]}"; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|301\|302"; then
            log_success "✓ $url: Accessible"
        else
            log_warning "⚠ $url: Not accessible or returned error"
        fi
    done
}

# Rollback deployment
rollback_deployment() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would rollback deployment:"
        log_info "  - Find latest backup"
        log_info "  - Stop current containers"
        log_info "  - Restore configuration"
        log_info "  - Start containers"
        return 0
    fi

    log_info "Rolling back deployment..."

    ssh "$VPS_USER@$VPS_HOST" << 'EOF'
        cd /opt/cloudtolocalllm
        
        # Find latest backup
        LATEST_BACKUP=$(ls -1t backups/ | head -n 1)
        
        if [ -z "$LATEST_BACKUP" ]; then
            echo "No backup found for rollback"
            exit 1
        fi
        
        echo "Rolling back to: $LATEST_BACKUP"
        
        # Stop current containers
        docker-compose -f docker-compose.multi.yml down || true
        
        # Restore configuration
        cp -r "backups/$LATEST_BACKUP/config/" . 2>/dev/null || true
        cp "backups/$LATEST_BACKUP/docker-compose"*.yml . 2>/dev/null || true
        
        # Start containers
        if [ -f "docker-compose.multi.yml" ]; then
            docker-compose -f docker-compose.multi.yml up -d
        elif [ -f "docker-compose.yml" ]; then
            docker-compose up -d
        fi
        
        echo "Rollback completed"
EOF
    
    log_success "Rollback completed"
}

# Automated deployment confirmation (no interactive prompts)
confirm_deployment() {
    if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
        log_info "Automated deployment mode - proceeding with deployment"
        log_warning "Deploying multi-container architecture to PRODUCTION"
        log_info "This will:"
        echo "  • Stop existing containers"
        echo "  • Deploy new multi-container architecture"
        echo "  • Update all services (nginx-proxy, static-site, flutter-app, api-backend)"
        echo "  • Potentially cause brief downtime during transition"
        echo ""
        log_info "Proceeding automatically (use --dry-run to preview without executing)"
    elif [ "$FORCE" = true ]; then
        log_info "Force mode enabled - skipping safety checks"
    elif [ "$DRY_RUN" = true ]; then
        log_info "Dry run mode - no actual deployment will occur"
    fi
}

# Main deployment process
main() {
    log_info "CloudToLocalLLM Live Deployment - Automated Mode"
    log_info "================================================="

    # Show configuration
    if [ "$VERBOSE" = true ]; then
        log_info "Configuration:"
        log_info "  Force mode: $FORCE"
        log_info "  Skip backup: $SKIP_BACKUP"
        log_info "  Verbose: $VERBOSE"
        log_info "  Dry run: $DRY_RUN"
        log_info "  SSL renew: $SSL_RENEW"
        log_info "  Rollback: $ROLLBACK"
        log_info "  Status only: $STATUS_ONLY"
        echo ""
    fi

    # Validate prerequisites unless in status-only mode
    if [ "$STATUS_ONLY" = false ]; then
        validate_prerequisites
    fi

    check_vps_connection

    if [ "$STATUS_ONLY" = true ]; then
        check_deployment_status
        exit 0
    fi

    if [ "$ROLLBACK" = true ]; then
        confirm_deployment
        rollback_deployment
        verify_deployment
        exit 0
    fi

    # Standard deployment flow
    check_deployment_status
    confirm_deployment
    create_backup
    push_code
    deploy_multi_container
    verify_deployment

    if [ "$DRY_RUN" = true ]; then
        log_success "🎉 Dry run completed successfully!"
        log_info "No actual changes were made. Use without --dry-run to execute deployment."
    else
        log_success "🎉 Deployment completed successfully!"
        log_info ""
        log_info "URLs to test:"
        log_info "  • Main site: https://cloudtolocalllm.online"
        log_info "  • Documentation: https://docs.cloudtolocalllm.online"
        log_info "  • Web app: https://app.cloudtolocalllm.online"
        log_info "  • API health: https://app.cloudtolocalllm.online/api/health"
        log_info ""
        log_info "Monitor with:"
        log_info "  ssh $VPS_USER@$VPS_HOST 'cd /opt/cloudtolocalllm && docker-compose -f docker-compose.multi.yml logs -f'"
    fi
}

# Run main function
main "$@"
