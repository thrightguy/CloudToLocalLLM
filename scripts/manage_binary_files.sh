#!/bin/bash

# CloudToLocalLLM Binary File Management Script
# Automatically handles splitting, checksums, and Git management for large binary files
# Version: 3.0.1

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
MAX_FILE_SIZE="50M"
GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"
CHECKSUMS_FILE="$DIST_DIR/binary_checksums.txt"

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

# Print usage information
usage() {
    echo "CloudToLocalLLM Binary File Management"
    echo "======================================"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  split       Split large files (>50MB) into GitHub-compatible chunks"
    echo "  reassemble  Reassemble split files back to originals"
    echo "  verify      Verify integrity of split/reassembled files"
    echo "  clean       Clean up split files and checksums"
    echo "  status      Show status of binary files and splits"
    echo "  auto        Automatically manage all binary files (default)"
    echo
    echo "Options:"
    echo "  --dry-run   Show what would be done without making changes"
    echo "  --force     Force operations even if files exist"
    echo "  --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 auto                    # Automatically manage all binary files"
    echo "  $0 split --dry-run         # Show what files would be split"
    echo "  $0 verify                  # Verify all checksums"
    echo "  $0 clean                   # Clean up all split files"
}

# Check if file is larger than specified size
is_file_large() {
    local file="$1"
    local size_limit="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Convert size limit to bytes for comparison
    local limit_bytes
    case "$size_limit" in
        *M) limit_bytes=$((${size_limit%M} * 1024 * 1024)) ;;
        *G) limit_bytes=$((${size_limit%G} * 1024 * 1024 * 1024)) ;;
        *) limit_bytes="$size_limit" ;;
    esac
    
    local file_size
    file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    
    [[ "$file_size" -gt "$limit_bytes" ]]
}

# Find all large files in dist directory
find_large_files() {
    local files=()
    
    if [[ ! -d "$DIST_DIR" ]]; then
        return 0
    fi
    
    while IFS= read -r -d '' file; do
        if is_file_large "$file" "$MAX_FILE_SIZE"; then
            # Skip already split files
            if [[ ! "$file" =~ \.part[a-z]+$ ]]; then
                files+=("$file")
            fi
        fi
    done < <(find "$DIST_DIR" -type f -print0)
    
    printf '%s\n' "${files[@]}"
}

# Split a single file
split_file() {
    local file="$1"
    local dry_run="${2:-false}"
    local force="${3:-false}"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    local basename
    basename="$(basename "$file")"
    local dirname
    dirname="$(dirname "$file")"
    
    # Check if split files already exist
    if [[ "$force" != "true" ]] && ls "$dirname/$basename.part"* >/dev/null 2>&1; then
        log_warning "Split files already exist for $basename (use --force to overwrite)"
        return 0
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "Would split: $file ($(du -h "$file" | cut -f1))"
        return 0
    fi
    
    log_info "Splitting $basename ($(du -h "$file" | cut -f1)) into $MAX_FILE_SIZE chunks..."
    
    # Remove existing split files if force is enabled
    if [[ "$force" == "true" ]]; then
        rm -f "$dirname/$basename.part"*
    fi
    
    # Split the file
    cd "$dirname"
    if split -b "$MAX_FILE_SIZE" "$basename" "$basename.part"; then
        log_success "Split $basename into $(ls "$basename.part"* | wc -l) parts"
        
        # Generate checksums
        generate_checksums_for_file "$file"
        
        return 0
    else
        log_error "Failed to split $file"
        return 1
    fi
}

# Reassemble split files
reassemble_file() {
    local base_file="$1"
    local dry_run="${2:-false}"
    local force="${3:-false}"
    
    local basename
    basename="$(basename "$base_file")"
    local dirname
    dirname="$(dirname "$base_file")"
    
    # Check if split files exist
    if ! ls "$dirname/$basename.part"* >/dev/null 2>&1; then
        log_warning "No split files found for $basename"
        return 0
    fi
    
    # Check if original already exists
    if [[ "$force" != "true" ]] && [[ -f "$base_file" ]]; then
        log_warning "Original file already exists: $basename (use --force to overwrite)"
        return 0
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "Would reassemble: $basename from $(ls "$dirname/$basename.part"* | wc -l) parts"
        return 0
    fi
    
    log_info "Reassembling $basename from split parts..."
    
    # Reassemble the file
    cd "$dirname"
    if cat "$basename.part"* > "$basename.tmp" && mv "$basename.tmp" "$basename"; then
        log_success "Reassembled $basename"
        
        # Verify checksum if available
        verify_file_checksum "$base_file"
        
        return 0
    else
        log_error "Failed to reassemble $base_file"
        rm -f "$basename.tmp"
        return 1
    fi
}

