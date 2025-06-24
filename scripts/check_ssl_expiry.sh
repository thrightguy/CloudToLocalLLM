#!/bin/bash

# CloudToLocalLLM SSL Certificate Expiry Checker
# Monitors SSL certificate expiration dates and sends alerts
# Ensures continuous HTTPS availability for the application

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# SSL monitoring configuration
DOMAINS=("cloudtolocalllm.online" "app.cloudtolocalllm.online")
WARNING_DAYS=30
CRITICAL_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# SSL status tracking
SSL_STATUS="HEALTHY"
WARNINGS=0
CRITICAL_ISSUES=0

# Update SSL status
update_ssl_status() {
    local level="$1"
    case $level in
        WARNING)
            ((WARNINGS++))
            if [[ "$SSL_STATUS" == "HEALTHY" ]]; then
                SSL_STATUS="WARNING"
            fi
            ;;
        CRITICAL)
            ((CRITICAL_ISSUES++))
            SSL_STATUS="CRITICAL"
            ;;
    esac
}

# Check SSL certificate for domain
check_ssl_certificate() {
    local domain="$1"
    
    log_info "Checking SSL certificate for $domain..."
    
    # Get certificate information
    local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL_ERROR")
    
    if [[ "$cert_info" == "SSL_ERROR" ]]; then
        log_error "Failed to retrieve SSL certificate for $domain"
        update_ssl_status "CRITICAL"
        return 1
    fi
    
    # Parse certificate dates
    local not_before=$(echo "$cert_info" | grep "notBefore" | cut -d= -f2)
    local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
    
    # Convert to timestamps
    local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
    local current_date=$(date +%s)
    local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
    
    # Check certificate status
    if [[ "$days_until_expiry" -lt 0 ]]; then
        log_critical "$domain SSL certificate has EXPIRED!"
        update_ssl_status "CRITICAL"
        return 1
    elif [[ "$days_until_expiry" -le "$CRITICAL_DAYS" ]]; then
        log_critical "$domain SSL certificate expires in $days_until_expiry days (CRITICAL)"
        update_ssl_status "CRITICAL"
        return 1
    elif [[ "$days_until_expiry" -le "$WARNING_DAYS" ]]; then
        log_warning "$domain SSL certificate expires in $days_until_expiry days"
        update_ssl_status "WARNING"
        return 1
    else
        log_success "$domain SSL certificate is valid (expires in $days_until_expiry days)"
        return 0
    fi
}

# Generate SSL report
generate_ssl_report() {
    echo
    echo "=== CloudToLocalLLM SSL Certificate Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Overall Status: $SSL_STATUS"
    echo "Warnings: $WARNINGS"
    echo "Critical Issues: $CRITICAL_ISSUES"
    echo
    
    case $SSL_STATUS in
        HEALTHY)
            echo "✅ All SSL certificates are healthy"
            ;;
        WARNING)
            echo "⚠️  SSL certificates need attention"
            echo "🟡 $WARNINGS certificate(s) expiring soon"
            ;;
        CRITICAL)
            echo "🚨 SSL certificates require immediate action"
            echo "🔴 $CRITICAL_ISSUES certificate(s) expired or expiring very soon"
            ;;
    esac
    
    echo
    echo "Certificate Details:"
    for domain in "${DOMAINS[@]}"; do
        local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL_ERROR")
        
        if [[ "$cert_info" != "SSL_ERROR" ]]; then
            local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
            local current_date=$(date +%s)
            local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
            
            echo "  $domain: expires in $days_until_expiry days ($not_after)"
        else
            echo "  $domain: certificate check failed"
        fi
    done
    echo
}

# Main execution function
main() {
    log_info "Starting SSL certificate expiry check..."
    echo
    
    # Check each domain
    for domain in "${DOMAINS[@]}"; do
        check_ssl_certificate "$domain"
        echo
    done
    
    # Generate report
    generate_ssl_report
    
    # Exit with appropriate code
    case $SSL_STATUS in
        HEALTHY)
            exit 0
            ;;
        WARNING)
            exit 1
            ;;
        CRITICAL)
            exit 2
            ;;
    esac
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM SSL Certificate Expiry Checker"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script monitors SSL certificate expiration for:"
        for domain in "${DOMAINS[@]}"; do
            echo "  - $domain"
        done
        echo
        echo "Thresholds:"
        echo "  Warning: $WARNING_DAYS days"
        echo "  Critical: $CRITICAL_DAYS days"
        echo
        echo "Exit codes:"
        echo "  0 - HEALTHY (all certificates valid)"
        echo "  1 - WARNING (certificates expiring soon)"
        echo "  2 - CRITICAL (certificates expired or expiring very soon)"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
