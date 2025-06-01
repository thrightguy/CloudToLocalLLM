#!/bin/bash

# Fix tray_manager deprecation warning by patching the source file
# This script replaces the deprecated app_indicator_new call with modern g_object_new

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to find the tray_manager plugin source file
find_tray_manager_source() {
    local search_paths=(
        "$PROJECT_ROOT/linux/flutter/ephemeral/.plugin_symlinks/tray_manager/linux/tray_manager_plugin.cc"
        "$PROJECT_ROOT/build/linux/x64/release/flutter/ephemeral/.plugin_symlinks/tray_manager/linux/tray_manager_plugin.cc"
        "$PROJECT_ROOT/build/linux/x64/debug/flutter/ephemeral/.plugin_symlinks/tray_manager/linux/tray_manager_plugin.cc"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Function to check if file needs patching
needs_patching() {
    local file="$1"
    if grep -q "app_indicator_new(" "$file" 2>/dev/null; then
        return 0  # needs patching
    else
        return 1  # already patched or not found
    fi
}

# Function to create backup
create_backup() {
    local file="$1"
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ ! -f "${file}.backup.original" ]]; then
        cp "$file" "${file}.backup.original"
        log_info "Created original backup: ${file}.backup.original"
    fi
    
    cp "$file" "$backup"
    log_info "Created backup: $backup"
}

# Function to apply the fix
apply_fix() {
    local file="$1"
    
    log_info "Applying deprecation fix to: $file"
    
    # Create backup
    create_backup "$file"
    
    # Apply the fix using sed
    sed -i.tmp '
        /indicator = app_indicator_new(id, icon_path,/{
            N
            s/indicator = app_indicator_new(id, icon_path,\n[[:space:]]*APP_INDICATOR_CATEGORY_APPLICATION_STATUS);/indicator = APP_INDICATOR(g_object_new(APP_INDICATOR_TYPE,\n                                          "id", id,\n                                          "icon-name", icon_path,\n                                          "category", APP_INDICATOR_CATEGORY_APPLICATION_STATUS,\n                                          NULL));/
        }
    ' "$file"
    
    # Remove temporary file
    rm -f "${file}.tmp"
    
    # Verify the fix was applied
    if grep -q "g_object_new(APP_INDICATOR_TYPE" "$file"; then
        log_success "Successfully applied deprecation fix"
        return 0
    else
        log_error "Failed to apply fix, restoring backup"
        if [[ -f "${file}.backup.original" ]]; then
            cp "${file}.backup.original" "$file"
        fi
        return 1
    fi
}

# Function to restore original file
restore_original() {
    local file="$1"
    local backup="${file}.backup.original"
    
    if [[ -f "$backup" ]]; then
        cp "$backup" "$file"
        log_success "Restored original file: $file"
    else
        log_warning "No original backup found for: $file"
    fi
}

# Main function
main() {
    log_info "CloudToLocalLLM tray_manager deprecation fix"
    log_info "============================================"
    
    case "${1:-apply}" in
        "apply")
            log_info "Searching for tray_manager plugin source file..."
            
            if source_file=$(find_tray_manager_source); then
                log_info "Found tray_manager source: $source_file"
                
                if needs_patching "$source_file"; then
                    log_info "File needs patching (contains deprecated app_indicator_new)"
                    apply_fix "$source_file"
                else
                    log_success "File already patched or doesn't contain deprecated calls"
                fi
            else
                log_error "Could not find tray_manager plugin source file"
                log_info "Make sure you have run 'flutter clean' and 'flutter build linux' first"
                exit 1
            fi
            ;;
            
        "restore")
            log_info "Restoring original tray_manager source file..."
            
            if source_file=$(find_tray_manager_source); then
                restore_original "$source_file"
            else
                log_error "Could not find tray_manager plugin source file"
                exit 1
            fi
            ;;
            
        "check")
            log_info "Checking tray_manager deprecation status..."
            
            if source_file=$(find_tray_manager_source); then
                log_info "Found tray_manager source: $source_file"
                
                if needs_patching "$source_file"; then
                    log_warning "File contains deprecated app_indicator_new calls"
                    echo "Run '$0 apply' to fix the deprecation warning"
                    exit 1
                else
                    log_success "File is clean (no deprecated calls found)"
                fi
            else
                log_error "Could not find tray_manager plugin source file"
                exit 1
            fi
            ;;
            
        *)
            echo "Usage: $0 [apply|restore|check]"
            echo ""
            echo "Commands:"
            echo "  apply   - Apply the deprecation fix (default)"
            echo "  restore - Restore the original source file"
            echo "  check   - Check if the file needs patching"
            echo ""
            echo "This script fixes the tray_manager deprecation warning by replacing"
            echo "the deprecated app_indicator_new() call with modern g_object_new()."
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