# Generate checksums for a file and its parts
generate_checksums_for_file() {
    local file="$1"
    local basename
    basename="$(basename "$file")"
    local dirname
    dirname="$(dirname "$file")"
    
    # Create checksums directory if it doesn't exist
    mkdir -p "$(dirname "$CHECKSUMS_FILE")"
    
    # Initialize checksums file if it doesn't exist
    if [[ ! -f "$CHECKSUMS_FILE" ]]; then
        cat > "$CHECKSUMS_FILE" << EOF
# CloudToLocalLLM Binary Files Checksums
# Generated: $(date)
# Format: SHA256 checksum, filename, file type (original/part)

EOF
    fi
    
    # Remove existing entries for this file
    sed -i "/$(basename "$file")/d" "$CHECKSUMS_FILE" 2>/dev/null || true
    
    # Add original file checksum
    if [[ -f "$file" ]]; then
        local checksum
        checksum=$(sha256sum "$file" | cut -d' ' -f1)
        echo "$checksum  $basename  original" >> "$CHECKSUMS_FILE"
    fi
    
    # Add split parts checksums
    if ls "$dirname/$basename.part"* >/dev/null 2>&1; then
        for part in "$dirname/$basename.part"*; do
            local part_name
            part_name="$(basename "$part")"
            local part_checksum
            part_checksum=$(sha256sum "$part" | cut -d' ' -f1)
            echo "$part_checksum  $part_name  part" >> "$CHECKSUMS_FILE"
        done
    fi
    
    log_success "Updated checksums for $basename"
}

# Verify file checksum
verify_file_checksum() {
    local file="$1"
    local basename
    basename="$(basename "$file")"
    
    if [[ ! -f "$CHECKSUMS_FILE" ]]; then
        log_warning "No checksums file found"
        return 1
    fi
    
    local stored_checksum
    stored_checksum=$(grep "$basename.*original" "$CHECKSUMS_FILE" 2>/dev/null | cut -d' ' -f1 || echo "")
    
    if [[ -z "$stored_checksum" ]]; then
        log_warning "No stored checksum found for $basename"
        return 1
    fi
    
    local current_checksum
    current_checksum=$(sha256sum "$file" | cut -d' ' -f1)
    
    if [[ "$stored_checksum" == "$current_checksum" ]]; then
        log_success "Checksum verified for $basename"
        return 0
    else
        log_error "Checksum mismatch for $basename"
        log_error "  Expected: $stored_checksum"
        log_error "  Actual:   $current_checksum"
        return 1
    fi
}

# Update .gitignore to handle split files
update_gitignore() {
    local dry_run="${1:-false}"

    if [[ "$dry_run" == "true" ]]; then
        log_info "Would update .gitignore with binary file rules"
        return 0
    fi

    log_info "Updating .gitignore for binary file management..."

    # Create .gitignore if it doesn't exist
    if [[ ! -f "$GITIGNORE_FILE" ]]; then
        touch "$GITIGNORE_FILE"
    fi

    # Check if our rules already exist
    if grep -q "# CloudToLocalLLM Binary File Management" "$GITIGNORE_FILE"; then
        log_info ".gitignore already contains binary file rules"
        return 0
    fi

    # Add our rules
    cat >> "$GITIGNORE_FILE" << 'EOF'

# CloudToLocalLLM Binary File Management
# Exclude large original files (>50MB) but include split parts
dist/*.tar.gz
dist/*.AppImage
dist/**/cloudtolocalllm-enhanced-tray
dist/**/cloudtolocalllm-settings
# Include split parts and checksums
!dist/*.part*
!dist/**/binary_checksums.txt
!dist/binary_checksums.txt
EOF

    log_success "Updated .gitignore with binary file management rules"
}

