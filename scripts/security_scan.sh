#!/bin/bash

# CloudToLocalLLM Security Scan Script
# Performs comprehensive security scanning including port scans, vulnerability checks,
# file permissions, and security configuration validation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/cloudtolocalllm"

# Security scan configuration
SCAN_REPORT_DIR="/var/log/cloudtolocalllm/security"

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

# Security status tracking
SECURITY_STATUS="SECURE"
WARNINGS=0
VULNERABILITIES=0
CRITICAL_ISSUES=0

# Update security status
update_security_status() {
    local level="$1"
    case $level in
        WARNING)
            ((WARNINGS++))
            if [[ "$SECURITY_STATUS" == "SECURE" ]]; then
                SECURITY_STATUS="WARNING"
            fi
            ;;
        VULNERABILITY)
            ((VULNERABILITIES++))
            if [[ "$SECURITY_STATUS" != "CRITICAL" ]]; then
                SECURITY_STATUS="VULNERABLE"
            fi
            ;;
        CRITICAL)
            ((CRITICAL_ISSUES++))
            SECURITY_STATUS="CRITICAL"
            ;;
    esac
}

# Check if running on VPS or locally
is_vps_environment() {
    [[ "$(hostname)" == *"cloudtolocalllm"* ]] || [[ -f "/opt/cloudtolocalllm/docker-compose.yml" ]]
}

# Execute command on VPS or locally
execute_command() {
    local cmd="$1"
    
    if is_vps_environment; then
        eval "$cmd"
    else
        ssh "$VPS_USER@$VPS_HOST" "$cmd"
    fi
}

