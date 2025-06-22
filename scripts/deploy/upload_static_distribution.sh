#!/bin/bash

# CloudToLocalLLM Distribution Upload Script v3.5.6+
# Uploads package to download location for Flutter-native homepage
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
VPS_DOWNLOAD_DIR="/opt/cloudtolocalllm/downloads"

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

    # Initialize arrays for multiple package types
    PACKAGE_FILES=()
    CHECKSUM_FILES=()

    # Define package patterns to look for
    local patterns=(
        "cloudtolocalllm-$version-x86_64.tar.gz"                    # Linux binary
        "cloudtolocalllm-$version-x86_64.AppImage"                  # Linux AppImage
        "cloudtolocalllm_${version}_amd64.deb"                      # Debian package
        "cloudtolocalllm-$version-windows-portable.zip"             # Windows portable
        "cloudtolocalllm-$version-windows-installer.msi"            # Windows installer
        "cloudtolocalllm-$version-macos.dmg"                        # macOS package
    )

    # Find all available packages
    for pattern in "${patterns[@]}"; do
        local package_file="$DIST_DIR/$pattern"
        local checksum_file="$package_file.sha256"

        if [[ -f "$package_file" ]]; then
            PACKAGE_FILES+=("$package_file")
            if [[ -f "$checksum_file" ]]; then
                CHECKSUM_FILES+=("$checksum_file")
            fi
            log_verbose "Found package: $pattern"
        fi
    done

    # Check for AUR info file
    AUR_INFO_FILE="$DIST_DIR/cloudtolocalllm-$version-x86_64-aur-info.txt"

    # Verify at least one package exists
    if [[ ${#PACKAGE_FILES[@]} -eq 0 ]]; then
        log_error "No package files found in $DIST_DIR"
        log_error "Expected patterns: ${patterns[*]}"
        exit 2
    fi

    log_success "Found ${#PACKAGE_FILES[@]} package file(s)"
}

# Validate package integrity
validate_package_integrity() {
    log "Validating package integrity..."

    cd "$DIST_DIR"

    # Verify checksums for all packages that have checksum files
    local validation_failed=false
    for checksum_file in "${CHECKSUM_FILES[@]}"; do
        local checksum_basename=$(basename "$checksum_file")
        if ! sha256sum -c "$checksum_basename" &> /dev/null; then
            log_error "Package integrity validation failed for $checksum_basename"
            validation_failed=true
        else
            log_verbose "Checksum validation passed for $checksum_basename"
        fi
    done

    if [[ "$validation_failed" == "true" ]]; then
        exit 2
    fi

    log_success "Package integrity validation passed for all packages"
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
        for package_file in "${PACKAGE_FILES[@]}"; do
            log "DRY RUN: - $(basename "$package_file")"
        done
        for checksum_file in "${CHECKSUM_FILES[@]}"; do
            log "DRY RUN: - $(basename "$checksum_file")"
        done
        if [[ -f "$AUR_INFO_FILE" ]]; then
            log "DRY RUN: - $(basename "$AUR_INFO_FILE")"
        fi
        log_success "DRY RUN: File upload simulation completed"
        return 0
    fi

    # Upload all package files
    for package_file in "${PACKAGE_FILES[@]}"; do
        local package_basename=$(basename "$package_file")
        log_verbose "Uploading package file: $package_basename"
        if [[ "$VERBOSE" == "true" ]]; then
            scp "$package_file" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/"
        else
            scp "$package_file" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/" &> /dev/null
        fi
    done

    # Upload all checksum files
    for checksum_file in "${CHECKSUM_FILES[@]}"; do
        local checksum_basename=$(basename "$checksum_file")
        log_verbose "Uploading checksum file: $checksum_basename"
        if [[ "$VERBOSE" == "true" ]]; then
            scp "$checksum_file" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/"
        else
            scp "$checksum_file" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/" &> /dev/null
        fi
    done

    # Upload AUR info file if it exists
    if [[ -f "$AUR_INFO_FILE" ]]; then
        log_verbose "Uploading AUR info file..."
        if [[ "$VERBOSE" == "true" ]]; then
            scp "$AUR_INFO_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/"
        else
            scp "$AUR_INFO_FILE" "$VPS_USER@$VPS_HOST:$VPS_DOWNLOAD_DIR/" &> /dev/null
        fi
    fi

    log_success "File upload completed (${#PACKAGE_FILES[@]} packages, ${#CHECKSUM_FILES[@]} checksums)"
}

# Verify remote upload
verify_remote_upload() {
    log "Verifying remote upload..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would verify files on remote server"
        log_success "DRY RUN: Remote verification simulation completed"
        return 0
    fi

    local verification_failed=false

    # Check if all package files exist on remote server
    for package_file in "${PACKAGE_FILES[@]}"; do
        local package_basename=$(basename "$package_file")
        if ! ssh "$VPS_USER@$VPS_HOST" "test -f $VPS_DOWNLOAD_DIR/$package_basename"; then
            log_error "Package file not found on remote server: $package_basename"
            verification_failed=true
        else
            log_verbose "Package file verified on remote: $package_basename"
        fi
    done

    # Check if all checksum files exist and verify them
    for checksum_file in "${CHECKSUM_FILES[@]}"; do
        local checksum_basename=$(basename "$checksum_file")
        if ! ssh "$VPS_USER@$VPS_HOST" "test -f $VPS_DOWNLOAD_DIR/$checksum_basename"; then
            log_error "Checksum file not found on remote server: $checksum_basename"
            verification_failed=true
        else
            # Verify checksum on remote server
            if ! ssh "$VPS_USER@$VPS_HOST" "cd $VPS_DOWNLOAD_DIR && sha256sum -c $checksum_basename" &> /dev/null; then
                log_error "Remote checksum verification failed for: $checksum_basename"
                verification_failed=true
            else
                log_verbose "Checksum verification passed on remote: $checksum_basename"
            fi
        fi
    done

    if [[ "$verification_failed" == "true" ]]; then
        exit 4
    fi

    log_success "Remote upload verification passed for all packages"
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
    local upload_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Build JSON for all packages
    local packages_json="["
    local first=true
    for package_file in "${PACKAGE_FILES[@]}"; do
        local package_basename=$(basename "$package_file")
        local package_size=$(ssh "$VPS_USER@$VPS_HOST" "du -h $VPS_DOWNLOAD_DIR/$package_basename | cut -f1")
        local download_url="https://app.cloudtolocalllm.online/downloads/$package_basename"

        if [[ "$first" == "false" ]]; then
            packages_json+=","
        fi
        first=false

        packages_json+="{\"filename\":\"$package_basename\",\"size\":\"$package_size\",\"url\":\"$download_url\"}"
    done
    packages_json+="]"

    # Create/update download metadata
    ssh "$VPS_USER@$VPS_HOST" "cat > $VPS_DOWNLOAD_DIR/latest.json << EOF
{
  \"version\": \"$version\",
  \"upload_date\": \"$upload_date\",
  \"packages\": $packages_json
}
EOF"

    log_success "Download metadata updated for ${#PACKAGE_FILES[@]} packages"
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

    echo ""
    echo -e "${GREEN}📦 Upload Summary${NC}"
    echo -e "${GREEN}=================${NC}"
    echo "Version: $version"
    echo "Packages uploaded: ${#PACKAGE_FILES[@]}"
    echo ""

    # List all uploaded packages
    for package_file in "${PACKAGE_FILES[@]}"; do
        local package_basename=$(basename "$package_file")
        echo "  📄 $package_basename"
        echo "     https://app.cloudtolocalllm.online/downloads/$package_basename"
    done
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}📋 DRY RUN completed - no actual upload performed${NC}"
    else
        echo -e "${BLUE}📋 Next steps:${NC}"
        echo "  1. Test download links from web interface"
        echo "  2. Update AUR PKGBUILD if Linux packages were uploaded"
        echo "  3. Deploy web application to VPS if needed"
        echo "  4. Verify all download links work correctly"
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
