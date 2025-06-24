#!/bin/bash

# CloudToLocalLLM Health Check Script
# Comprehensive system health monitoring including containers, endpoints,
# resources, and application functionality verification

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/cloudtolocalllm"

# Health check thresholds
CPU_WARNING_THRESHOLD=80
CPU_CRITICAL_THRESHOLD=95
MEMORY_WARNING_THRESHOLD=80
MEMORY_CRITICAL_THRESHOLD=95
DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90
RESPONSE_TIME_WARNING=5
RESPONSE_TIME_CRITICAL=10

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
    echo -e "${CYAN}[CHECK $1]${NC} $2"
}

# Health status tracking
HEALTH_STATUS="HEALTHY"
WARNING_COUNT=0
ERROR_COUNT=0
CRITICAL_COUNT=0

# Update health status
update_health_status() {
    local level="$1"
    case $level in
        WARNING)
            ((WARNING_COUNT++))
            if [[ "$HEALTH_STATUS" == "HEALTHY" ]]; then
                HEALTH_STATUS="WARNING"
            fi
            ;;
        ERROR)
            ((ERROR_COUNT++))
            if [[ "$HEALTH_STATUS" != "CRITICAL" ]]; then
                HEALTH_STATUS="ERROR"
            fi
            ;;
        CRITICAL)
            ((CRITICAL_COUNT++))
            HEALTH_STATUS="CRITICAL"
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

# Check system resources
check_system_resources() {
    log_step 1 "Checking system resources..."
    
    # CPU usage check
    local cpu_usage=$(execute_command "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" || echo "0")
    log_info "CPU usage: ${cpu_usage}%"
    
    if (( $(echo "$cpu_usage > $CPU_CRITICAL_THRESHOLD" | bc -l) )); then
        log_critical "CPU usage is critically high (${cpu_usage}%)"
        update_health_status "CRITICAL"
    elif (( $(echo "$cpu_usage > $CPU_WARNING_THRESHOLD" | bc -l) )); then
        log_warning "CPU usage is high (${cpu_usage}%)"
        update_health_status "WARNING"
    else
        log_success "CPU usage is normal (${cpu_usage}%)"
    fi
    
    # Memory usage check
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" || echo "0")
    log_info "Memory usage: ${memory_usage}%"
    
    if (( $(echo "$memory_usage > $MEMORY_CRITICAL_THRESHOLD" | bc -l) )); then
        log_critical "Memory usage is critically high (${memory_usage}%)"
        update_health_status "CRITICAL"
    elif (( $(echo "$memory_usage > $MEMORY_WARNING_THRESHOLD" | bc -l) )); then
        log_warning "Memory usage is high (${memory_usage}%)"
        update_health_status "WARNING"
    else
        log_success "Memory usage is normal (${memory_usage}%)"
    fi
    
    # Disk usage check
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" || echo "0")
    log_info "Disk usage: ${disk_usage}%"
    
    if [[ "$disk_usage" -gt "$DISK_CRITICAL_THRESHOLD" ]]; then
        log_critical "Disk usage is critically high (${disk_usage}%)"
        update_health_status "CRITICAL"
    elif [[ "$disk_usage" -gt "$DISK_WARNING_THRESHOLD" ]]; then
        log_warning "Disk usage is high (${disk_usage}%)"
        update_health_status "WARNING"
    else
        log_success "Disk usage is normal (${disk_usage}%)"
    fi
    
    # Load average check
    local load_avg=$(execute_command "uptime | awk '{print \$(NF-2)}' | sed 's/,//'" || echo "0")
    local cpu_cores=$(execute_command "nproc" || echo "1")
    local load_percentage=$(echo "scale=1; $load_avg * 100 / $cpu_cores" | bc -l || echo "0")
    log_info "Load average: $load_avg (${load_percentage}% of $cpu_cores cores)"
    
    if (( $(echo "$load_percentage > 200" | bc -l) )); then
        log_critical "System load is critically high (${load_percentage}%)"
        update_health_status "CRITICAL"
    elif (( $(echo "$load_percentage > 100" | bc -l) )); then
        log_warning "System load is high (${load_percentage}%)"
        update_health_status "WARNING"
    else
        log_success "System load is normal (${load_percentage}%)"
    fi
}

