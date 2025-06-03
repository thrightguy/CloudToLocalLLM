#!/bin/bash
# CloudToLocalLLM Binary Reassembly Script
# Reassembles split binary files that were compressed to stay under GitHub's 100MB limit

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"

echo -e "${BLUE}CloudToLocalLLM Binary Reassembly Script${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to reassemble a split file
reassemble_file() {
    local base_name="$1"
    local output_file="$2"
    local parts_pattern="$3"
    
    if [[ -f "$output_file" ]]; then
        print_warning "File $output_file already exists, skipping reassembly"
        return 0
    fi
    
    if ! ls $parts_pattern >/dev/null 2>&1; then
        print_error "No parts found for pattern: $parts_pattern"
        return 1
    fi
    
    print_status "Reassembling $base_name..."
    cat $parts_pattern > "$output_file"
    
    if [[ -f "$output_file" ]]; then
        print_status "Successfully reassembled: $output_file"
        local size=$(du -h "$output_file" | cut -f1)
        print_status "File size: $size"
        return 0
    else
        print_error "Failed to reassemble $base_name"
        return 1
    fi
}

# Change to dist directory
cd "$DIST_DIR"

print_status "Reassembling binary files in: $DIST_DIR"
echo ""

# Reassemble AppImage
if ls CloudToLocalLLM-3.0.0-x86_64.AppImage.part* >/dev/null 2>&1; then
    reassemble_file "AppImage" "CloudToLocalLLM-3.0.0-x86_64.AppImage" "CloudToLocalLLM-3.0.0-x86_64.AppImage.part*"
    if [[ $? -eq 0 ]]; then
        chmod +x "CloudToLocalLLM-3.0.0-x86_64.AppImage"
        print_status "Made AppImage executable"
    fi
else
    print_warning "No AppImage parts found"
fi

# Reassemble AUR binary package
if ls cloudtolocalllm-3.0.0-x86_64.tar.gz.part* >/dev/null 2>&1; then
    reassemble_file "AUR binary package" "cloudtolocalllm-3.0.0-x86_64.tar.gz" "cloudtolocalllm-3.0.0-x86_64.tar.gz.part*"
else
    print_warning "No AUR binary package parts found"
fi

# Reassemble tray daemon
if ls tray_daemon/linux-x64/cloudtolocalllm-enhanced-tray.gz.part* >/dev/null 2>&1; then
    cd tray_daemon/linux-x64
    reassemble_file "tray daemon (compressed)" "cloudtolocalllm-enhanced-tray.gz" "cloudtolocalllm-enhanced-tray.gz.part*"
    
    if [[ -f "cloudtolocalllm-enhanced-tray.gz" ]]; then
        print_status "Decompressing tray daemon..."
        gunzip cloudtolocalllm-enhanced-tray.gz
        if [[ -f "cloudtolocalllm-enhanced-tray" ]]; then
            chmod +x "cloudtolocalllm-enhanced-tray"
            print_status "Made tray daemon executable"
            
            # Create symlink for AUR package compatibility
            if [[ ! -L "cloudtolocalllm-tray" ]]; then
                ln -sf cloudtolocalllm-enhanced-tray cloudtolocalllm-tray
                print_status "Created symlink for AUR package compatibility"
            fi
        fi
    fi
    cd "$DIST_DIR"
else
    print_warning "No tray daemon parts found"
fi

echo ""
print_status "Binary reassembly completed!"
print_status "Files are ready for deployment and AUR package creation"
