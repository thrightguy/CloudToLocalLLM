#!/bin/bash

# CloudToLocalLLM Timestamp-Based Versioning Test Script v3.5.5+
# Tests the timestamp-based build number system (YYYYMMDDHHMM format)

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

# Test functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
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

# Test timestamp format validation
test_timestamp_format() {
    log_test "Testing timestamp format validation..."
    
    local current_build=$(./scripts/version_manager.sh get-build)
    
    # Check if build number matches YYYYMMDDHHMM format (12 digits)
    if [[ "$current_build" =~ ^[0-9]{12}$ ]]; then
        log_success "Build number format is valid: $current_build"
        
        # Extract components for validation
        local year=${current_build:0:4}
        local month=${current_build:4:2}
        local day=${current_build:6:2}
        local hour=${current_build:8:2}
        local minute=${current_build:10:2}
        
        # Basic range validation
        if [[ $year -ge 2025 && $year -le 2030 ]]; then
            log_success "Year component valid: $year"
        else
            log_error "Year component invalid: $year (expected 2025-2030)"
            return 1
        fi
        
        if [[ $month -ge 01 && $month -le 12 ]]; then
            log_success "Month component valid: $month"
        else
            log_error "Month component invalid: $month (expected 01-12)"
            return 1
        fi
        
        if [[ $day -ge 01 && $day -le 31 ]]; then
            log_success "Day component valid: $day"
        else
            log_error "Day component invalid: $day (expected 01-31)"
            return 1
        fi
        
        if [[ $hour -ge 00 && $hour -le 23 ]]; then
            log_success "Hour component valid: $hour"
        else
            log_error "Hour component invalid: $hour (expected 00-23)"
            return 1
        fi
        
        if [[ $minute -ge 00 && $minute -le 59 ]]; then
            log_success "Minute component valid: $minute"
        else
            log_error "Minute component invalid: $minute (expected 00-59)"
            return 1
        fi
        
    else
        log_error "Build number format invalid: $current_build (expected YYYYMMDDHHMM)"
        return 1
    fi
}

# Test build number generation
test_build_number_generation() {
    log_test "Testing build number generation..."
    
    # Generate a new build number
    local new_build=$(date +"%Y%m%d%H%M")
    log_test "Generated build number: $new_build"
    
    # Verify it's different from a build number generated 1 minute later
    sleep 61
    local newer_build=$(date +"%Y%m%d%H%M")
    
    if [[ "$new_build" != "$newer_build" ]]; then
        log_success "Build numbers are unique over time: $new_build != $newer_build"
    else
        log_warning "Build numbers are the same (test ran within same minute): $new_build"
    fi
}