# Check Docker containers
check_docker_containers() {
    log_step 2 "Checking Docker containers..."
    
    # Check if Docker is running
    if ! execute_command "docker info >/dev/null 2>&1"; then
        log_critical "Docker daemon is not running"
        update_health_status "CRITICAL"
        return
    fi
    
    # Check application containers
    local containers_status=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "")
    
    if [[ -z "$containers_status" ]]; then
        log_error "No Docker containers found"
        update_health_status "ERROR"
        return
    fi
    
    echo "$containers_status"
    
    # Check required containers
    local required_containers=("webapp" "api-backend")
    local unhealthy_containers=()
    
    for container in "${required_containers[@]}"; do
        if echo "$containers_status" | grep -q "$container.*Up"; then
            log_success "Container $container is running"
        else
            log_error "Container $container is not running"
            unhealthy_containers+=("$container")
            update_health_status "ERROR"
        fi
    done
    
    # Check container resource usage
    local container_stats=$(execute_command "cd $VPS_PROJECT_DIR && docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'" 2>/dev/null || echo "")
    if [[ -n "$container_stats" ]]; then
        log_info "Container resource usage:"
        echo "$container_stats"
    fi
}

# Check network connectivity
check_network_connectivity() {
    log_step 3 "Checking network connectivity..."
    
    # Check external connectivity
    if execute_command "ping -c 1 8.8.8.8 >/dev/null 2>&1"; then
        log_success "External network connectivity is working"
    else
        log_error "External network connectivity failed"
        update_health_status "ERROR"
    fi
    
    # Check DNS resolution
    if execute_command "nslookup google.com >/dev/null 2>&1"; then
        log_success "DNS resolution is working"
    else
        log_error "DNS resolution failed"
        update_health_status "ERROR"
    fi
    
    # Check listening ports
    local required_ports=(80 443)
    for port in "${required_ports[@]}"; do
        if execute_command "netstat -tuln | grep -q ':$port '"; then
            log_success "Port $port is listening"
        else
            log_warning "Port $port is not listening"
            update_health_status "WARNING"
        fi
    done
}

# Check application endpoints
check_application_endpoints() {
    log_step 4 "Checking application endpoints..."
    
    local endpoints=(
        "http://cloudtolocalllm.online"
        "http://app.cloudtolocalllm.online"
        "https://cloudtolocalllm.online"
        "https://app.cloudtolocalllm.online"
    )
    
    for endpoint in "${endpoints[@]}"; do
        log_info "Checking $endpoint..."
        
        local start_time=$(date +%s.%N)
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$endpoint" || echo "000")
        local end_time=$(date +%s.%N)
        local response_time=$(echo "$end_time - $start_time" | bc -l | awk '{printf "%.2f", $1}')
        
        if [[ "$http_code" == "200" ]]; then
            if (( $(echo "$response_time > $RESPONSE_TIME_CRITICAL" | bc -l) )); then
                log_critical "$endpoint is slow (${response_time}s, HTTP $http_code)"
                update_health_status "CRITICAL"
            elif (( $(echo "$response_time > $RESPONSE_TIME_WARNING" | bc -l) )); then
                log_warning "$endpoint is slow (${response_time}s, HTTP $http_code)"
                update_health_status "WARNING"
            else
                log_success "$endpoint is accessible (${response_time}s, HTTP $http_code)"
            fi
        elif [[ "$http_code" == "301" || "$http_code" == "302" ]]; then
            log_warning "$endpoint returned redirect (${response_time}s, HTTP $http_code)"
            update_health_status "WARNING"
        else
            log_error "$endpoint is not accessible (${response_time}s, HTTP $http_code)"
            update_health_status "ERROR"
        fi
    done
}

# Check SSL certificates
check_ssl_certificates() {
    log_step 5 "Checking SSL certificates..."
    
    local domains=("cloudtolocalllm.online" "app.cloudtolocalllm.online")
    
    for domain in "${domains[@]}"; do
        log_info "Checking SSL certificate for $domain..."
        
        local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL_ERROR")
        
        if [[ "$cert_info" != "SSL_ERROR" ]]; then
            local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
            local current_date=$(date +%s)
            local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
            
            if [[ "$days_until_expiry" -lt 0 ]]; then
                log_critical "$domain SSL certificate has expired!"
                update_health_status "CRITICAL"
            elif [[ "$days_until_expiry" -lt 7 ]]; then
                log_critical "$domain SSL certificate expires in $days_until_expiry days"
                update_health_status "CRITICAL"
            elif [[ "$days_until_expiry" -lt 30 ]]; then
                log_warning "$domain SSL certificate expires in $days_until_expiry days"
                update_health_status "WARNING"
            else
                log_success "$domain SSL certificate is valid (expires in $days_until_expiry days)"
            fi
        else
            log_error "Failed to check SSL certificate for $domain"
            update_health_status "ERROR"
        fi
    done
}