# Scan open ports
scan_open_ports() {
    log_step 1 "Scanning open ports..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== PORT SCAN RESULTS ===
EOF"
    
    # Check listening ports
    local listening_ports=$(execute_command "netstat -tuln | grep LISTEN" || echo "")
    execute_command "echo 'Listening Ports:' >> $report_file"
    execute_command "echo '$listening_ports' >> $report_file"
    execute_command "echo '' >> $report_file"
    
    # Check for unexpected open ports
    local unexpected_ports=()
    local expected_ports=(22 80 443 3000)
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
            local found=false
            
            for expected in "${expected_ports[@]}"; do
                if [[ "$port" == "$expected" ]]; then
                    found=true
                    break
                fi
            done
            
            if [[ "$found" == "false" ]] && [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -lt 65536 ]]; then
                unexpected_ports+=("$port")
            fi
        fi
    done <<< "$listening_ports"
    
    if [[ ${#unexpected_ports[@]} -gt 0 ]]; then
        log_warning "Unexpected open ports found: ${unexpected_ports[*]}"
        execute_command "echo 'WARNING: Unexpected open ports: ${unexpected_ports[*]}' >> $report_file"
        update_security_status "WARNING"
    else
        log_success "All open ports are expected"
        execute_command "echo 'All open ports are expected and authorized' >> $report_file"
    fi
    
    execute_command "echo '' >> $report_file"
}

# Check file permissions
check_file_permissions() {
    log_step 2 "Checking critical file permissions..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== FILE PERMISSIONS AUDIT ===
EOF"
    
    # Critical system files
    local critical_files=(
        "/etc/passwd:644"
        "/etc/shadow:640"
        "/etc/ssh/sshd_config:644"
        "/etc/sudoers:440"
    )
    
    execute_command "echo 'Critical System Files:' >> $report_file"
    
    for file_perm in "${critical_files[@]}"; do
        local file=$(echo "$file_perm" | cut -d: -f1)
        local expected_perm=$(echo "$file_perm" | cut -d: -f2)
        
        if execute_command "test -f $file"; then
            local actual_perm=$(execute_command "stat -c '%a' $file" || echo "unknown")
            
            if [[ "$actual_perm" == "$expected_perm" ]]; then
                log_success "✓ $file ($actual_perm)"
                execute_command "echo '✓ $file: $actual_perm (correct)' >> $report_file"
            else
                log_warning "✗ $file has incorrect permissions ($actual_perm, expected $expected_perm)"
                execute_command "echo '✗ $file: $actual_perm (expected $expected_perm)' >> $report_file"
                update_security_status "WARNING"
            fi
        else
            execute_command "echo '- $file: not found' >> $report_file"
        fi
    done
    
    # Application files
    execute_command "echo '' >> $report_file"
    execute_command "echo 'Application Files:' >> $report_file"
    
    if execute_command "test -f $VPS_PROJECT_DIR/docker-compose.yml"; then
        local compose_perm=$(execute_command "stat -c '%a' $VPS_PROJECT_DIR/docker-compose.yml")
        execute_command "echo 'docker-compose.yml: $compose_perm' >> $report_file"
        
        if [[ "$compose_perm" == "644" || "$compose_perm" == "600" ]]; then
            log_success "✓ docker-compose.yml permissions are secure"
        else
            log_warning "✗ docker-compose.yml has overly permissive permissions ($compose_perm)"
            update_security_status "WARNING"
        fi
    fi
    
    execute_command "echo '' >> $report_file"
}

# Check SSH configuration
check_ssh_security() {
    log_step 3 "Checking SSH security configuration..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== SSH SECURITY AUDIT ===
EOF"
    
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_issues=()
    
    # Check SSH configuration
    if execute_command "test -f $ssh_config"; then
        # Check root login
        local root_login=$(execute_command "grep -E '^PermitRootLogin' $ssh_config | awk '{print \$2}'" || echo "unknown")
        if [[ "$root_login" == "no" ]]; then
            log_success "✓ Root login is disabled"
            execute_command "echo '✓ Root login: disabled' >> $report_file"
        else
            log_warning "✗ Root login is enabled or not explicitly disabled"
            execute_command "echo '✗ Root login: $root_login (should be no)' >> $report_file"
            ssh_issues+=("root_login")
            update_security_status "WARNING"
        fi
        
        # Check password authentication
        local password_auth=$(execute_command "grep -E '^PasswordAuthentication' $ssh_config | awk '{print \$2}'" || echo "unknown")
        if [[ "$password_auth" == "no" ]]; then
            log_success "✓ Password authentication is disabled"
            execute_command "echo '✓ Password authentication: disabled' >> $report_file"
        else
            log_warning "✗ Password authentication is enabled"
            execute_command "echo '✗ Password authentication: $password_auth (consider disabling)' >> $report_file"
            ssh_issues+=("password_auth")
            update_security_status "WARNING"
        fi
        
        # Check SSH protocol version
        local protocol=$(execute_command "grep -E '^Protocol' $ssh_config | awk '{print \$2}'" || echo "2")
        if [[ "$protocol" == "2" ]]; then
            log_success "✓ SSH protocol version 2 is used"
            execute_command "echo '✓ SSH protocol: version 2' >> $report_file"
        else
            log_critical "✗ Insecure SSH protocol version ($protocol)"
            execute_command "echo '✗ SSH protocol: version $protocol (should be 2)' >> $report_file"
            ssh_issues+=("protocol")
            update_security_status "CRITICAL"
        fi
    else
        log_error "SSH configuration file not found"
        execute_command "echo 'SSH configuration file not found' >> $report_file"
        update_security_status "VULNERABILITY"
    fi
    
    # Check for failed login attempts
    local failed_logins=$(execute_command "grep 'Failed password' /var/log/auth.log 2>/dev/null | wc -l" || echo "0")
    execute_command "echo 'Recent failed login attempts: $failed_logins' >> $report_file"
    
    if [[ "$failed_logins" -gt 100 ]]; then
        log_warning "High number of failed login attempts ($failed_logins)"
        update_security_status "WARNING"
    fi
    
    execute_command "echo '' >> $report_file"
}

# Check Docker security
check_docker_security() {
    log_step 4 "Checking Docker security configuration..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== DOCKER SECURITY AUDIT ===
EOF"
    
    if execute_command "docker info >/dev/null 2>&1"; then
        # Check Docker daemon configuration
        execute_command "echo 'Docker Version:' >> $report_file"
        execute_command "docker --version >> $report_file"
        
        # Check running containers
        local containers=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps -q" 2>/dev/null || echo "")
        if [[ -n "$containers" ]]; then
            execute_command "echo '' >> $report_file"
            execute_command "echo 'Container Security:' >> $report_file"
            
            for container in $containers; do
                local container_name=$(execute_command "docker inspect --format='{{.Name}}' $container" | sed 's/^\/*//')
                
                # Check if container is running as root
                local user=$(execute_command "docker inspect --format='{{.Config.User}}' $container" || echo "")
                if [[ -z "$user" ]]; then
                    log_warning "Container $container_name may be running as root"
                    execute_command "echo '⚠️  $container_name: running as root (consider using non-root user)' >> $report_file"
                    update_security_status "WARNING"
                else
                    log_success "✓ Container $container_name is running as user: $user"
                    execute_command "echo '✓ $container_name: running as user $user' >> $report_file"
                fi
                
                # Check for privileged containers
                local privileged=$(execute_command "docker inspect --format='{{.HostConfig.Privileged}}' $container" || echo "false")
                if [[ "$privileged" == "true" ]]; then
                    log_critical "Container $container_name is running in privileged mode"
                    execute_command "echo '🚨 $container_name: privileged mode (security risk)' >> $report_file"
                    update_security_status "CRITICAL"
                else
                    log_success "✓ Container $container_name is not privileged"
                    execute_command "echo '✓ $container_name: not privileged' >> $report_file"
                fi
            done
        else
            execute_command "echo 'No running containers found' >> $report_file"
        fi
    else
        execute_command "echo 'Docker is not running or not available' >> $report_file"
    fi
    
    execute_command "echo '' >> $report_file"
}

# Check for security updates
check_security_updates() {
    log_step 5 "Checking for security updates..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== SECURITY UPDATES AUDIT ===
EOF"
    
    if execute_command "command -v apt-get >/dev/null 2>&1"; then
        # Update package list
        execute_command "apt-get update >/dev/null 2>&1" || true
        
        # Check for security updates
        local security_updates=$(execute_command "apt list --upgradable 2>/dev/null | grep -i security | wc -l" || echo "0")
        execute_command "echo 'Available security updates: $security_updates' >> $report_file"
        
        if [[ "$security_updates" -gt 0 ]]; then
            log_warning "$security_updates security updates available"
            execute_command "echo 'Security updates available:' >> $report_file"
            execute_command "apt list --upgradable 2>/dev/null | grep -i security | head -10 >> $report_file"
            update_security_status "WARNING"
        else
            log_success "No security updates pending"
            execute_command "echo 'System is up to date with security patches' >> $report_file"
        fi
    elif execute_command "command -v yum >/dev/null 2>&1"; then
        local security_updates=$(execute_command "yum --security check-update 2>/dev/null | grep -c 'needed for security' || echo '0'")
        execute_command "echo 'Available security updates: $security_updates' >> $report_file"
        
        if [[ "$security_updates" -gt 0 ]]; then
            log_warning "$security_updates security updates available"
            update_security_status "WARNING"
        else
            log_success "No security updates pending"
        fi
    else
        execute_command "echo 'Package manager not supported for security update check' >> $report_file"
    fi
    
    execute_command "echo '' >> $report_file"
}

# Generate security report summary
generate_security_summary() {
    log_step 6 "Generating security summary..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== SECURITY SCAN SUMMARY ===
Scan Timestamp: \$(date -u +%Y-%m-%dT%H:%M:%SZ)
Overall Security Status: $SECURITY_STATUS
Warnings: $WARNINGS
Vulnerabilities: $VULNERABILITIES
Critical Issues: $CRITICAL_ISSUES

Security Assessment:
EOF"
    
    case $SECURITY_STATUS in
        SECURE)
            execute_command "echo '✅ SECURE - No significant security issues found' >> $report_file"
            ;;
        WARNING)
            execute_command "echo '⚠️  WARNING - Minor security issues that should be addressed' >> $report_file"
            ;;
        VULNERABLE)
            execute_command "echo '🔶 VULNERABLE - Security vulnerabilities found that need attention' >> $report_file"
            ;;
        CRITICAL)
            execute_command "echo '🚨 CRITICAL - Critical security issues requiring immediate action' >> $report_file"
            ;;
    esac
    
    execute_command "cat >> $report_file << 'EOF'

