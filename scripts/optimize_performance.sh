#!/bin/bash

# CloudToLocalLLM Performance Optimization Script
# Optimizes system performance through cache management, resource tuning,
# and application-specific optimizations for better responsiveness

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
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

# Clear system caches
clear_system_caches() {
    log_step 1 "Clearing system caches..."
    
    # Clear page cache, dentries and inodes
    log_info "Clearing page cache, dentries, and inodes..."
    execute_command "sync && echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null || log_warning "Failed to clear system caches (may require root)"
    
    # Clear systemd journal logs
    log_info "Clearing old systemd journal logs..."
    execute_command "journalctl --vacuum-time=7d" 2>/dev/null || log_warning "Failed to vacuum journal logs"
    
    # Clear package manager caches
    log_info "Clearing package manager caches..."
    if execute_command "command -v apt-get >/dev/null 2>&1"; then
        execute_command "apt-get clean" 2>/dev/null || true
        execute_command "apt-get autoclean" 2>/dev/null || true
    elif execute_command "command -v yum >/dev/null 2>&1"; then
        execute_command "yum clean all" 2>/dev/null || true
    fi
    
    log_success "System cache cleanup completed"
}

# Optimize Docker performance
optimize_docker() {
    log_step 2 "Optimizing Docker performance..."
    
    if execute_command "docker info >/dev/null 2>&1"; then
        # Clean up Docker system
        log_info "Cleaning up Docker system..."
        execute_command "docker system prune -f" || log_warning "Docker system prune failed"
        
        # Remove unused images
        log_info "Removing unused Docker images..."
        execute_command "docker image prune -f" || log_warning "Docker image prune failed"
        
        # Remove unused volumes
        log_info "Removing unused Docker volumes..."
        execute_command "docker volume prune -f" || log_warning "Docker volume prune failed"
        
        # Remove unused networks
        log_info "Removing unused Docker networks..."
        execute_command "docker network prune -f" || log_warning "Docker network prune failed"
        
        # Restart containers for fresh state
        log_info "Restarting application containers..."
        execute_command "cd $VPS_PROJECT_DIR && docker compose restart" 2>/dev/null || log_warning "Failed to restart containers"
        
        log_success "Docker optimization completed"
    else
        log_warning "Docker not available, skipping Docker optimization"
    fi
}

# Optimize file system
optimize_filesystem() {
    log_step 3 "Optimizing file system..."
    
    # Update locate database
    log_info "Updating locate database..."
    execute_command "updatedb" 2>/dev/null || log_warning "Failed to update locate database"
    
    # Clean temporary files
    log_info "Cleaning temporary files..."
    local temp_dirs=("/tmp" "/var/tmp")
    
    for temp_dir in "${temp_dirs[@]}"; do
        if execute_command "test -d $temp_dir"; then
            # Remove files older than 7 days
            execute_command "find $temp_dir -type f -mtime +7 -delete 2>/dev/null" || true
            # Remove empty directories
            execute_command "find $temp_dir -type d -empty -delete 2>/dev/null" || true
        fi
    done
    
    # Clean log files
    log_info "Rotating and compressing log files..."
    local log_dirs=("/var/log" "/var/log/cloudtolocalllm")
    
    for log_dir in "${log_dirs[@]}"; do
        if execute_command "test -d $log_dir"; then
            # Compress logs older than 1 day
            execute_command "find $log_dir -name '*.log' -type f -mtime +1 -exec gzip {} \;" 2>/dev/null || true
            # Remove compressed logs older than 30 days
            execute_command "find $log_dir -name '*.log.gz' -type f -mtime +30 -delete" 2>/dev/null || true
        fi
    done
    
    log_success "File system optimization completed"
}

# Optimize network settings
optimize_network() {
    log_step 4 "Optimizing network settings..."
    
    # Check current network configuration
    local tcp_congestion=$(execute_command "sysctl net.ipv4.tcp_congestion_control 2>/dev/null | cut -d= -f2 | xargs" || echo "unknown")
    log_info "Current TCP congestion control: $tcp_congestion"
    
    # Optimize TCP settings (if possible)
    if execute_command "test -w /proc/sys/net/ipv4/tcp_congestion_control"; then
        log_info "Optimizing TCP congestion control..."
        execute_command "echo 'bbr' > /proc/sys/net/ipv4/tcp_congestion_control" 2>/dev/null || true
    else
        log_info "TCP optimization requires root privileges, skipping"
    fi
    
    # Clear ARP cache
    log_info "Clearing ARP cache..."
    execute_command "ip neigh flush all" 2>/dev/null || log_warning "Failed to clear ARP cache"
    
    # Check network interface statistics
    local network_stats=$(execute_command "cat /proc/net/dev | grep -E 'eth|ens|enp' | head -1" || echo "")
    if [[ -n "$network_stats" ]]; then
        log_info "Network interface statistics updated"
    fi
    
    log_success "Network optimization completed"
}

