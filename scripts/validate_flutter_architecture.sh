#!/bin/bash

# CloudToLocalLLM Flutter-Only Architecture Validation Script
# Validates the 3-app modular Flutter architecture implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}🔍 CloudToLocalLLM Flutter-Only Architecture Validation${NC}"
echo -e "${BLUE}📁 Project Root: $PROJECT_ROOT${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to run a validation check
validate_check() {
    local description="$1"
    local command="$2"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_info "Checking: $description"
    
    if eval "$command" > /dev/null 2>&1; then
        print_status "$description"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_error "$description"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to validate app structure
validate_app_structure() {
    local app_name="$1"
    local app_dir="$PROJECT_ROOT/apps/$app_name"

    print_info "Validating $app_name app structure..."

    validate_check "$app_name: pubspec.yaml exists" "[ -f '$app_dir/pubspec.yaml' ]"
    validate_check "$app_name: lib directory exists" "[ -d '$app_dir/lib' ]"

    # Only check for main.dart in actual apps, not shared library
    if [ "$app_name" != "shared" ]; then
        validate_check "$app_name: main.dart exists" "[ -f '$app_dir/lib/main.dart' ]"
        validate_check "$app_name: assets directory exists" "[ -d '$app_dir/assets' ]"
    fi

    # Check for Flutter dependencies
    if [ -f "$app_dir/pubspec.yaml" ]; then
        validate_check "$app_name: Flutter dependency declared" "grep -q 'flutter:' '$app_dir/pubspec.yaml'"

        # Only check for shared library dependency in apps, not in shared itself
        if [ "$app_name" != "shared" ]; then
            validate_check "$app_name: Shared library dependency" "grep -q 'cloudtolocalllm_shared:' '$app_dir/pubspec.yaml'"
        fi
    fi
}

# Function to validate Python removal
validate_python_removal() {
    print_info "Validating Python component removal..."
    
    validate_check "Python tray_daemon directory removed" "[ ! -d '$PROJECT_ROOT/tray_daemon' ]"
    validate_check "Python icon generation script removed" "[ ! -f '$PROJECT_ROOT/scripts/generate_tray_icons.py' ]"
    
    # Check for any remaining Python files (excluding legitimate scripts and node_modules)
    local python_files=$(find "$PROJECT_ROOT" -name "*.py" -not -path "*/.*" -not -path "*/scripts/deployment/*" -not -path "*/node_modules/*" 2>/dev/null | wc -l)
    validate_check "No stray Python files in main codebase" "[ $python_files -eq 0 ]"
}

# Function to validate IPC implementation
validate_ipc_implementation() {
    print_info "Validating IPC implementation..."
    
    # Tray service IPC server
    validate_check "Tray service IPC server exists" "[ -f '$PROJECT_ROOT/apps/tray/lib/services/ipc_server.dart' ]"
    
    # Chat app IPC client
    validate_check "Chat app IPC client exists" "[ -f '$PROJECT_ROOT/apps/chat/lib/services/tray_ipc_client.dart' ]"
    
    # Settings app IPC client
    validate_check "Settings app IPC client exists" "[ -f '$PROJECT_ROOT/apps/settings/lib/services/ipc_client.dart' ]"
    
    # Check for TCP socket usage in IPC files
    validate_check "Tray IPC server uses TCP sockets" "grep -q 'ServerSocket' '$PROJECT_ROOT/apps/tray/lib/services/ipc_server.dart'"
    validate_check "Chat IPC client uses TCP sockets" "grep -q 'Socket.connect' '$PROJECT_ROOT/apps/chat/lib/services/tray_ipc_client.dart'"
}

# Function to validate system tray implementation
validate_system_tray() {
    print_info "Validating system tray implementation..."
    
    # Tray service using tray_manager
    validate_check "Tray service uses tray_manager" "grep -q 'tray_manager:' '$PROJECT_ROOT/apps/tray/pubspec.yaml'"
    validate_check "Tray service implementation exists" "[ -f '$PROJECT_ROOT/apps/tray/lib/services/tray_service.dart' ]"
    
    # Check for monochrome icons
    validate_check "Tray icons directory exists" "[ -d '$PROJECT_ROOT/apps/tray/assets/images' ]"
    
    # Updated system tray manager in chat app
    validate_check "Chat app system tray manager updated" "grep -q 'TrayIPCClient' '$PROJECT_ROOT/apps/chat/lib/services/system_tray_manager.dart'"
}

# Function to validate build system
validate_build_system() {
    print_info "Validating build system..."
    
    validate_check "Build script exists" "[ -f '$PROJECT_ROOT/scripts/build_all.sh' ]"
    validate_check "Build script is executable" "[ -x '$PROJECT_ROOT/scripts/build_all.sh' ]"
    
    # Check build script references correct apps
    validate_check "Build script references chat app" "grep -q 'chat' '$PROJECT_ROOT/scripts/build_all.sh'"
    validate_check "Build script references tray app" "grep -q 'tray' '$PROJECT_ROOT/scripts/build_all.sh'"
    validate_check "Build script references settings app" "grep -q 'settings' '$PROJECT_ROOT/scripts/build_all.sh'"
    validate_check "Build script no longer references tunnel app" "! grep -q 'tunnel' '$PROJECT_ROOT/scripts/build_all.sh'"
}

# Function to validate Context7 documentation requirement
validate_context7_requirement() {
    print_info "Validating Context7 documentation requirement..."
    
    validate_check "README mentions Context7 requirement" "grep -q 'Context7' '$PROJECT_ROOT/README.md'"
    validate_check "README mentions resolve-library-id" "grep -q 'resolve-library-id' '$PROJECT_ROOT/README.md'"
    validate_check "README mentions get-library-docs" "grep -q 'get-library-docs' '$PROJECT_ROOT/README.md'"
}

# Function to validate dependencies
validate_dependencies() {
    print_info "Validating Flutter dependencies..."
    
    # Check for proper Flutter dependencies in each app
    for app in chat tray settings; do
        if [ -f "$PROJECT_ROOT/apps/$app/pubspec.yaml" ]; then
            validate_check "$app: No deprecated dart:html imports" "! grep -r 'dart:html' '$PROJECT_ROOT/apps/$app/lib' 2>/dev/null"
            validate_check "$app: Uses package:web if needed" "grep -q 'web:' '$PROJECT_ROOT/apps/$app/pubspec.yaml' || true"
        fi
    done
}

# Main validation process
main() {
    echo -e "${BLUE}🔧 Starting Flutter-only architecture validation...${NC}"
    echo ""
    
    # Validate shared library
    validate_app_structure "shared"
    echo ""
    
    # Validate chat app
    validate_app_structure "chat"
    echo ""
    
    # Validate tray app
    validate_app_structure "tray"
    echo ""
    
    # Validate settings app
    validate_app_structure "settings"
    echo ""
    
    # Validate Python removal
    validate_python_removal
    echo ""
    
    # Validate IPC implementation
    validate_ipc_implementation
    echo ""
    
    # Validate system tray
    validate_system_tray
    echo ""
    
    # Validate build system
    validate_build_system
    echo ""
    
    # Validate Context7 requirement
    validate_context7_requirement
    echo ""
    
    # Validate dependencies
    validate_dependencies
    echo ""
    
    # Display summary
    echo -e "${BLUE}📊 Validation Summary:${NC}"
    echo -e "Total checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
    echo ""
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        print_status "All validation checks passed! 🎉"
        print_info "Flutter-only architecture is properly implemented."
        exit 0
    else
        print_error "Some validation checks failed."
        print_info "Please review the failed checks and fix the issues."
        exit 1
    fi
}

# Run validation
main "$@"
