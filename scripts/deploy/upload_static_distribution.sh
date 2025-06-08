#!/bin/bash

# CloudToLocalLLM Static Distribution Upload Script v3.4.0+
# Uploads package to static download location with integrity validation
# Supports non-interactive execution for CI/CD pipelines

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"

# VPS Configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_DOWNLOAD_DIR="/opt/cloudtolocalllm/static_homepage/downloads"

# Flags
DRY_RUN=false
VERBOSE=false
FORCE=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [VERBOSE]${NC} $1"
    fi
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Static Distribution Upload Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run           Simulate upload without actual file transfer
    --verbose           Enable detailed logging
    --force             Force upload without confirmation prompts
    --help              Show this help message

EXAMPLES:
    $0                  # Non-interactive upload with 3-second delay
    $0 --dry-run        # Simulate upload
    $0 --force          # Upload without prompts (CI/CD compatible)
    $0 --verbose        # Detailed logging

EXIT CODES:
    0 - Success
    1 - General error
    2 - Validation failure
    3 - Upload failure
    4 - Verification failure
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE=true
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check if dist directory exists
    if [[ ! -d "$DIST_DIR" ]]; then
        log_error "Distribution directory not found: $DIST_DIR"
        exit 2
    fi

    # Check for required tools
    for tool in scp ssh; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 2
        fi
    done

    # Test SSH connection
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS_USER@$VPS_HOST" "echo 'SSH connection test'" &> /dev/null; then
        log_error "SSH connection to $VPS_USER@$VPS_HOST failed"
        log_error "Please ensure SSH key authentication is configured"
        exit 2
    fi

    log_success "Prerequisites check passed"
}

# Find package files
find_package_files() {
    log "Finding package files..."

    # Get current version
    local version=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *\([0-9.]*\).*/\1/')
    
    # Find package files
    PACKAGE_FILE="$DIST_DIR/cloudtolocalllm-$version-x86_64.tar.gz"
    CHECKSUM_FILE="$PACKAGE_FILE.sha256"
    AUR_INFO_FILE="$DIST_DIR/cloudtolocalllm-$version-x86_64-aur-info.txt"

    log_verbose "Package file: $PACKAGE_FILE"
    log_verbose "Checksum file: $CHECKSUM_FILE"
    log_verbose "AUR info file: $AUR_INFO_FILE"

    # Verify files exist
    if [[ ! -f "$PACKAGE_FILE" ]]; then
        log_error "Package file not found: $PACKAGE_FILE"
        exit 2
    fi

    if [[ ! -f "$CHECKSUM_FILE" ]]; then
        log_error "Checksum file not found: $CHECKSUM_FILE"
        exit 2
    fi

    local package_size=$(du -h "$PACKAGE_FILE" | cut -f1)
    log_success "Package files found (Size: $package_size)"
}

# Validate package integrity
validate_package_integrity() {
    log "Validating package integrity..."

    cd "$DIST_DIR"

    # Verify checksum
    if ! sha256sum -c "$(basename "$CHECKSUM_FILE")" &> /dev/null; then
        log_error "Package integrity validation failed"
        exit 2
    fi

    log_success "Package integrity validation passed"
}

# Create remote directory structure
create_remote_structure() {
    log "Creating remote directory structure..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would create directory: $VPS_DOWNLOAD_DIR"
        log_success "DRY RUN: Remote structure creation simulated"
        return 0
    fi

    # Create download directory on VPS
    ssh "$VPS_USER@$VPS_HOST" "mkdir -p $VPS_DOWNLOAD_DIR"

    log_success "Remote directory structure created"
}

# Upload package files
upload_files() {
    log "Uploading package files..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would upload files to $VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR"
        log "DRY RUN: - $(basename "$PACKAGE_FILE")"
        log "DRY RUN: - $(basename "$CHECKSUM_FILE")"
        if [[ -f "$AUR_INFO_FILE" ]]; then
            log "DRY RUN: - $(basename "$AUR_INFO_FILE")"
        fi
        log_success "DRY RUN: File upload simulation completed"
        return 0
    fi

    # Upload package file
    log_verbose "Uploading package file..."
    if [[ "$VERBOSE" == "true" ]]; then
        scp "$PACKAGE_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/"
    else
        scp "$PACKAGE_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/" &> /dev/null
    fi

    # Upload checksum file
    log_verbose "Uploading checksum file..."
    if [[ "$VERBOSE" == "true" ]]; then
        scp "$CHECKSUM_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/"
    else
        scp "$CHECKSUM_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/" &> /dev/null
    fi

    # Upload AUR info file if it exists
    if [[ -f "$AUR_INFO_FILE" ]]; then
        log_verbose "Uploading AUR info file..."
        if [[ "$VERBOSE" == "true" ]]; then
            scp "$AUR_INFO_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/"
        else
            scp "$AUR_INFO_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/" &> /dev/null
        fi
    fi

    log_success "File upload completed"
}

