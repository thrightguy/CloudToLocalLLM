#!/bin/bash

# CloudToLocalLLM Flutter Build Wrapper with Build-Time Timestamp Injection
# Wraps Flutter build commands to inject actual build timestamp at build execution time

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_INJECTOR="$SCRIPT_DIR/build_time_version_injector.sh"

# Flags
VERBOSE=false
DRY_RUN=false
SKIP_INJECTION=false
RESTORE_AFTER_BUILD=true

# Logging functions
log_info() {
    echo -e "${BLUE}[FLUTTER-BUILD]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[FLUTTER-BUILD] âœ…${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[FLUTTER-BUILD] âš ï¸${NC} $1"
}

log_error() {
    echo -e "${RED}[FLUTTER-BUILD] âŒ${NC} $1"
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Flutter Build Wrapper with Build-Time Timestamp Injection

USAGE:
    $0 [OPTIONS] <flutter_build_command> [flutter_args...]

OPTIONS:
    --verbose           Enable detailed logging
    --dry-run           Simulate build without actual execution
    --skip-injection    Skip timestamp injection (use existing version)
    --no-restore        Don't restore version files after build
    --help              Show this help message

EXAMPLES:
    $0 web --release                    # Build web with timestamp injection
    $0 linux --release                  # Build Linux with timestamp injection
    $0 --verbose web --no-tree-shake-icons  # Verbose web build
    $0 --dry-run linux --release        # Simulate Linux build

WORKFLOW:
    1. Inject current timestamp into version files
    2. Execute Flutter build command
    3. Restore original version files (optional)

This ensures build artifacts contain the exact timestamp of build execution.
EOF
}

# Parse command line arguments
parse_arguments() {
    local flutter_args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-injection)
                SKIP_INJECTION=true
                shift
                ;;
            --no-restore)
                RESTORE_AFTER_BUILD=false
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            --*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Remaining arguments are Flutter build command and args
                flutter_args=("$@")
                break
                ;;
        esac
    done
    
    if [[ ${#flutter_args[@]} -eq 0 ]]; then
        log_error "No Flutter build command specified"
        show_usage
        exit 1
    fi
    
    # Set global variables for Flutter command
    FLUTTER_BUILD_COMMAND="${flutter_args[@]}"
}

# Check if build injector script exists
check_build_injector() {
    if [[ ! -f "$BUILD_INJECTOR" ]]; then
        log_error "Build injector script not found: $BUILD_INJECTOR"
        exit 1
    fi
    
    if [[ ! -x "$BUILD_INJECTOR" ]]; then
        log_error "Build injector script is not executable: $BUILD_INJECTOR"
        exit 1
    fi
}

# Inject build timestamp
inject_build_timestamp() {
    if [[ "$SKIP_INJECTION" == "true" ]]; then
        log_warning "Skipping timestamp injection (--skip-injection flag)"
        return 0
    fi
    
    log_info "ðŸ•’ Injecting build timestamp..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would inject build timestamp"
        return 0
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        "$BUILD_INJECTOR" inject
    else
        "$BUILD_INJECTOR" inject > /dev/null
    fi
    
    log_success "Build timestamp injected"
}

# Execute Flutter build command
execute_flutter_build() {
    log_info "ðŸ”¨ Executing Flutter build: flutter build $FLUTTER_BUILD_COMMAND"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would execute: flutter build $FLUTTER_BUILD_COMMAND"
        return 0
    fi
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Execute Flutter build with proper error handling
    local build_start_time=$(date)
    log_info "Build started at: $build_start_time"
    
    if [[ "$VERBOSE" == "true" ]]; then
        if flutter build $FLUTTER_BUILD_COMMAND; then
            log_success "Flutter build completed successfully"
        else
            local exit_code=$?
            log_error "Flutter build failed with exit code $exit_code"
            return $exit_code
        fi
    else
        if flutter build $FLUTTER_BUILD_COMMAND > /dev/null 2>&1; then
            log_success "Flutter build completed successfully"
        else
            local exit_code=$?
            log_error "Flutter build failed with exit code $exit_code"
            return $exit_code
        fi
    fi
    
    local build_end_time=$(date)
    log_info "Build completed at: $build_end_time"
}

# Restore version files after build
restore_version_files() {
    if [[ "$RESTORE_AFTER_BUILD" != "true" ]]; then
        log_warning "Skipping version file restoration (--no-restore flag)"
        return 0
    fi
    
    if [[ "$SKIP_INJECTION" == "true" ]]; then
        log_info "No restoration needed (injection was skipped)"
        return 0
    fi
    
    log_info "ðŸ”„ Restoring version files..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would restore version files"
        return 0
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        "$BUILD_INJECTOR" restore
    else
        "$BUILD_INJECTOR" restore > /dev/null
    fi
    
    log_success "Version files restored"
}

# Clean up backup files
cleanup_backups() {
    if [[ "$SKIP_INJECTION" == "true" ]]; then
        return 0
    fi
    
    log_info "ðŸ§¹ Cleaning up backup files..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would clean up backup files"
        return 0
    fi
    
    "$BUILD_INJECTOR" cleanup > /dev/null 2>&1 || true
}

# Error handling and cleanup
cleanup_on_error() {
    local exit_code=$?
    log_error "Build failed with exit code $exit_code"
    
    # Attempt to restore version files on error
    if [[ "$SKIP_INJECTION" != "true" && "$DRY_RUN" != "true" ]]; then
        log_info "Attempting to restore version files after error..."
        "$BUILD_INJECTOR" restore > /dev/null 2>&1 || true
    fi
    
    exit $exit_code
}

# Display build summary
display_build_summary() {
    local current_version
    if command -v "$SCRIPT_DIR/version_manager.sh" &> /dev/null; then
        current_version=$("$SCRIPT_DIR/version_manager.sh" get 2>/dev/null || echo "Unknown")
    else
        current_version="Unknown"
    fi
    
    echo ""
    log_success "ðŸŽ‰ Flutter build completed successfully!"
    echo ""
    echo -e "${BLUE}ðŸ“‹ Build Summary${NC}"
    echo -e "${BLUE}===============${NC}"
    echo "  Command: flutter build $FLUTTER_BUILD_COMMAND"
    echo "  Version: $current_version"
    echo "  Timestamp Injection: $([ "$SKIP_INJECTION" == "true" ] && echo "Skipped" || echo "Applied")"
    echo "  Version Restoration: $([ "$RESTORE_AFTER_BUILD" == "true" ] && echo "Applied" || echo "Skipped")"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}ðŸ“‹ DRY RUN completed - no actual build performed${NC}"
    fi
}

# Main execution function
main() {
    # Header
    echo -e "${BLUE}CloudToLocalLLM Flutter Build with Build-Time Timestamp Injection${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Check prerequisites
    check_build_injector
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Execute build workflow
    inject_build_timestamp
    execute_flutter_build
    restore_version_files
    cleanup_backups
    
    # Display summary
    display_build_summary
}

# Execute main function
main "$@"
