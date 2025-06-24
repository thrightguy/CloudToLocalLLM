#!/bin/bash

# CloudToLocalLLM Performance Report Generator
# Generates comprehensive performance reports including system metrics,
# application performance, and resource utilization analysis

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/cloudtolocalllm"

# Performance monitoring configuration
REPORT_DIR="/var/log/cloudtolocalllm/performance"
SAMPLE_DURATION=60  # seconds
SAMPLE_INTERVAL=5   # seconds

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

# Collect system information
collect_system_info() {
    log_step 1 "Collecting system information..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== SYSTEM INFORMATION ===
Hostname: \$(hostname)
Kernel: \$(uname -r)
OS: \$(cat /etc/os-release | grep PRETTY_NAME | cut -d'\"' -f2)
Architecture: \$(uname -m)
CPU Model: \$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
CPU Cores: \$(nproc)
Total Memory: \$(free -h | grep Mem | awk '{print \$2}')
Uptime: \$(uptime -p)
Load Average: \$(uptime | awk '{print \$10, \$11, \$12}')

EOF"
    
    log_success "System information collected"
}

# Collect CPU performance metrics
collect_cpu_metrics() {
    log_step 2 "Collecting CPU performance metrics..."
    
    local report_file="$1"
    
    log_info "Sampling CPU usage for $SAMPLE_DURATION seconds..."
    
    execute_command "cat >> $report_file << 'EOF'
=== CPU PERFORMANCE METRICS ===
EOF"
    
    # Collect CPU usage samples
    execute_command "echo 'CPU Usage Samples (every ${SAMPLE_INTERVAL}s for ${SAMPLE_DURATION}s):' >> $report_file"
    
    local samples=$((SAMPLE_DURATION / SAMPLE_INTERVAL))
    for ((i=1; i<=samples; i++)); do
        local cpu_usage=$(execute_command "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1")
        local timestamp=$(date '+%H:%M:%S')
        execute_command "echo '$timestamp: ${cpu_usage}%' >> $report_file"
        
        if [[ $i -lt $samples ]]; then
            sleep $SAMPLE_INTERVAL
        fi
    done
    
    # Calculate average CPU usage
    local avg_cpu=$(execute_command "grep -o '[0-9.]*%' $report_file | tail -$samples | sed 's/%//' | awk '{sum+=\$1} END {printf \"%.1f\", sum/NR}'")
    execute_command "echo 'Average CPU Usage: ${avg_cpu}%' >> $report_file"
    
    # Top CPU consuming processes
    execute_command "cat >> $report_file << 'EOF'

Top CPU Consuming Processes:
\$(ps aux --sort=-%cpu | head -10)

EOF"
    
    log_success "CPU metrics collected (average: ${avg_cpu}%)"
}

