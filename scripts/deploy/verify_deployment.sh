#!/bin/bash

# CloudToLocalLLM Deployment Verification Script
# Comprehensive verification of VPS deployment status and functionality
# Validates containers, endpoints, SSL certificates, and application health
#
# STRICT SUCCESS CRITERIA: Zero tolerance for warnings or errors
# - Any warning condition will cause deployment failure and trigger rollback
# - Only completely clean deployments (no warnings, no errors) are considered successful
# - This ensures production deployments meet the highest quality standards

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/cloudtolocalllm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

# Check VPS connectivity
check_vps_connectivity() {
    log_step 1 "Checking VPS connectivity..."
    
    if ssh -o ConnectTimeout=10 "$VPS_USER@$VPS_HOST" "echo 'VPS connection successful'" >/dev/null 2>&1; then
        log_success "VPS connectivity verified"
        return 0
    else
        log_error "Cannot connect to VPS: $VPS_USER@$VPS_HOST"
        return 1
    fi
}

# Verify Docker containers
verify_containers() {
    log_step 2 "Verifying Docker containers..."
    
    local containers_status=$(ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'")
    
    echo "$containers_status"
    
    # Check if all required containers are running
    local required_containers=("webapp" "api-backend")
    local all_running=true
    
    for container in "${required_containers[@]}"; do
        if echo "$containers_status" | grep -q "$container.*Up"; then
            log_success "Container $container is running"
        else
            log_error "Container $container is not running"
            all_running=false
        fi
    done
    
    if $all_running; then
        log_success "All required containers are running"
        return 0
    else
        log_error "Some containers are not running properly"
        return 1
    fi
}

# Check HTTP endpoints
check_http_endpoints() {
    log_step 3 "Checking HTTP endpoints..."
    
    local endpoints=(
        "http://cloudtolocalllm.online"
        "http://app.cloudtolocalllm.online"
    )
    
    local all_accessible=true
    
    for endpoint in "${endpoints[@]}"; do
        log_info "Checking $endpoint..."
        
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$endpoint" || echo "000")
        
        if [[ "$http_code" == "200" ]]; then
            log_success "$endpoint is accessible (HTTP $http_code)"
        elif [[ "$http_code" == "301" || "$http_code" == "302" ]]; then
            log_critical "$endpoint returned redirect (HTTP $http_code) - STRICT MODE: Redirects not allowed"
            all_accessible=false
        else
            log_error "$endpoint is not accessible (HTTP $http_code)"
            all_accessible=false
        fi
    done
    
    if $all_accessible; then
        log_success "All HTTP endpoints are accessible"
        return 0
    else
        log_error "Some HTTP endpoints are not accessible"
        return 1
    fi
}

# Check HTTPS endpoints and SSL certificates
check_https_endpoints() {
    log_step 4 "Checking HTTPS endpoints and SSL certificates..."
    
    local https_endpoints=(
        "https://cloudtolocalllm.online"
        "https://app.cloudtolocalllm.online"
    )
    
    local ssl_valid=true
    
    for endpoint in "${https_endpoints[@]}"; do
        log_info "Checking SSL for $endpoint..."
        
        # Check SSL certificate validity
        local ssl_info=$(echo | openssl s_client -servername "${endpoint#https://}" -connect "${endpoint#https://}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL_ERROR")
        
        if [[ "$ssl_info" != "SSL_ERROR" ]]; then
            local not_after=$(echo "$ssl_info" | grep "notAfter" | cut -d= -f2)
            log_success "$endpoint SSL certificate is valid (expires: $not_after)"
            
            # Check HTTP response
            local https_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$endpoint" || echo "000")
            if [[ "$https_code" == "200" ]]; then
                log_success "$endpoint HTTPS is accessible (HTTP $https_code)"
            else
                log_critical "$endpoint HTTPS returned HTTP $https_code - STRICT MODE: Non-200 HTTPS responses not allowed"
                ssl_valid=false
            fi
        else
            log_critical "$endpoint SSL certificate check failed or not configured - STRICT MODE: All SSL certificates must be valid"
            ssl_valid=false
        fi
    done
    
    if $ssl_valid; then
        log_success "SSL certificates are valid"
        return 0
    else
        log_critical "SSL certificate validation failed - STRICT MODE: All certificates must be valid"
        return 1
    fi
}

# Check application health
check_application_health() {
    log_step 5 "Checking application health..."
    
    # Check if version endpoint is accessible
    local version_endpoint="http://app.cloudtolocalllm.online/version.json"
    log_info "Checking version endpoint: $version_endpoint"
    
    local version_response=$(curl -s --connect-timeout 10 "$version_endpoint" || echo "ERROR")
    
    if [[ "$version_response" != "ERROR" ]] && echo "$version_response" | jq . >/dev/null 2>&1; then
        local app_version=$(echo "$version_response" | jq -r '.version // "unknown"')
        local build_date=$(echo "$version_response" | jq -r '.build_date // "unknown"')
        log_success "Application version: $app_version (built: $build_date)"
        return 0
    else
        log_error "Application health check failed - version endpoint not accessible"
        return 1
    fi
}

# Check container logs for errors
check_container_logs() {
    log_step 6 "Checking container logs for recent errors..."
    
    local containers=("webapp" "api-backend")
    local errors_found=false
    
    for container in "${containers[@]}"; do
        log_info "Checking logs for $container..."
        
        local recent_errors=$(ssh "$VPS_USER@$VPS_HOST" "cd $VPS_PROJECT_DIR && docker compose logs --tail=50 $container 2>/dev/null | grep -i 'error\|exception\|failed' | tail -5" || echo "")
        
        if [[ -n "$recent_errors" ]]; then
            log_critical "Recent errors found in $container logs - STRICT MODE: No errors allowed:"
            echo "$recent_errors"
            errors_found=true
        else
            log_success "No recent errors in $container logs"
        fi
    done
    
    if $errors_found; then
        log_critical "Container log errors detected - STRICT MODE: No errors allowed in production"
        return 1
    else
        log_success "No recent errors found in container logs"
        return 0
    fi
}

# Check disk space and resources
check_system_resources() {
    log_step 7 "Checking system resources..."
    
    local disk_usage=$(ssh "$VPS_USER@$VPS_HOST" "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" || echo "unknown")
    local memory_usage=$(ssh "$VPS_USER@$VPS_HOST" "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" || echo "unknown")
    
    log_info "Disk usage: ${disk_usage}%"
    log_info "Memory usage: ${memory_usage}%"
    
    local resource_issues=false

    if [[ "$disk_usage" != "unknown" ]] && [[ "$disk_usage" -lt 90 ]]; then
        log_success "Disk usage is acceptable (${disk_usage}%)"
    else
        log_critical "Disk usage is high (${disk_usage}%) - STRICT MODE: Must be below 90%"
        resource_issues=true
    fi

    if [[ "$memory_usage" != "unknown" ]] && (( $(echo "$memory_usage < 90" | bc -l) )); then
        log_success "Memory usage is acceptable (${memory_usage}%)"
    else
        log_critical "Memory usage is high (${memory_usage}%) - STRICT MODE: Must be below 90%"
        resource_issues=true
    fi

    if $resource_issues; then
        return 1
    else
        return 0
    fi
}

# Generate verification report
generate_report() {
    local overall_status="$1"
    
    echo
    echo "=== CloudToLocalLLM Deployment Verification Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "VPS Host: $VPS_HOST"
    echo "Overall Status: $overall_status"
    echo
    
    if [[ "$overall_status" == "HEALTHY" ]]; then
        echo "✅ Deployment is healthy and fully operational"
        echo "🌐 Web interfaces are accessible with perfect HTTP 200 responses"
        echo "🔒 SSL certificates are valid and properly configured"
        echo "📦 All containers are running without any errors"
        echo "💚 Application health checks passed completely"
        echo "🎯 STRICT SUCCESS: Zero warnings, zero errors detected"
    else
        echo "❌ Deployment FAILED strict quality standards"
        echo "🚫 STRICT MODE: Any warning or error triggers failure"
        echo "📋 Review the verification steps above for critical issues"
        echo "🔄 Automatic rollback will be initiated"
        echo "🎯 SUCCESS CRITERIA: Zero warnings AND zero errors required"
    fi
    
    echo
    echo "Quick access URLs:"
    echo "- Flutter Homepage: http://cloudtolocalllm.online"
    echo "- Flutter Web App: http://app.cloudtolocalllm.online"
    echo "- HTTPS Homepage: https://cloudtolocalllm.online"
    echo "- HTTPS Web App: https://app.cloudtolocalllm.online"
    echo
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM deployment verification..."
    echo
    
    local verification_passed=true
    
    # Run all verification steps
    check_vps_connectivity || verification_passed=false
    echo
    
    verify_containers || verification_passed=false
    echo
    
    check_http_endpoints || verification_passed=false
    echo
    
    check_https_endpoints || verification_passed=false
    echo
    
    check_application_health || verification_passed=false
    echo
    
    check_container_logs || verification_passed=false
    echo
    
    check_system_resources || verification_passed=false
    echo
    
    # Generate final report
    if $verification_passed; then
        generate_report "HEALTHY"
        log_success "STRICT VERIFICATION PASSED: Deployment meets highest quality standards!"
        log_success "Zero warnings, zero errors - Production deployment approved"
        exit 0
    else
        generate_report "FAILED"
        log_critical "STRICT VERIFICATION FAILED: Deployment does not meet quality standards"
        log_critical "Automatic rollback will be triggered due to strict success criteria"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Deployment Verification Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script performs STRICT verification with zero tolerance policy:"
        echo "  - VPS connectivity and SSH access (must be perfect)"
        echo "  - Docker container status and health (no errors allowed)"
        echo "  - HTTP/HTTPS endpoint accessibility (HTTP 200 only)"
        echo "  - SSL certificate validity (all certificates must be valid)"
        echo "  - Application health and version info (must be accessible)"
        echo "  - Container logs for recent errors (zero errors required)"
        echo "  - System resource usage (must be below 90%)"
        echo
        echo "STRICT SUCCESS CRITERIA:"
        echo "  - Zero warnings AND zero errors required for success"
        echo "  - Any warning condition triggers deployment failure"
        echo "  - Automatic rollback on any quality standard violation"
        echo "  - Only completely clean deployments are approved"
        echo
        echo "Requirements:"
        echo "  - SSH access to $VPS_USER@$VPS_HOST"
        echo "  - curl, openssl, jq, bc commands available"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