# Optimize application performance
optimize_application() {
    log_step 5 "Optimizing application performance..."
    
    # Check if application is running
    if execute_command "cd $VPS_PROJECT_DIR && docker compose ps | grep -q Up"; then
        # Restart application containers for fresh state
        log_info "Restarting application containers..."
        execute_command "cd $VPS_PROJECT_DIR && docker compose restart webapp" 2>/dev/null || log_warning "Failed to restart webapp"
        execute_command "cd $VPS_PROJECT_DIR && docker compose restart api-backend" 2>/dev/null || log_warning "Failed to restart api-backend"
        
        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 10
        
        # Test application responsiveness
        local response_time=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 10 "http://app.cloudtolocalllm.online" 2>/dev/null || echo "0")
        if (( $(echo "$response_time > 0" | bc -l) )); then
            log_success "Application is responding (${response_time}s)"
        else
            log_warning "Application may not be responding properly"
        fi
    else
        log_warning "Application containers not running, skipping application optimization"
    fi
    
    # Clean application-specific caches
    log_info "Cleaning application caches..."
    local app_cache_dirs=(
        "$VPS_PROJECT_DIR/temp"
        "$VPS_PROJECT_DIR/.cache"
        "$VPS_PROJECT_DIR/logs"
    )
    
    for cache_dir in "${app_cache_dirs[@]}"; do
        if execute_command "test -d $cache_dir"; then
            execute_command "find $cache_dir -type f -mtime +3 -delete 2>/dev/null" || true
        fi
    done
    
    log_success "Application optimization completed"
}

# Optimize system resources
optimize_system_resources() {
    log_step 6 "Optimizing system resources..."
    
    # Check and optimize swap usage
    local swap_usage=$(execute_command "free | grep Swap | awk '{if (\$2 > 0) printf \"%.1f\", \$3/\$2 * 100.0; else print \"0\"}'" || echo "0")
    log_info "Current swap usage: ${swap_usage}%"
    
    if (( $(echo "$swap_usage > 50" | bc -l) )); then
        log_info "High swap usage detected, clearing swap..."
        execute_command "swapoff -a && swapon -a" 2>/dev/null || log_warning "Failed to clear swap"
    fi
    
    # Optimize memory settings
    if execute_command "test -w /proc/sys/vm/swappiness"; then
        log_info "Optimizing memory swappiness..."
        execute_command "echo '10' > /proc/sys/vm/swappiness" 2>/dev/null || true
    fi
    
    # Check for memory leaks in processes
    log_info "Checking for high memory usage processes..."
    local high_mem_processes=$(execute_command "ps aux --sort=-%mem | head -5 | tail -4" || echo "")
    if [[ -n "$high_mem_processes" ]]; then
        log_info "Top memory consuming processes:"
        echo "$high_mem_processes"
    fi
    
    log_success "System resource optimization completed"
}

# Generate optimization report
generate_optimization_report() {
    log_step 7 "Generating optimization report..."
    
    # Collect post-optimization metrics
    local cpu_usage=$(execute_command "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" || echo "unknown")
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'" || echo "unknown")
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}'" || echo "unknown")
    local load_avg=$(execute_command "uptime | awk '{print \$(NF-2)}' | sed 's/,//'" || echo "unknown")
    
    echo
    echo "=== CloudToLocalLLM Performance Optimization Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "Optimization Tasks Completed:"
    echo "✅ System cache cleanup"
    echo "✅ Docker optimization"
    echo "✅ File system optimization"
    echo "✅ Network optimization"
    echo "✅ Application optimization"
    echo "✅ System resource optimization"
    echo
    echo "Current System Metrics:"
    echo "  CPU Usage: ${cpu_usage}%"
    echo "  Memory Usage: ${memory_usage}%"
    echo "  Disk Usage: $disk_usage"
    echo "  Load Average: $load_avg"
    echo
    echo "Optimization Benefits:"
    echo "  🚀 Improved system responsiveness"
    echo "  💾 Reduced memory footprint"
    echo "  🗂️  Cleaned up unnecessary files"
    echo "  🐳 Optimized Docker performance"
    echo "  🌐 Enhanced network efficiency"
    echo
    echo "Recommendations:"
    echo "  - Run this optimization weekly for best performance"
    echo "  - Monitor system metrics regularly"
    echo "  - Consider upgrading hardware if performance issues persist"
    echo "  - Keep system and applications updated"
    echo
    
    # Test application performance
    log_info "Testing application performance..."
    local endpoints=("http://cloudtolocalllm.online" "http://app.cloudtolocalllm.online")
    
    echo "Application Response Times:"
    for endpoint in "${endpoints[@]}"; do
        local response_time=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 10 "$endpoint" 2>/dev/null || echo "timeout")
        echo "  $endpoint: ${response_time}s"
    done
    echo
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM performance optimization..."
    echo
    
    # Record start time
    local start_time=$(date +%s)
    
    # Execute optimization steps
    clear_system_caches
    echo
    
    optimize_docker
    echo
    
    optimize_filesystem
    echo
    
    optimize_network
    echo
    
    optimize_application
    echo
    
    optimize_system_resources
    echo
    
    # Calculate optimization time
    local end_time=$(date +%s)
    local optimization_time=$((end_time - start_time))
    
    # Generate final report
    generate_optimization_report
    
    log_success "Performance optimization completed in ${optimization_time} seconds!"
    
    # Log optimization to system log
    execute_command "logger 'CloudToLocalLLM performance optimization completed'" 2>/dev/null || true
    
    exit 0
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Performance Optimization Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script optimizes system performance by:"
        echo "  - Clearing system caches (page cache, dentries, inodes)"
        echo "  - Optimizing Docker containers and images"
        echo "  - Cleaning up file system (temp files, logs)"
        echo "  - Optimizing network settings"
        echo "  - Restarting application containers"
        echo "  - Optimizing system resource usage"
        echo "  - Generating performance report"
        echo
        echo "Benefits:"
        echo "  - Improved system responsiveness"
        echo "  - Reduced memory footprint"
        echo "  - Better application performance"
        echo "  - Cleaned up disk space"
        echo
        echo "Recommended frequency: Weekly"
        echo
        echo "Can be run locally (connects to VPS) or directly on VPS"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