# Collect memory performance metrics
collect_memory_metrics() {
    log_step 3 "Collecting memory performance metrics..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== MEMORY PERFORMANCE METRICS ===
Memory Usage Summary:
\$(free -h)

Memory Usage Details:
\$(cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree')

Top Memory Consuming Processes:
\$(ps aux --sort=-%mem | head -10)

EOF"
    
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'")
    log_success "Memory metrics collected (usage: ${memory_usage}%)"
}

# Collect disk performance metrics
collect_disk_metrics() {
    log_step 4 "Collecting disk performance metrics..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== DISK PERFORMANCE METRICS ===
Disk Usage Summary:
\$(df -h)

Disk I/O Statistics:
\$(iostat -x 1 3 2>/dev/null | tail -n +4 || echo 'iostat not available')

Largest Directories:
\$(du -sh /opt/cloudtolocalllm/* 2>/dev/null | sort -hr | head -10)
\$(du -sh /var/log/* 2>/dev/null | sort -hr | head -5)

EOF"
    
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}'")
    log_success "Disk metrics collected (usage: $disk_usage)"
}

# Collect network performance metrics
collect_network_metrics() {
    log_step 5 "Collecting network performance metrics..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== NETWORK PERFORMANCE METRICS ===
Network Interfaces:
\$(ip addr show | grep -E '^[0-9]+:|inet ')

Network Statistics:
\$(cat /proc/net/dev | head -2 && cat /proc/net/dev | grep -E 'eth|ens|enp')

Active Network Connections:
\$(netstat -tuln | head -20)

Connection Count by State:
\$(netstat -an | awk '/^tcp/ {print \$6}' | sort | uniq -c | sort -nr)

EOF"
    
    local connection_count=$(execute_command "netstat -tuln | wc -l")
    log_success "Network metrics collected ($connection_count active connections)"
}

# Collect Docker container metrics
collect_docker_metrics() {
    log_step 6 "Collecting Docker container metrics..."
    
    local report_file="$1"
    
    if execute_command "docker info >/dev/null 2>&1"; then
        execute_command "cat >> $report_file << 'EOF'
=== DOCKER CONTAINER METRICS ===
Docker System Information:
\$(docker system df)

Container Status:
\$(cd $VPS_PROJECT_DIR && docker compose ps 2>/dev/null || echo 'Docker Compose not available')

Container Resource Usage:
\$(docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}' 2>/dev/null || echo 'Docker stats not available')

Container Logs (last 10 lines each):
EOF"
        
        # Get container logs
        local containers=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps -q 2>/dev/null" || echo "")
        if [[ -n "$containers" ]]; then
            for container in $containers; do
                local container_name=$(execute_command "docker inspect --format='{{.Name}}' $container" | sed 's/^\/*//')
                execute_command "echo 'Container: $container_name' >> $report_file"
                execute_command "docker logs --tail 10 $container 2>&1 | head -10 >> $report_file"
                execute_command "echo '' >> $report_file"
            done
        fi
        
        log_success "Docker metrics collected"
    else
        execute_command "echo '=== DOCKER CONTAINER METRICS ===' >> $report_file"
        execute_command "echo 'Docker is not running or not available' >> $report_file"
        execute_command "echo '' >> $report_file"
        log_warning "Docker not available, skipping container metrics"
    fi
}

# Collect application performance metrics
collect_application_metrics() {
    log_step 7 "Collecting application performance metrics..."
    
    local report_file="$1"
    
    execute_command "cat >> $report_file << 'EOF'
=== APPLICATION PERFORMANCE METRICS ===
EOF"
    
    # Test application response times
    local endpoints=(
        "http://cloudtolocalllm.online"
        "http://app.cloudtolocalllm.online"
        "https://cloudtolocalllm.online"
        "https://app.cloudtolocalllm.online"
    )
    
    execute_command "echo 'Endpoint Response Times:' >> $report_file"
    
    for endpoint in "${endpoints[@]}"; do
        local start_time=$(date +%s.%N)
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$endpoint" 2>/dev/null || echo "000")
        local end_time=$(date +%s.%N)
        local response_time=$(echo "$end_time - $start_time" | bc -l | awk '{printf "%.3f", $1}')
        
        execute_command "echo '$endpoint: ${response_time}s (HTTP $http_code)' >> $report_file"
    done
    
    # Application version information
    execute_command "cat >> $report_file << 'EOF'

Application Version:
\$(curl -s http://app.cloudtolocalllm.online/version.json 2>/dev/null | jq . || echo 'Version info not available')

EOF"
    
    log_success "Application metrics collected"
}

# Generate performance summary
generate_performance_summary() {
    log_step 8 "Generating performance summary..."
    
    local report_file="$1"
    
    # Calculate performance scores
    local cpu_usage=$(execute_command "grep 'Average CPU Usage:' $report_file | awk '{print \$4}' | sed 's/%//'")
    local memory_usage=$(execute_command "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'")
    local disk_usage=$(execute_command "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'")
    
    # Performance scoring
    local cpu_score=100
    local memory_score=100
    local disk_score=100
    
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        cpu_score=50
    elif (( $(echo "$cpu_usage > 60" | bc -l) )); then
        cpu_score=75
    fi
    
    if (( $(echo "$memory_usage > 80" | bc -l) )); then
        memory_score=50
    elif (( $(echo "$memory_usage > 60" | bc -l) )); then
        memory_score=75
    fi
    
    if [[ "$disk_usage" -gt 80 ]]; then
        disk_score=50
    elif [[ "$disk_usage" -gt 60 ]]; then
        disk_score=75
    fi
    
    local overall_score=$(( (cpu_score + memory_score + disk_score) / 3 ))
    
    execute_command "cat >> $report_file << 'EOF'
=== PERFORMANCE SUMMARY ===
Report Generated: \$(date -u +%Y-%m-%dT%H:%M:%SZ)
Monitoring Duration: ${SAMPLE_DURATION} seconds
Sample Interval: ${SAMPLE_INTERVAL} seconds

Performance Scores (0-100):
- CPU Performance: $cpu_score/100 (${cpu_usage}% usage)
- Memory Performance: $memory_score/100 (${memory_usage}% usage)
- Disk Performance: $disk_score/100 (${disk_usage}% usage)
- Overall Score: $overall_score/100

Performance Status:
EOF"
    
    if [[ "$overall_score" -ge 90 ]]; then
        execute_command "echo '✅ EXCELLENT - System performance is optimal' >> $report_file"
    elif [[ "$overall_score" -ge 75 ]]; then
        execute_command "echo '✅ GOOD - System performance is acceptable' >> $report_file"
    elif [[ "$overall_score" -ge 60 ]]; then
        execute_command "echo '⚠️  FAIR - System performance needs monitoring' >> $report_file"
    else
        execute_command "echo '❌ POOR - System performance needs immediate attention' >> $report_file"
    fi
    
    execute_command "cat >> $report_file << 'EOF'

Recommendations:
EOF"
    
    # Generate recommendations
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        execute_command "echo '- High CPU usage detected - consider optimizing applications or upgrading hardware' >> $report_file"
    fi
    
    if (( $(echo "$memory_usage > 80" | bc -l) )); then
        execute_command "echo '- High memory usage detected - consider adding more RAM or optimizing memory usage' >> $report_file"
    fi
    
    if [[ "$disk_usage" -gt 80 ]]; then
        execute_command "echo '- High disk usage detected - consider cleaning up files or adding more storage' >> $report_file"
    fi
    
    if [[ "$overall_score" -ge 90 ]]; then
        execute_command "echo '- System is performing well - maintain current configuration' >> $report_file"
    fi
    
    execute_command "echo '' >> $report_file"
    
    log_success "Performance summary generated (overall score: $overall_score/100)"
}

# Main execution function
main() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file="$REPORT_DIR/performance_report_$timestamp.txt"
    
    log_info "Starting CloudToLocalLLM performance report generation..."
    echo
    
    # Create report directory
    execute_command "mkdir -p $REPORT_DIR"
    
    # Initialize report file
    execute_command "echo 'CloudToLocalLLM Performance Report' > $report_file"
    execute_command "echo '======================================' >> $report_file"
    execute_command "echo '' >> $report_file"
    
    # Collect all metrics
    collect_system_info "$report_file"
    echo
    
    collect_cpu_metrics "$report_file"
    echo
    
    collect_memory_metrics "$report_file"
    echo
    
    collect_disk_metrics "$report_file"
    echo
    
    collect_network_metrics "$report_file"
    echo
    
    collect_docker_metrics "$report_file"
    echo
    
    collect_application_metrics "$report_file"
    echo
    
    generate_performance_summary "$report_file"
    echo
    
    # Display report location
    log_success "Performance report generated successfully!"
    log_info "Report location: $report_file"
    
    # Show report summary
    echo
    echo "=== PERFORMANCE REPORT SUMMARY ==="
    execute_command "tail -20 $report_file"
    
    exit 0
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Performance Report Generator"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script generates comprehensive performance reports including:"
        echo "  - System information and specifications"
        echo "  - CPU usage metrics and top processes"
        echo "  - Memory usage and allocation details"
        echo "  - Disk usage and I/O statistics"
        echo "  - Network interface and connection metrics"
        echo "  - Docker container resource usage"
        echo "  - Application endpoint response times"
        echo "  - Performance scoring and recommendations"
        echo
        echo "Configuration:"
        echo "  Sample duration: $SAMPLE_DURATION seconds"
        echo "  Sample interval: $SAMPLE_INTERVAL seconds"
        echo "  Report directory: $REPORT_DIR"
        echo
        echo "Can be run locally (connects to VPS) or directly on VPS"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
