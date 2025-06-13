#!/bin/bash

# CloudToLocalLLM Build-Time Timestamp Injection Test Script
# Tests the build-time timestamp injection system to ensure build numbers reflect actual build execution time

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

# Create backup of current state
create_test_backup() {
    log_test "Creating test backup..."
    
    cp pubspec.yaml pubspec.yaml.test-backup
    if [[ -f "assets/version.json" ]]; then
        cp assets/version.json assets/version.json.test-backup
    fi
    if [[ -f "lib/shared/lib/version.dart" ]]; then
        cp lib/shared/lib/version.dart lib/shared/lib/version.dart.test-backup
    fi
    if [[ -f "lib/shared/pubspec.yaml" ]]; then
        cp lib/shared/pubspec.yaml lib/shared/pubspec.yaml.test-backup
    fi
    
    log_success "Test backup created"
}

# Restore test backup
restore_test_backup() {
    log_test "Restoring test backup..."
    
    mv pubspec.yaml.test-backup pubspec.yaml
    if [[ -f "assets/version.json.test-backup" ]]; then
        mv assets/version.json.test-backup assets/version.json
    fi
    if [[ -f "lib/shared/lib/version.dart.test-backup" ]]; then
        mv lib/shared/lib/version.dart.test-backup lib/shared/lib/version.dart
    fi
    if [[ -f "lib/shared/pubspec.yaml.test-backup" ]]; then
        mv lib/shared/pubspec.yaml.test-backup lib/shared/pubspec.yaml
    fi
    
    log_success "Test backup restored"
}

# Test version preparation
test_version_preparation() {
    log_test "Testing version preparation with placeholder..."
    
    # Prepare a build increment
    if ./scripts/version_manager.sh prepare build; then
        log_success "Version preparation completed"
    else
        log_error "Version preparation failed"
        return 1
    fi
    
    # Check if placeholder was inserted
    local build_number=$(./scripts/version_manager.sh get-build)
    if [[ "$build_number" == "BUILD_TIME_PLACEHOLDER" ]]; then
        log_success "Placeholder build number inserted: $build_number"
    else
        log_error "Expected placeholder, got: $build_number"
        return 1
    fi
    
    return 0
}

# Test build-time injection
test_build_time_injection() {
    log_test "Testing build-time timestamp injection..."
    
    # Record time before injection
    local before_timestamp=$(date +"%Y%m%d%H%M")
    
    # Inject build timestamp
    if ./scripts/build_time_version_injector.sh inject; then
        log_success "Build-time injection completed"
    else
        log_error "Build-time injection failed"
        return 1
    fi
    
    # Record time after injection
    local after_timestamp=$(date +"%Y%m%d%H%M")
    
    # Check if real timestamp was injected
    local build_number=$(./scripts/version_manager.sh get-build)
    if [[ "$build_number" =~ ^[0-9]{12}$ ]]; then
        log_success "Valid timestamp format injected: $build_number"
        
        # Verify timestamp is within reasonable range
        if [[ "$build_number" -ge "$before_timestamp" && "$build_number" -le "$after_timestamp" ]]; then
            log_success "Timestamp is within expected range"
        else
            log_warning "Timestamp outside expected range: $before_timestamp <= $build_number <= $after_timestamp"
        fi
    else
        log_error "Invalid timestamp format: $build_number"
        return 1
    fi
    
    return 0
}

# Test version file synchronization
test_version_synchronization() {
    log_test "Testing version file synchronization..."
    
    local pubspec_version=$(./scripts/version_manager.sh get-semantic)
    local pubspec_build=$(./scripts/version_manager.sh get-build)
    
    local sync_errors=0
    
    # Check assets/version.json
    if [[ -f "assets/version.json" ]]; then
        local assets_version=$(grep '"version"' assets/version.json | cut -d'"' -f4)
        local assets_build=$(grep '"build_number"' assets/version.json | cut -d'"' -f4)
        
        if [[ "$assets_version" == "$pubspec_version" && "$assets_build" == "$pubspec_build" ]]; then
            log_success "assets/version.json synchronized"
        else
            log_error "assets/version.json not synchronized: $assets_version+$assets_build != $pubspec_version+$pubspec_build"
            ((sync_errors++))
        fi
    fi
    
    # Check shared/lib/version.dart
    if [[ -f "lib/shared/lib/version.dart" ]]; then
        local shared_version=$(grep "static const String mainAppVersion = " lib/shared/lib/version.dart | cut -d"'" -f2)
        local shared_build=$(grep "static const int mainAppBuildNumber = " lib/shared/lib/version.dart | sed 's/.*= \([0-9]*\);/\1/')
        
        if [[ "$shared_version" == "$pubspec_version" && "$shared_build" == "$pubspec_build" ]]; then
            log_success "lib/shared/lib/version.dart synchronized"
        else
            log_error "lib/shared/lib/version.dart not synchronized: $shared_version+$shared_build != $pubspec_version+$pubspec_build"
            ((sync_errors++))
        fi
    fi
    
    return $sync_errors
}