# Show status of binary files
show_status() {
    log_info "CloudToLocalLLM Binary Files Status"
    echo "===================================="
    echo

    if [[ ! -d "$DIST_DIR" ]]; then
        log_warning "Distribution directory not found: $DIST_DIR"
        return 1
    fi

    echo "📁 Distribution Directory: $DIST_DIR"
    echo

    # Find all files and categorize them
    local large_files=()
    local split_files=()
    local normal_files=()

    while IFS= read -r -d '' file; do
        local rel_path="${file#$DIST_DIR/}"

        if [[ "$file" =~ \.part[a-z]+$ ]]; then
            split_files+=("$rel_path")
        elif is_file_large "$file" "$MAX_FILE_SIZE"; then
            large_files+=("$rel_path")
        else
            normal_files+=("$rel_path")
        fi
    done < <(find "$DIST_DIR" -type f -print0 2>/dev/null || true)

    # Show large files
    if [[ ${#large_files[@]} -gt 0 ]]; then
        echo "🔴 Large Files (>$MAX_FILE_SIZE):"
        for file in "${large_files[@]}"; do
            local size
            size=$(du -h "$DIST_DIR/$file" | cut -f1)
            echo "  📦 $file ($size)"

            # Check if split files exist
            if ls "$DIST_DIR/$file.part"* >/dev/null 2>&1; then
                local parts
                parts=$(ls "$DIST_DIR/$file.part"* | wc -l)
                echo "    ✅ Split into $parts parts"
            else
                echo "    ❌ Not split"
            fi
        done
        echo
    fi

    # Show split files
    if [[ ${#split_files[@]} -gt 0 ]]; then
        echo "🟡 Split Files:"
        # Group by base name
        local base_names=()
        for file in "${split_files[@]}"; do
            local base_name="${file%.part*}"
            if [[ ! " ${base_names[*]} " =~ " $base_name " ]]; then
                base_names+=("$base_name")
            fi
        done

        for base_name in "${base_names[@]}"; do
            local parts
            parts=$(ls "$DIST_DIR/$base_name.part"* 2>/dev/null | wc -l || echo "0")
            local total_size
            total_size=$(du -ch "$DIST_DIR/$base_name.part"* 2>/dev/null | tail -1 | cut -f1 || echo "0")
            echo "  🧩 $base_name ($parts parts, $total_size total)"
        done
        echo
    fi

    # Show normal files
    if [[ ${#normal_files[@]} -gt 0 ]]; then
        echo "🟢 Normal Files (<$MAX_FILE_SIZE):"
        for file in "${normal_files[@]}"; do
            local size
            size=$(du -h "$DIST_DIR/$file" | cut -f1)
            echo "  📄 $file ($size)"
        done
        echo
    fi

    # Show checksums status
    if [[ -f "$CHECKSUMS_FILE" ]]; then
        local checksum_count
        checksum_count=$(grep -c "original\|part" "$CHECKSUMS_FILE" 2>/dev/null || echo "0")
        echo "🔐 Checksums: $checksum_count entries in $(basename "$CHECKSUMS_FILE")"
    else
        echo "🔐 Checksums: No checksum file found"
    fi

    echo
}

# Split all large files
split_all() {
    local dry_run="${1:-false}"
    local force="${2:-false}"

    log_info "Finding large files to split..."

    local large_files
    mapfile -t large_files < <(find_large_files)

    if [[ ${#large_files[@]} -eq 0 ]]; then
        log_success "No large files found that need splitting"
        return 0
    fi

    log_info "Found ${#large_files[@]} large files to split"

    local success_count=0
    local error_count=0

    for file in "${large_files[@]}"; do
        if split_file "$file" "$dry_run" "$force"; then
            ((success_count++))
        else
            ((error_count++))
        fi
    done

    if [[ "$dry_run" != "true" ]]; then
        log_success "Split $success_count files successfully"
        if [[ $error_count -gt 0 ]]; then
            log_error "Failed to split $error_count files"
        fi
    fi

    return $error_count
}

# Reassemble all split files
reassemble_all() {
    local dry_run="${1:-false}"
    local force="${2:-false}"

    log_info "Finding split files to reassemble..."

    # Find all base files that have split parts
    local base_files=()
    if [[ -d "$DIST_DIR" ]]; then
        while IFS= read -r -d '' part_file; do
            local base_file="${part_file%.part*}"
            if [[ ! " ${base_files[*]} " =~ " $base_file " ]]; then
                base_files+=("$base_file")
            fi
        done < <(find "$DIST_DIR" -name "*.part*" -print0 2>/dev/null || true)
    fi

    if [[ ${#base_files[@]} -eq 0 ]]; then
        log_success "No split files found to reassemble"
        return 0
    fi

    log_info "Found ${#base_files[@]} files to reassemble"

    local success_count=0
    local error_count=0

    for file in "${base_files[@]}"; do
        if reassemble_file "$file" "$dry_run" "$force"; then
            ((success_count++))
        else
            ((error_count++))
        fi
    done

    if [[ "$dry_run" != "true" ]]; then
        log_success "Reassembled $success_count files successfully"
        if [[ $error_count -gt 0 ]]; then
            log_error "Failed to reassemble $error_count files"
        fi
    fi

    return $error_count
}

# Verify all checksums
verify_all() {
    log_info "Verifying all file checksums..."

    if [[ ! -f "$CHECKSUMS_FILE" ]]; then
        log_warning "No checksums file found"
        return 1
    fi

    local success_count=0
    local error_count=0

    # Get all original files from checksums
    while IFS= read -r line; do
        if [[ "$line" =~ ^[a-f0-9]+[[:space:]]+([^[:space:]]+)[[:space:]]+original$ ]]; then
            local filename="${BASH_REMATCH[1]}"
            local filepath="$DIST_DIR/$filename"

            if [[ -f "$filepath" ]]; then
                if verify_file_checksum "$filepath"; then
                    ((success_count++))
                else
                    ((error_count++))
                fi
            else
                log_warning "File not found for checksum verification: $filename"
            fi
        fi
    done < "$CHECKSUMS_FILE"

    log_success "Verified $success_count files successfully"
    if [[ $error_count -gt 0 ]]; then
        log_error "Failed to verify $error_count files"
    fi

    return $error_count
}

# Clean up split files and checksums
clean_all() {
    local dry_run="${1:-false}"

    log_info "Cleaning up split files and checksums..."

    if [[ "$dry_run" == "true" ]]; then
        log_info "Would remove all .part* files and checksums"
        if [[ -d "$DIST_DIR" ]]; then
            find "$DIST_DIR" -name "*.part*" -type f | while read -r file; do
                log_info "Would remove: ${file#$DIST_DIR/}"
            done
        fi
        if [[ -f "$CHECKSUMS_FILE" ]]; then
            log_info "Would remove: $(basename "$CHECKSUMS_FILE")"
        fi
        return 0
    fi

    local removed_count=0

    # Remove split files
    if [[ -d "$DIST_DIR" ]]; then
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((removed_count++))
            log_info "Removed: ${file#$DIST_DIR/}"
        done < <(find "$DIST_DIR" -name "*.part*" -type f -print0 2>/dev/null || true)
    fi

    # Remove checksums file
    if [[ -f "$CHECKSUMS_FILE" ]]; then
        rm -f "$CHECKSUMS_FILE"
        ((removed_count++))
        log_info "Removed: $(basename "$CHECKSUMS_FILE")"
    fi

    log_success "Cleaned up $removed_count files"
}

# Automatic management (default operation)
auto_manage() {
    local dry_run="${1:-false}"
    local force="${2:-false}"

    log_info "Automatic binary file management..."

    # Update .gitignore first
    update_gitignore "$dry_run"

    # Split large files
    split_all "$dry_run" "$force"

    # Show final status
    if [[ "$dry_run" != "true" ]]; then
        echo
        show_status
    fi
}

# Main function
main() {
    local command="auto"
    local dry_run=false
    local force=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            split|reassemble|verify|clean|status|auto)
                command="$1"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Ensure we're in the project root
    cd "$PROJECT_ROOT"

    # Execute the requested command
    case "$command" in
        split)
            split_all "$dry_run" "$force"
            ;;
        reassemble)
            reassemble_all "$dry_run" "$force"
            ;;
        verify)
            verify_all
            ;;
        clean)
            clean_all "$dry_run"
            ;;
        status)
            show_status
            ;;
        auto)
            auto_manage "$dry_run" "$force"
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
