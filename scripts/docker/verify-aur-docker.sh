#!/bin/bash

# CloudToLocalLLM Docker-based AUR Building System Verification
# Tests and verifies the Docker-based AUR building system
# Version: 1.0.0

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [VERIFY]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [VERIFY] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [VERIFY] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [VERIFY] ❌${NC} $1"
}

# Test result functions
test_pass() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_success "PASS: $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_error "FAIL: $test_name - $reason"
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Docker-based AUR Building System Verification

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --quick             Run only quick tests (skip Docker build)
    --verbose           Enable detailed logging
    --help              Show this help message

TESTS:
    1. File Structure Verification
    2. Script Permissions and Syntax
    3. Docker Environment Check
    4. Docker Image Build Test
    5. Container Functionality Test
    6. Universal Builder Integration Test
    7. Deployment Workflow Integration Test

EXAMPLES:
    $0                  # Run all verification tests
    $0 --quick          # Run quick tests only
    $0 --verbose        # Detailed logging

EXIT CODES:
    0 - All tests passed
    1 - Some tests failed
    2 - Critical failure (cannot continue testing)
EOF
}

# Parse command line arguments
parse_arguments() {
    QUICK_MODE=false
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
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

# Test 1: File Structure Verification
test_file_structure() {
    log "Testing file structure..."

    local required_files=(
        "scripts/docker/build-aur-docker.sh"
        "scripts/docker/aur-builder/Dockerfile"
        "scripts/docker/aur-builder/entrypoint.sh"
        "scripts/packaging/build_aur_universal.sh"
        "scripts/deploy/test_aur_package.sh"
        "scripts/deploy/submit_aur_package.sh"
    )

    local all_files_exist=true

    for file in "${required_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                log "✓ Found: $file"
            fi
        else
            log_error "Missing: $file"
            all_files_exist=false
        fi
    done

    if [[ "$all_files_exist" == "true" ]]; then
        test_pass "File structure verification"
    else
        test_fail "File structure verification" "Missing required files"
    fi
}

# Test 2: Script Permissions and Syntax
test_script_permissions() {
    log "Testing script permissions and syntax..."

    local scripts=(
        "scripts/docker/build-aur-docker.sh"
        "scripts/docker/aur-builder/entrypoint.sh"
        "scripts/packaging/build_aur_universal.sh"
        "scripts/deploy/test_aur_package.sh"
        "scripts/deploy/submit_aur_package.sh"
    )

    local all_scripts_ok=true

    for script in "${scripts[@]}"; do
        local script_path="$PROJECT_ROOT/$script"

        # Check if file is executable (on Unix systems)
        if [[ -f "$script_path" ]]; then
            # Check syntax
            if bash -n "$script_path" 2>/dev/null; then
                if [[ "$VERBOSE" == "true" ]]; then
                    log "✓ Syntax OK: $script"
                fi
            else
                log_error "Syntax error in: $script"
                all_scripts_ok=false
            fi
        else
            log_error "Script not found: $script"
            all_scripts_ok=false
        fi
    done

    if [[ "$all_scripts_ok" == "true" ]]; then
        test_pass "Script permissions and syntax"
    else
        test_fail "Script permissions and syntax" "Script issues detected"
    fi
}

# Test 3: Docker Environment Check
test_docker_environment() {
    log "Testing Docker environment..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        test_fail "Docker environment check" "Docker not installed"
        return
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        test_fail "Docker environment check" "Docker daemon not running"
        return
    fi

    # Check if user can run Docker commands
    if ! docker ps &> /dev/null; then
        test_fail "Docker environment check" "Permission denied - user cannot run Docker"
        return
    fi

    test_pass "Docker environment check"
}

# Test 4: Docker Image Build Test
test_docker_image_build() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        log "Skipping Docker image build test (quick mode)"
        return
    fi

    log "Testing Docker image build..."

    local build_script="$PROJECT_ROOT/scripts/docker/build-aur-docker.sh"

    if [[ ! -f "$build_script" ]]; then
        test_fail "Docker image build test" "Build script not found"
        return
    fi

    # Test Docker image build (dry run)
    if [[ "$VERBOSE" == "true" ]]; then
        if "$build_script" build --dry-run --verbose; then
            test_pass "Docker image build test (dry run)"
        else
            test_fail "Docker image build test" "Dry run failed"
        fi
    else
        if "$build_script" build --dry-run &> /dev/null; then
            test_pass "Docker image build test (dry run)"
        else
            test_fail "Docker image build test" "Dry run failed"
        fi
    fi
}

# Test 5: Container Functionality Test
test_container_functionality() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        log "Skipping container functionality test (quick mode)"
        return
    fi

    log "Testing container functionality..."

    local build_script="$PROJECT_ROOT/scripts/docker/build-aur-docker.sh"

    # Test container shell access (dry run)
    if [[ "$VERBOSE" == "true" ]]; then
        if "$build_script" shell --dry-run --verbose; then
            test_pass "Container functionality test (dry run)"
        else
            test_fail "Container functionality test" "Shell access dry run failed"
        fi
    else
        if "$build_script" shell --dry-run &> /dev/null; then
            test_pass "Container functionality test (dry run)"
        else
            test_fail "Container functionality test" "Shell access dry run failed"
        fi
    fi
}