Recommendations:
EOF"
    
    # Generate recommendations based on findings
    if [[ "$CRITICAL_ISSUES" -gt 0 ]]; then
        execute_command "echo '🚨 IMMEDIATE ACTION REQUIRED:' >> $report_file"
        execute_command "echo '  - Address critical security issues immediately' >> $report_file"
        execute_command "echo '  - Review and fix SSH configuration' >> $report_file"
        execute_command "echo '  - Check Docker container security settings' >> $report_file"
    fi
    
    if [[ "$VULNERABILITIES" -gt 0 ]]; then
        execute_command "echo '🔧 SECURITY IMPROVEMENTS NEEDED:' >> $report_file"
        execute_command "echo '  - Apply available security updates' >> $report_file"
        execute_command "echo '  - Review file permissions' >> $report_file"
        execute_command "echo '  - Monitor for suspicious activity' >> $report_file"
    fi
    
    if [[ "$WARNINGS" -gt 0 ]]; then
        execute_command "echo '📋 RECOMMENDED IMPROVEMENTS:' >> $report_file"
        execute_command "echo '  - Review SSH configuration for best practices' >> $report_file"
        execute_command "echo '  - Consider implementing additional security measures' >> $report_file"
        execute_command "echo '  - Regular security monitoring and updates' >> $report_file"
    fi
    
    if [[ "$SECURITY_STATUS" == "SECURE" ]]; then
        execute_command "echo '✅ MAINTAIN CURRENT SECURITY POSTURE:' >> $report_file"
        execute_command "echo '  - Continue regular security updates' >> $report_file"
        execute_command "echo '  - Monitor logs for suspicious activity' >> $report_file"
        execute_command "echo '  - Perform regular security scans' >> $report_file"
    fi
    
    execute_command "echo '' >> $report_file"
    execute_command "echo 'Next security scan recommended: \$(date -d \"+1 week\" +%Y-%m-%d)' >> $report_file"
}