# Verify remote upload
verify_remote_upload() {
    log "Verifying remote upload..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would verify files on remote server"
        log_success "DRY RUN: Remote verification simulation completed"
        return 0
    fi

    local package_basename=$(basename "$PACKAGE_FILE")
    local checksum_basename=$(basename "$CHECKSUM_FILE")

    # Check if files exist on remote server
    if ! ssh "$VPS_USER@$VPS_HOST" "test -f $VPS_DOWNLOAD_DIR/$package_basename"; then
        log_error "Package file not found on remote server"
        exit 4
    fi

    if ! ssh "$VPS_USER@$VPS_HOST" "test -f $VPS_DOWNLOAD_DIR/$checksum_basename"; then
        log_error "Checksum file not found on remote server"
        exit 4
    fi

    # Verify checksum on remote server
    if ! ssh "$VPS_USER@$VPS_HOST" "cd $VPS_DOWNLOAD_DIR && sha256sum -c $checksum_basename" &> /dev/null; then
        log_error "Remote checksum verification failed"
        exit 4
    fi

    log_success "Remote upload verification passed"
}

# Update download page metadata
update_download_metadata() {
    log "Updating download page metadata..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would update download page metadata"
        log_success "DRY RUN: Metadata update simulation completed"
        return 0
    fi

    local version=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *\([0-9.]*\).*/\1/')
    local package_basename=$(basename "$PACKAGE_FILE")
    local package_size=$(ssh "$VPS_USER@$VPS_HOST" "du -h $VPS_DOWNLOAD_DIR/$package_basename | cut -f1")

    # Create/update download metadata
    ssh "$VPS_USER@$VPS_HOST" "cat > $VPS_DOWNLOAD_DIR/latest.json << EOF
{
  \"version\": \"$version\",
  \"package_file\": \"$package_basename\",
  \"package_size\": \"$package_size\",
  \"upload_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"download_url\": \"https://cloudtolocalllm.online/$package_basename\"
}
EOF"

    log_success "Download metadata updated"
}

# Set proper permissions
set_remote_permissions() {
    log "Setting remote file permissions..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would set file permissions on remote server"
        log_success "DRY RUN: Permission setting simulation completed"
        return 0
    fi

    # Set proper permissions for web access
    ssh "$VPS_USER@$VPS_HOST" "chmod 644 $VPS_DOWNLOAD_DIR/*"

    log_success "Remote file permissions set"
}

# Display upload summary
display_summary() {
    local version=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *\([0-9.]*\).*/\1/')
    local package_basename=$(basename "$PACKAGE_FILE")
    
    echo ""
    echo -e "${GREEN}📦 Upload Summary${NC}"
    echo -e "${GREEN}=================${NC}"
    echo "Version: $version"
    echo "Package: $package_basename"
    echo "Download URL: https://cloudtolocalllm.online/$package_basename"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}📋 DRY RUN completed - no actual upload performed${NC}"
    else
        echo -e "${BLUE}📋 Next steps:${NC}"
        echo "  1. Update AUR PKGBUILD to use static download URL"
        echo "  2. Test AUR package build locally"
        echo "  3. Submit updated PKGBUILD to AUR"
        echo "  4. Deploy web application to VPS"
    fi
}

# Main execution
main() {
    # Header
    echo -e "${BLUE}CloudToLocalLLM Static Distribution Upload${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo "Target: $VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR"
    echo "Dry Run: $DRY_RUN"
    echo ""

    # Execute upload phases
    check_prerequisites
    find_package_files
    validate_package_integrity
    
    # Non-interactive execution - no prompts allowed
    # Use --force flag to bypass safety checks in automated environments
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        log_warning "Production upload starting without --force flag"
        log_warning "Use --force flag for automated/CI environments"
        log "Proceeding with upload in 3 seconds..."
        sleep 3
    fi
    
    create_remote_structure
    upload_files
    verify_remote_upload
    update_download_metadata
    set_remote_permissions
    display_summary

    echo ""
    log_success "🎉 Static distribution upload completed successfully!"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Check logs above for details."' ERR

# Parse arguments and execute
parse_arguments "$@"
main "$@"
