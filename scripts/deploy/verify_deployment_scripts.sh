#!/bin/bash

# CloudToLocalLLM Deployment Scripts Verification Tool
# Tests the fixed deployment scripts to ensure they function correctly

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TESTS_TOTAL++))
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test functions
test_syntax_validation() {
    log_test "Testing deployment script syntax validation"
    
    if bash -n scripts/deploy/complete_automated_deployment.sh; then
        log_pass "complete_automated_deployment.sh syntax is valid"
    else
        log_fail "complete_automated_deployment.sh has syntax errors"
        return 1
    fi
    
    if bash -n scripts/deploy/update_and_deploy.sh; then
        log_pass "update_and_deploy.sh syntax is valid"
    else
        log_fail "update_and_deploy.sh has syntax errors"
        return 1
    fi
    
    if bash -n scripts/deploy/deployment_utils.sh; then
        log_pass "deployment_utils.sh syntax is valid"
    else
        log_fail "deployment_utils.sh has syntax errors"
        return 1
    fi
}

test_utilities_loading() {
    log_test "Testing deployment utilities loading"
    
    if timeout 10 bash -c "source scripts/deploy/deployment_utils.sh && echo 'Utils loaded successfully'" &> /dev/null; then
        log_pass "Deployment utilities load without hanging"
    else
        log_fail "Deployment utilities failed to load or hung"
        return 1
    fi
}

test_help_command() {
    log_test "Testing help command execution"
    
    if timeout 15 ./scripts/deploy/complete_automated_deployment.sh --help &> /dev/null; then
        log_pass "Help command executes successfully"
    else
        log_fail "Help command failed or hung"
        return 1
    fi
}

test_dry_run_execution() {
    log_test "Testing dry run execution"
    
    # This test may fail due to git status, but should not hang
    if timeout 30 ./scripts/deploy/complete_automated_deployment.sh --dry-run --verbose &> /tmp/dry_run_test.log; then
        log_pass "Dry run completed successfully"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_fail "Dry run timed out (script hanging)"
            return 1
        elif [[ $exit_code -eq 2 ]]; then
            log_pass "Dry run failed with validation error (expected behavior)"
        else
            log_warning "Dry run failed with exit code $exit_code (may be expected)"
        fi
    fi
}

test_script_permissions() {
    log_test "Testing script permissions"
    
    if [[ -x scripts/deploy/complete_automated_deployment.sh ]]; then
        log_pass "complete_automated_deployment.sh is executable"
    else
        log_fail "complete_automated_deployment.sh is not executable"
    fi
    
    if [[ -x scripts/deploy/update_and_deploy.sh ]]; then
        log_pass "update_and_deploy.sh is executable"
    else
        log_fail "update_and_deploy.sh is not executable"
    fi
}

test_required_files() {
    log_test "Testing required files existence"
    
    local required_files=(
        "scripts/deploy/complete_automated_deployment.sh"
        "scripts/deploy/update_and_deploy.sh"
        "scripts/deploy/deployment_utils.sh"
        "scripts/flutter_build_with_timestamp.sh"
        "scripts/build_time_version_injector.sh"
        "scripts/version_manager.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_pass "Required file exists: $file"
        else
            log_fail "Required file missing: $file"
        fi
    done
}

# Main execution
main() {
    echo -e "${BLUE}CloudToLocalLLM Deployment Scripts Verification${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
    
    # Change to project root
    cd "$(dirname "$0")/../.."
    
    log_info "Running deployment script verification tests..."
    echo ""
    
    # Run tests
    test_required_files
    echo ""
    
    test_script_permissions
    echo ""
    
    test_syntax_validation
    echo ""
    
    test_utilities_loading
    echo ""
    
    test_help_command
    echo ""
    
    test_dry_run_execution
    echo ""
    
    # Display results
    echo -e "${BLUE}Test Results Summary${NC}"
    echo -e "${BLUE}====================${NC}"
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed! Deployment scripts are ready for use.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please review and fix issues before deployment.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"