# Main execution function
main() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file="$SCAN_REPORT_DIR/security_scan_$timestamp.txt"
    
    log_info "Starting CloudToLocalLLM security scan..."
    echo
    
    # Create report directory
    execute_command "mkdir -p $SCAN_REPORT_DIR"
    
    # Initialize report file
    execute_command "echo 'CloudToLocalLLM Security Scan Report' > $report_file"
    execute_command "echo '=====================================' >> $report_file"
    execute_command "echo '' >> $report_file"
    
    # Execute security checks
    scan_open_ports "$report_file"
    echo
    
    check_file_permissions "$report_file"
    echo
    
    check_ssh_security "$report_file"
    echo
    
    check_docker_security "$report_file"
    echo
    
    check_security_updates "$report_file"
    echo
    
    generate_security_summary "$report_file"
    echo
    
    # Display results
    log_success "Security scan completed!"
    log_info "Report location: $report_file"
    
    # Show summary
    echo
    echo "=== SECURITY SCAN SUMMARY ==="
    execute_command "tail -15 $report_file"
    
    # Exit with appropriate code
    case $SECURITY_STATUS in
        SECURE)
            exit 0
            ;;
        WARNING)
            exit 1
            ;;
        VULNERABLE)
            exit 2
            ;;
        CRITICAL)
            exit 3
            ;;
    esac
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Security Scan Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script performs comprehensive security scanning:"
        echo "  - Open port scanning and analysis"
        echo "  - Critical file permission auditing"
        echo "  - SSH security configuration review"
        echo "  - Docker container security assessment"
        echo "  - Security update availability check"
        echo "  - Security posture scoring and recommendations"
        echo
        echo "Exit codes:"
        echo "  0 - SECURE (no significant issues)"
        echo "  1 - WARNING (minor issues found)"
        echo "  2 - VULNERABLE (vulnerabilities found)"
        echo "  3 - CRITICAL (critical issues found)"
        echo
        echo "Report directory: $SCAN_REPORT_DIR"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
