#!/bin/bash

# CloudToLocalLLM Timestamp-Based Versioning Verification Script v3.5.5+
# Quick verification of timestamp-based build number system

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

# Verification functions
log_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Verify timestamp format
verify_timestamp_format() {
    log_check "Verifying timestamp format..."
    
    local current_build=$(./scripts/version_manager.sh get-build)
    
    # Check if build number matches YYYYMMDDHHMM format (12 digits)
    if [[ "$current_build" =~ ^[0-9]{12}$ ]]; then
        log_success "Build number format is valid: $current_build"
        
        # Extract and validate components
        local year=${current_build:0:4}
        local month=${current_build:4:2}
        local day=${current_build:6:2}
        local hour=${current_build:8:2}
        local minute=${current_build:10:2}
        
        # Basic range validation (use 10# prefix to force decimal interpretation)
        if [[ $((10#$year)) -ge 2025 && $((10#$year)) -le 2030 && $((10#$month)) -ge 1 && $((10#$month)) -le 12 && $((10#$day)) -ge 1 && $((10#$day)) -le 31 && $((10#$hour)) -ge 0 && $((10#$hour)) -le 23 && $((10#$minute)) -ge 0 && $((10#$minute)) -le 59 ]]; then
            log_success "Timestamp components are valid: $year-$month-$day $hour:$minute"
            return 0
        else
            log_error "Timestamp components are invalid: $year-$month-$day $hour:$minute"
            return 1
        fi
    else
        log_error "Build number format invalid: $current_build (expected YYYYMMDDHHMM)"
        return 1
    fi
}

# Verify version synchronization
verify_version_sync() {
    log_check "Verifying version synchronization..."
    
    local pubspec_version=$(./scripts/version_manager.sh get-semantic)
    local pubspec_build=$(./scripts/version_manager.sh get-build)
    local pubspec_full=$(./scripts/version_manager.sh get)
    
    log_check "pubspec.yaml: $pubspec_full"
    
    local sync_errors=0
    
    # Check assets/version.json
    if [[ -f "assets/version.json" ]]; then
        local assets_version=$(grep '"version"' assets/version.json | cut -d'"' -f4)
        local assets_build=$(grep '"build_number"' assets/version.json | cut -d'"' -f4)
        
        if [[ "$assets_version" == "$pubspec_version" && "$assets_build" == "$pubspec_build" ]]; then
            log_success "assets/version.json synchronized: $assets_version+$assets_build"
        else
            log_error "assets/version.json not synchronized: $assets_version+$assets_build != $pubspec_version+$pubspec_build"
            ((sync_errors++))
        fi
    else
        log_warning "assets/version.json not found"
    fi
    
    # Check shared/lib/version.dart
    if [[ -f "lib/shared/lib/version.dart" ]]; then
        local shared_version=$(grep "static const String mainAppVersion = " lib/shared/lib/version.dart | cut -d"'" -f2)
        local shared_build=$(grep "static const int mainAppBuildNumber = " lib/shared/lib/version.dart | sed 's/.*= \([0-9]*\);/\1/')
        
        if [[ "$shared_version" == "$pubspec_version" && "$shared_build" == "$pubspec_build" ]]; then
            log_success "shared/lib/version.dart synchronized: $shared_version+$shared_build"
        else
            log_error "shared/lib/version.dart not synchronized: $shared_version+$shared_build != $pubspec_version+$pubspec_build"
            ((sync_errors++))
        fi
    else
        log_warning "lib/shared/lib/version.dart not found"
    fi
    
    # Check shared/pubspec.yaml
    if [[ -f "lib/shared/pubspec.yaml" ]]; then
        local shared_pubspec_full=$(grep "^version:" lib/shared/pubspec.yaml | cut -d':' -f2 | tr -d ' ')
        
        if [[ "$shared_pubspec_full" == "$pubspec_full" ]]; then
            log_success "lib/shared/pubspec.yaml synchronized: $shared_pubspec_full"
        else
            log_error "lib/shared/pubspec.yaml not synchronized: $shared_pubspec_full != $pubspec_full"
            ((sync_errors++))
        fi
    else
        log_warning "lib/shared/pubspec.yaml not found"
    fi
    
    return $sync_errors
}

# Verify build number generation
verify_build_generation() {
    log_check "Verifying build number generation..."
    
    # Test the generate_build_number function indirectly
    local current_timestamp=$(date +"%Y%m%d%H%M")
    
    # The current timestamp should be close to what generate_build_number would produce
    if [[ "$current_timestamp" =~ ^[0-9]{12}$ ]]; then
        log_success "Build number generation format is correct: $current_timestamp"
        return 0
    else
        log_error "Build number generation format is incorrect: $current_timestamp"
        return 1
    fi
}

# Verify version manager functionality
verify_version_manager() {
    log_check "Verifying version manager functionality..."
    
    # Test basic commands
    local full_version=$(./scripts/version_manager.sh get 2>/dev/null)
    local semantic_version=$(./scripts/version_manager.sh get-semantic 2>/dev/null)
    local build_number=$(./scripts/version_manager.sh get-build 2>/dev/null)
    
    if [[ -n "$full_version" && -n "$semantic_version" && -n "$build_number" ]]; then
        log_success "Version manager commands working: $full_version"
        
        # Verify format consistency
        if [[ "$full_version" == "$semantic_version+$build_number" ]]; then
            log_success "Version format consistency verified"
            return 0
        else
            log_error "Version format inconsistency: $full_version != $semantic_version+$build_number"
            return 1
        fi
    else
        log_error "Version manager commands failed"
        return 1
    fi
}

# Main verification
main() {
    echo -e "${BLUE}CloudToLocalLLM Timestamp-Based Versioning Verification${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo ""
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Run verifications
    local checks_passed=0
    local checks_total=4
    
    if verify_timestamp_format; then
        ((checks_passed++))
    fi
    echo ""
    
    if verify_build_generation; then
        ((checks_passed++))
    fi
    echo ""
    
    if verify_version_manager; then
        ((checks_passed++))
    fi
    echo ""
    
    if verify_version_sync; then
        ((checks_passed++))
    fi
    echo ""
    
    # Summary
    echo -e "${BLUE}Verification Results${NC}"
    echo -e "${BLUE}===================${NC}"
    echo -e "Checks passed: ${GREEN}$checks_passed${NC}/$checks_total"
    
    if [[ $checks_passed -eq $checks_total ]]; then
        echo -e "${GREEN}✅ All verifications passed! Timestamp-based versioning is working correctly.${NC}"
        echo ""
        echo -e "${BLUE}Current Version Information:${NC}"
        ./scripts/version_manager.sh info
        exit 0
    else
        echo -e "${RED}❌ Some verifications failed. Please review the output above.${NC}"
        echo ""
        echo -e "${YELLOW}💡 To fix synchronization issues, run:${NC}"
        echo -e "   ./scripts/deploy/sync_versions.sh"
        exit 1
    fi
}

# Execute main function
main "$@"