# Test backup and restore functionality
test_backup_restore() {
    log_test "Testing backup and restore functionality..."
    
    # Get original version
    local original_version=$(./scripts/version_manager.sh get)
    
    # Inject timestamp (creates backups)
    ./scripts/build_time_version_injector.sh inject > /dev/null
    
    # Get modified version
    local modified_version=$(./scripts/version_manager.sh get)
    
    # Restore from backups
    ./scripts/build_time_version_injector.sh restore > /dev/null
    
    # Get restored version
    local restored_version=$(./scripts/version_manager.sh get)
    
    if [[ "$original_version" == "$restored_version" ]]; then
        log_success "Backup and restore functionality working"
        return 0
    else
        log_error "Backup/restore failed: $original_version != $restored_version"
        return 1
    fi
}

# Test Flutter build wrapper (dry run)
test_flutter_build_wrapper() {
    log_test "Testing Flutter build wrapper (dry run)..."
    
    if [[ -f "./scripts/flutter_build_with_timestamp.sh" ]]; then
        if ./scripts/flutter_build_with_timestamp.sh --dry-run web --release; then
            log_success "Flutter build wrapper dry run completed"
            return 0
        else
            log_error "Flutter build wrapper dry run failed"
            return 1
        fi
    else
        log_warning "Flutter build wrapper not found, skipping test"
        return 0
    fi
}

# Test complete workflow
test_complete_workflow() {
    log_test "Testing complete build-time injection workflow..."
    
    # Step 1: Prepare version
    if ! ./scripts/version_manager.sh prepare build > /dev/null; then
        log_error "Step 1 failed: Version preparation"
        return 1
    fi
    
    # Step 2: Verify placeholder
    local build_number=$(./scripts/version_manager.sh get-build)
    if [[ "$build_number" != "BUILD_TIME_PLACEHOLDER" ]]; then
        log_error "Step 2 failed: Placeholder not set"
        return 1
    fi
    
    # Step 3: Inject build timestamp
    if ! ./scripts/build_time_version_injector.sh inject > /dev/null; then
        log_error "Step 3 failed: Timestamp injection"
        return 1
    fi
    
    # Step 4: Verify real timestamp
    build_number=$(./scripts/version_manager.sh get-build)
    if [[ ! "$build_number" =~ ^[0-9]{12}$ ]]; then
        log_error "Step 4 failed: Invalid timestamp format"
        return 1
    fi
    
    # Step 5: Restore original state
    if ! ./scripts/build_time_version_injector.sh restore > /dev/null; then
        log_error "Step 5 failed: Restoration"
        return 1
    fi
    
    log_success "Complete workflow test passed"
    return 0
}

# Main test execution
main() {
    echo -e "${BLUE}CloudToLocalLLM Build-Time Timestamp Injection Test Suite${NC}"
    echo -e "${BLUE}=========================================================${NC}"
    echo ""
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Create test backup
    create_test_backup
    
    # Set up cleanup trap
    trap 'restore_test_backup' EXIT
    
    # Run tests
    local tests_passed=0
    local tests_total=6
    
    if test_version_preparation; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_build_time_injection; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_version_synchronization; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_backup_restore; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_flutter_build_wrapper; then
        ((tests_passed++))
    fi
    echo ""
    
    if test_complete_workflow; then
        ((tests_passed++))
    fi
    echo ""
    
    # Summary
    echo -e "${BLUE}Test Results Summary${NC}"
    echo -e "${BLUE}===================${NC}"
    echo -e "Tests passed: ${GREEN}$tests_passed${NC}/$tests_total"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        echo -e "${GREEN}✅ All tests passed! Build-time timestamp injection is working correctly.${NC}"
        echo ""
        echo -e "${BLUE}Build-Time Injection Workflow:${NC}"
        echo "  1. ./scripts/version_manager.sh prepare build    # Prepare with placeholder"
        echo "  2. ./scripts/flutter_build_with_timestamp.sh ... # Build with timestamp injection"
        echo "  3. Build artifacts contain actual build execution timestamp"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"