# Check system services
check_system_services() {
    log_step 6 "Checking system services..."
    
    local required_services=("nginx" "docker" "ssh")
    
    for service in "${required_services[@]}"; do
        if execute_command "systemctl is-active $service >/dev/null 2>&1"; then
            log_success "Service $service is running"
        else
            log_error "Service $service is not running"
            update_health_status "ERROR"
        fi
    done
}

# Check log files for errors
check_log_errors() {
    log_step 7 "Checking recent log errors..."
    
    # Check application logs
    local app_errors=$(execute_command "grep -i 'error\|exception\|failed' /var/log/cloudtolocalllm/*.log 2>/dev/null | tail -5" || echo "")
    if [[ -n "$app_errors" ]]; then
        log_warning "Recent application errors found:"
        echo "$app_errors"
        update_health_status "WARNING"
    else
        log_success "No recent application errors found"
    fi
    
    # Check system logs
    local sys_errors=$(execute_command "grep -i 'error\|critical' /var/log/syslog 2>/dev/null | tail -5" || echo "")
    if [[ -n "$sys_errors" ]]; then
        log_warning "Recent system errors found:"
        echo "$sys_errors"
        update_health_status "WARNING"
    else
        log_success "No recent system errors found"
    fi
}

# Generate health report
generate_health_report() {
    echo
    echo "=== CloudToLocalLLM Health Check Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Overall Status: $HEALTH_STATUS"
    echo "Warnings: $WARNING_COUNT"
    echo "Errors: $ERROR_COUNT"
    echo "Critical Issues: $CRITICAL_COUNT"
    echo
    
    case $HEALTH_STATUS in
        HEALTHY)
            echo "✅ System is healthy and fully operational"
            echo "🟢 All checks passed successfully"
            ;;
        WARNING)
            echo "⚠️  System has minor issues that should be monitored"
            echo "🟡 $WARNING_COUNT warning(s) found"
            ;;
        ERROR)
            echo "❌ System has issues that need attention"
            echo "🔴 $ERROR_COUNT error(s) and $WARNING_COUNT warning(s) found"
            ;;
        CRITICAL)
            echo "🚨 System has critical issues requiring immediate attention"
            echo "🔴 $CRITICAL_COUNT critical issue(s), $ERROR_COUNT error(s), and $WARNING_COUNT warning(s) found"
            ;;
    esac
    
    echo
    echo "System Summary:"
    local uptime=$(execute_command "uptime | awk '{print \$3, \$4}' | sed 's/,//'" || echo "unknown")
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}'" || echo "unknown")
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}'" || echo "unknown")
    
    echo "  Uptime: $uptime"
    echo "  Disk Usage: $disk_usage"
    echo "  Memory Usage: $memory_usage"
    echo
    echo "Quick Access URLs:"
    echo "  - Homepage: https://cloudtolocalllm.online"
    echo "  - Web App: https://app.cloudtolocalllm.online"
    echo
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM health check..."
    echo
    
    # Execute health checks
    check_system_resources
    echo
    
    check_docker_containers
    echo
    
    check_network_connectivity
    echo
    
    check_application_endpoints
    echo
    
    check_ssl_certificates
    echo
    
    check_system_services
    echo
    
    check_log_errors
    echo
    
    # Generate final report
    generate_health_report
    
    # Exit with appropriate code
    case $HEALTH_STATUS in
        HEALTHY)
            exit 0
            ;;
        WARNING)
            exit 1
            ;;
        ERROR)
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
        echo "CloudToLocalLLM Health Check Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script performs comprehensive health checks:"
        echo "  - System resource usage (CPU, memory, disk, load)"
        echo "  - Docker container status and resource usage"
        echo "  - Network connectivity and DNS resolution"
        echo "  - Application endpoint accessibility and response times"
        echo "  - SSL certificate validity and expiration"
        echo "  - System service status"
        echo "  - Recent log errors and exceptions"
        echo
        echo "Exit codes:"
        echo "  0 - HEALTHY (all checks passed)"
        echo "  1 - WARNING (minor issues found)"
        echo "  2 - ERROR (issues requiring attention)"
        echo "  3 - CRITICAL (immediate attention required)"
        echo
        echo "Thresholds:"
        echo "  CPU Warning/Critical: $CPU_WARNING_THRESHOLD%/$CPU_CRITICAL_THRESHOLD%"
        echo "  Memory Warning/Critical: $MEMORY_WARNING_THRESHOLD%/$MEMORY_CRITICAL_THRESHOLD%"
        echo "  Disk Warning/Critical: $DISK_WARNING_THRESHOLD%/$DISK_CRITICAL_THRESHOLD%"
        echo "  Response Time Warning/Critical: ${RESPONSE_TIME_WARNING}s/${RESPONSE_TIME_CRITICAL}s"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