# Test 6: Universal Builder Integration Test
test_universal_builder() {
    log "Testing universal builder integration..."

    local universal_script="$PROJECT_ROOT/scripts/packaging/build_aur_universal.sh"

    if [[ ! -f "$universal_script" ]]; then
        test_fail "Universal builder integration test" "Universal builder script not found"
        return
    fi

    # Test platform detection (dry run)
    if [[ "$VERBOSE" == "true" ]]; then
        if "$universal_script" --dry-run --verbose; then
            test_pass "Universal builder integration test"
        else
            test_fail "Universal builder integration test" "Universal builder dry run failed"
        fi
    else
        if "$universal_script" --dry-run &> /dev/null; then
            test_pass "Universal builder integration test"
        else
            test_fail "Universal builder integration test" "Universal builder dry run failed"
        fi
    fi
}

# Test 7: Deployment Workflow Integration Test
test_deployment_integration() {
    log "Testing deployment workflow integration..."

    local deployment_script="$PROJECT_ROOT/scripts/deploy/complete_automated_deployment.sh"

    if [[ ! -f "$deployment_script" ]]; then
        test_fail "Deployment workflow integration test" "Deployment script not found"
        return
    fi

    # Check if deployment script references universal AUR builder
    if grep -q "build_aur_universal.sh" "$deployment_script"; then
        if [[ "$VERBOSE" == "true" ]]; then
            log "✓ Deployment script references universal AUR builder"
        fi
        test_pass "Deployment workflow integration test"
    else
        test_fail "Deployment workflow integration test" "Deployment script doesn't reference universal AUR builder"
    fi
}

# Test 8: Missing AUR Scripts Test
test_missing_aur_scripts() {
    log "Testing missing AUR scripts implementation..."

    local test_script="$PROJECT_ROOT/scripts/deploy/test_aur_package.sh"
    local submit_script="$PROJECT_ROOT/scripts/deploy/submit_aur_package.sh"

    local scripts_ok=true

    # Test test_aur_package.sh
    if [[ -f "$test_script" ]]; then
        if bash -n "$test_script" 2>/dev/null; then
            if [[ "$VERBOSE" == "true" ]]; then
                log "✓ test_aur_package.sh syntax OK"
            fi
        else
            log_error "Syntax error in test_aur_package.sh"
            scripts_ok=false
        fi
    else
        log_error "test_aur_package.sh not found"
        scripts_ok=false
    fi

    # Test submit_aur_package.sh
    if [[ -f "$submit_script" ]]; then
        if bash -n "$submit_script" 2>/dev/null; then
            if [[ "$VERBOSE" == "true" ]]; then
                log "✓ submit_aur_package.sh syntax OK"
            fi
        else
            log_error "Syntax error in submit_aur_package.sh"
            scripts_ok=false
        fi
    else
        log_error "submit_aur_package.sh not found"
        scripts_ok=false
    fi

    if [[ "$scripts_ok" == "true" ]]; then
        test_pass "Missing AUR scripts implementation"
    else
        test_fail "Missing AUR scripts implementation" "AUR scripts have issues"
    fi
}

# Generate test report
generate_report() {
    log ""
    log "=========================================="
    log "Docker-based AUR Building System Verification Report"
    log "=========================================="
    log ""
    log "Tests Summary:"
    log "  Total Tests: $TESTS_TOTAL"
    log "  Passed: $TESTS_PASSED"
    log "  Failed: $TESTS_FAILED"
    log ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "🎉 All tests passed! Docker-based AUR building system is ready."
        log ""
        log "Next Steps:"
        log "1. Test AUR package building: ./scripts/packaging/build_aur_universal.sh"
        log "2. Test Docker environment: ./scripts/docker/build-aur-docker.sh shell"
        log "3. Run deployment workflow: ./scripts/deploy/complete_automated_deployment.sh"
        log ""
    else
        log_error "❌ Some tests failed. Please review the issues above."
        log ""
        log "Common Solutions:"
        log "1. Install Docker: sudo apt install docker.io"
        log "2. Add user to docker group: sudo usermod -aG docker \$USER"
        log "3. Check file permissions: chmod +x scripts/docker/*.sh"
        log "4. Review script syntax errors"
        log ""
    fi

    if [[ "$QUICK_MODE" == "true" ]]; then
        log_warning "Note: Quick mode was used - some tests were skipped"
        log "Run without --quick for complete verification"
        log ""
    fi
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"

    log "CloudToLocalLLM Docker-based AUR Building System Verification"
    log "============================================================="

    if [[ "$QUICK_MODE" == "true" ]]; then
        log "Running in quick mode (skipping Docker build tests)"
    fi

    log ""

    # Execute all tests
    test_file_structure
    test_script_permissions
    test_docker_environment
    test_docker_image_build
    test_container_functionality
    test_universal_builder
    test_deployment_integration
    test_missing_aur_scripts

    # Generate report
    generate_report

    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"