# Test version synchronization
test_version_synchronization() {
    log_test "Testing version synchronization across files..."
    
    # Get versions from different sources
    local pubspec_version=$(./scripts/version_manager.sh get-semantic)
    local pubspec_build=$(./scripts/version_manager.sh get-build)
    local pubspec_full=$(./scripts/version_manager.sh get)
    
    log_test "pubspec.yaml: $pubspec_full"
    
    # Check assets/version.json
    if [[ -f "assets/version.json" ]]; then
        local assets_version=$(grep '"version"' assets/version.json | cut -d'"' -f4)
        local assets_build=$(grep '"build_number"' assets/version.json | cut -d'"' -f4)
        
        if [[ "$assets_version" == "$pubspec_version" ]]; then
            log_success "assets/version.json version matches: $assets_version"
        else
            log_error "assets/version.json version mismatch: $assets_version != $pubspec_version"
            return 1
        fi
        
        if [[ "$assets_build" == "$pubspec_build" ]]; then
            log_success "assets/version.json build number matches: $assets_build"
        else
            log_error "assets/version.json build number mismatch: $assets_build != $pubspec_build"
            return 1
        fi
    else
        log_warning "assets/version.json not found"
    fi
    
    # Check shared/lib/version.dart
    if [[ -f "lib/shared/lib/version.dart" ]]; then
        local shared_version=$(grep "static const String mainAppVersion = " lib/shared/lib/version.dart | cut -d"'" -f2)
        local shared_build=$(grep "static const int mainAppBuildNumber = " lib/shared/lib/version.dart | sed 's/.*= \([0-9]*\);/\1/')
        
        if [[ "$shared_version" == "$pubspec_version" ]]; then
            log_success "shared/lib/version.dart version matches: $shared_version"
        else
            log_error "shared/lib/version.dart version mismatch: $shared_version != $pubspec_version"
            return 1
        fi
        
        if [[ "$shared_build" == "$pubspec_build" ]]; then
            log_success "shared/lib/version.dart build number matches: $shared_build"
        else
            log_error "shared/lib/version.dart build number mismatch: $shared_build != $pubspec_build"
            return 1
        fi
    else
        log_warning "lib/shared/lib/version.dart not found"
    fi
    
    # Check shared/pubspec.yaml
    if [[ -f "lib/shared/pubspec.yaml" ]]; then
        local shared_pubspec_full=$(grep "^version:" lib/shared/pubspec.yaml | cut -d':' -f2 | tr -d ' ')
        
        if [[ "$shared_pubspec_full" == "$pubspec_full" ]]; then
            log_success "lib/shared/pubspec.yaml version matches: $shared_pubspec_full"
        else
            log_error "lib/shared/pubspec.yaml version mismatch: $shared_pubspec_full != $pubspec_full"
            return 1
        fi
    else
        log_warning "lib/shared/pubspec.yaml not found"
    fi
}

# Test increment build functionality
test_increment_build() {
    log_test "Testing build number increment functionality..."
    
    # Create backup of current state
    cp pubspec.yaml pubspec.yaml.test_backup
    if [[ -f "assets/version.json" ]]; then
        cp assets/version.json assets/version.json.test_backup
    fi
    
    # Get current build number
    local original_build=$(./scripts/version_manager.sh get-build)
    log_test "Original build number: $original_build"
    
    # Wait a minute to ensure timestamp difference
    log_test "Waiting 61 seconds to ensure timestamp difference..."
    sleep 61
    
    # Increment build number
    ./scripts/version_manager.sh increment build
    
    # Get new build number
    local new_build=$(./scripts/version_manager.sh get-build)
    log_test "New build number: $new_build"
    
    # Verify it's different and in correct format
    if [[ "$new_build" != "$original_build" ]]; then
        log_success "Build number changed: $original_build -> $new_build"
    else
        log_error "Build number did not change: $new_build"
        return 1
    fi
    
    if [[ "$new_build" =~ ^[0-9]{12}$ ]]; then
        log_success "New build number format is valid: $new_build"
    else
        log_error "New build number format is invalid: $new_build"
        return 1
    fi
    
    # Restore original state
    mv pubspec.yaml.test_backup pubspec.yaml
    if [[ -f "assets/version.json.test_backup" ]]; then
        mv assets/version.json.test_backup assets/version.json
    fi
    
    log_success "Test completed and original state restored"
}

# Main test execution
main() {
    echo -e "${BLUE}CloudToLocalLLM Timestamp-Based Versioning Test Suite${NC}"
    echo -e "${BLUE}====================================================${NC}"
    echo ""
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Run tests
    local tests_passed=0
    local tests_total=4
    
    if test_timestamp_format; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_build_number_generation; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_version_synchronization; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_increment_build; then
        ((tests_passed++))
    fi
    echo ""
    
    # Summary
    echo -e "${BLUE}Test Results Summary${NC}"
    echo -e "${BLUE}===================${NC}"
    echo -e "Tests passed: ${GREEN}$tests_passed${NC}/$tests_total"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        echo -e "${GREEN}✅ All tests passed! Timestamp-based versioning is working correctly.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"
