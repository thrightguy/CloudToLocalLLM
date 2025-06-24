#!/bin/bash

# CloudToLocalLLM Backup Verification Script
# Verifies backup integrity, completeness, and restoration capability
# Ensures backups are reliable and can be used for disaster recovery

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/cloudtolocalllm"

# Backup configuration
BACKUP_BASE_DIR="/var/backups/cloudtolocalllm"
TEST_RESTORE_DIR="/tmp/backup_verification"

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

# Verification status tracking
VERIFICATION_STATUS="PASSED"
ISSUES_FOUND=0
BACKUPS_VERIFIED=0

# Update verification status
update_verification_status() {
    local level="$1"
    case $level in
        WARNING)
            if [[ "$VERIFICATION_STATUS" == "PASSED" ]]; then
                VERIFICATION_STATUS="WARNING"
            fi
            ((ISSUES_FOUND++))
            ;;
        FAILED)
            VERIFICATION_STATUS="FAILED"
            ((ISSUES_FOUND++))
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

# List available backups
list_available_backups() {
    log_step 1 "Listing available backups..."
    
    if ! execute_command "test -d $BACKUP_BASE_DIR"; then
        log_error "Backup directory not found: $BACKUP_BASE_DIR"
        update_verification_status "FAILED"
        return 1
    fi
    
    local backup_dirs=$(execute_command "ls -1d $BACKUP_BASE_DIR/20* 2>/dev/null | sort -r" || echo "")
    
    if [[ -z "$backup_dirs" ]]; then
        log_error "No backups found in $BACKUP_BASE_DIR"
        update_verification_status "FAILED"
        return 1
    fi
    
    log_info "Available backups:"
    while IFS= read -r backup_dir; do
        local backup_name=$(basename "$backup_dir")
        local backup_size=$(execute_command "du -sh $backup_dir 2>/dev/null | cut -f1" || echo "unknown")
        local backup_date=$(execute_command "stat -c %y $backup_dir 2>/dev/null | cut -d' ' -f1" || echo "unknown")
        log_info "  $backup_name ($backup_size, created: $backup_date)"
    done <<< "$backup_dirs"
    
    echo "$backup_dirs"
}

# Verify backup integrity
verify_backup_integrity() {
    local backup_dir="$1"
    local backup_name=$(basename "$backup_dir")
    
    log_step 2 "Verifying backup integrity for $backup_name..."
    
    local integrity_passed=true
    
    # Check if backup manifest exists
    if execute_command "test -f $backup_dir/BACKUP_MANIFEST.txt"; then
        log_success "Backup manifest found"
    else
        log_warning "Backup manifest missing"
        update_verification_status "WARNING"
    fi
    
    # Verify tar.gz files
    local tar_files=$(execute_command "find $backup_dir -name '*.tar.gz'" || echo "")
    if [[ -n "$tar_files" ]]; then
        local tar_count=0
        local tar_failed=0
        
        while IFS= read -r tar_file; do
            ((tar_count++))
            local file_name=$(basename "$tar_file")
            
            if execute_command "tar -tzf $tar_file >/dev/null 2>&1"; then
                log_success "✓ $file_name"
            else
                log_error "✗ $file_name (corrupted)"
                ((tar_failed++))
                integrity_passed=false
            fi
        done <<< "$tar_files"
        
        if [[ $tar_failed -eq 0 ]]; then
            log_success "All $tar_count tar.gz files verified successfully"
        else
            log_error "$tar_failed of $tar_count tar.gz files are corrupted"
            update_verification_status "FAILED"
        fi
    else
        log_warning "No tar.gz files found in backup"
        update_verification_status "WARNING"
    fi
    
    # Verify SQL dumps
    local sql_files=$(execute_command "find $backup_dir -name '*.sql.gz'" || echo "")
    if [[ -n "$sql_files" ]]; then
        while IFS= read -r sql_file; do
            local file_name=$(basename "$sql_file")
            
            if execute_command "gunzip -t $sql_file 2>/dev/null"; then
                log_success "✓ $file_name"
            else
                log_error "✗ $file_name (corrupted)"
                integrity_passed=false
            fi
        done <<< "$sql_files"
    fi
    
    if $integrity_passed; then
        log_success "Backup integrity verification passed for $backup_name"
        return 0
    else
        log_error "Backup integrity verification failed for $backup_name"
        update_verification_status "FAILED"
        return 1
    fi
}

# Check backup completeness
check_backup_completeness() {
    local backup_dir="$1"
    local backup_name=$(basename "$backup_dir")
    
    log_step 3 "Checking backup completeness for $backup_name..."
    
    local completeness_passed=true
    
    # Check required backup components
    local required_components=(
        "application"
        "configuration"
        "logs"
    )
    
    for component in "${required_components[@]}"; do
        if execute_command "test -d $backup_dir/$component"; then
            local component_files=$(execute_command "find $backup_dir/$component -type f | wc -l" || echo "0")
            if [[ "$component_files" -gt 0 ]]; then
                log_success "✓ $component ($component_files files)"
            else
                log_warning "✗ $component (empty directory)"
                update_verification_status "WARNING"
            fi
        else
            log_error "✗ $component (missing)"
            completeness_passed=false
        fi
    done
    
    # Check for critical application files
    local critical_files=(
        "application/cloudtolocalllm_app.tar.gz"
        "configuration/docker-compose.yml"
    )
    
    for file in "${critical_files[@]}"; do
        if execute_command "test -f $backup_dir/$file"; then
            log_success "✓ $(basename $file)"
        else
            log_warning "✗ $(basename $file) (missing)"
            update_verification_status "WARNING"
        fi
    done
    
    # Check backup size
    local backup_size=$(execute_command "du -sb $backup_dir | cut -f1" || echo "0")
    if [[ "$backup_size" -gt 10485760 ]]; then  # > 10MB
        local backup_size_human=$(execute_command "du -sh $backup_dir | cut -f1")
        log_success "Backup size is reasonable: $backup_size_human"
    else
        log_warning "Backup size seems small: $(execute_command "du -sh $backup_dir | cut -f1")"
        update_verification_status "WARNING"
    fi
    
    if $completeness_passed; then
        log_success "Backup completeness check passed for $backup_name"
        return 0
    else
        log_error "Backup completeness check failed for $backup_name"
        update_verification_status "FAILED"
        return 1
    fi
}

# Test backup restoration
test_backup_restoration() {
    local backup_dir="$1"
    local backup_name=$(basename "$backup_dir")
    
    log_step 4 "Testing backup restoration for $backup_name..."
    
    # Create test restoration directory
    execute_command "rm -rf $TEST_RESTORE_DIR && mkdir -p $TEST_RESTORE_DIR"
    
    local restoration_passed=true
    
    # Test application backup restoration
    if execute_command "test -f $backup_dir/application/cloudtolocalllm_app.tar.gz"; then
        log_info "Testing application backup restoration..."
        
        if execute_command "cd $TEST_RESTORE_DIR && tar -xzf $backup_dir/application/cloudtolocalllm_app.tar.gz >/dev/null 2>&1"; then
            # Check if key files were restored
            if execute_command "test -f $TEST_RESTORE_DIR/docker-compose.yml"; then
                log_success "✓ Application backup restoration test passed"
            else
                log_error "✗ Application backup restoration test failed (missing key files)"
                restoration_passed=false
            fi
        else
            log_error "✗ Application backup restoration test failed (extraction error)"
            restoration_passed=false
        fi
    else
        log_warning "Application backup not found, skipping restoration test"
    fi
    
    # Test configuration backup restoration
    if execute_command "test -f $backup_dir/configuration/nginx_config.tar.gz"; then
        log_info "Testing configuration backup restoration..."
        
        if execute_command "cd $TEST_RESTORE_DIR && tar -xzf $backup_dir/configuration/nginx_config.tar.gz >/dev/null 2>&1"; then
            log_success "✓ Configuration backup restoration test passed"
        else
            log_error "✗ Configuration backup restoration test failed"
            restoration_passed=false
        fi
    fi
    
    # Test database backup restoration (if exists)
    local db_backup=$(execute_command "find $backup_dir/database -name '*.sql.gz' | head -1" || echo "")
    if [[ -n "$db_backup" ]]; then
        log_info "Testing database backup restoration..."
        
        if execute_command "gunzip -c $db_backup > $TEST_RESTORE_DIR/test_db.sql 2>/dev/null"; then
            local sql_size=$(execute_command "wc -l < $TEST_RESTORE_DIR/test_db.sql" || echo "0")
            if [[ "$sql_size" -gt 10 ]]; then
                log_success "✓ Database backup restoration test passed ($sql_size lines)"
            else
                log_warning "✗ Database backup seems empty or corrupted"
                update_verification_status "WARNING"
            fi
        else
            log_error "✗ Database backup restoration test failed"
            restoration_passed=false
        fi
    fi
    
    # Cleanup test directory
    execute_command "rm -rf $TEST_RESTORE_DIR"
    
    if $restoration_passed; then
        log_success "Backup restoration test passed for $backup_name"
        return 0
    else
        log_error "Backup restoration test failed for $backup_name"
        update_verification_status "FAILED"
        return 1
    fi
}

# Check backup age and retention
check_backup_age() {
    local backup_dirs="$1"
    
    log_step 5 "Checking backup age and retention..."
    
    local backup_count=$(echo "$backup_dirs" | wc -l)
    log_info "Total backups found: $backup_count"
    
    # Check latest backup age
    local latest_backup=$(echo "$backup_dirs" | head -1)
    local latest_backup_name=$(basename "$latest_backup")
    local backup_age_days=$(execute_command "find $latest_backup -maxdepth 0 -mtime +1 | wc -l" || echo "0")
    
    if [[ "$backup_age_days" -eq 0 ]]; then
        log_success "Latest backup is recent (less than 1 day old)"
    else
        local actual_age=$(execute_command "stat -c %Y $latest_backup" || echo "0")
        local current_time=$(date +%s)
        local age_days=$(( (current_time - actual_age) / 86400 ))
        
        if [[ "$age_days" -gt 7 ]]; then
            log_error "Latest backup is too old ($age_days days)"
            update_verification_status "FAILED"
        elif [[ "$age_days" -gt 3 ]]; then
            log_warning "Latest backup is getting old ($age_days days)"
            update_verification_status "WARNING"
        else
            log_success "Latest backup age is acceptable ($age_days days)"
        fi
    fi
    
    # Check backup retention
    if [[ "$backup_count" -lt 3 ]]; then
        log_warning "Few backups available ($backup_count), consider increasing backup frequency"
        update_verification_status "WARNING"
    elif [[ "$backup_count" -gt 30 ]]; then
        log_warning "Many backups found ($backup_count), consider cleanup"
        update_verification_status "WARNING"
    else
        log_success "Backup retention is reasonable ($backup_count backups)"
    fi
}

# Generate verification report
generate_verification_report() {
    echo
    echo "=== CloudToLocalLLM Backup Verification Report ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Overall Status: $VERIFICATION_STATUS"
    echo "Backups Verified: $BACKUPS_VERIFIED"
    echo "Issues Found: $ISSUES_FOUND"
    echo
    
    case $VERIFICATION_STATUS in
        PASSED)
            echo "✅ All backup verifications passed"
            echo "💾 Backups are reliable and ready for disaster recovery"
            echo "🔒 Backup integrity verified"
            echo "📋 Backup completeness confirmed"
            echo "🔄 Restoration capability tested"
            ;;
        WARNING)
            echo "⚠️  Backup verification completed with warnings"
            echo "📋 $ISSUES_FOUND issue(s) found that should be addressed"
            echo "💾 Backups are mostly reliable but need attention"
            ;;
        FAILED)
            echo "❌ Backup verification failed"
            echo "🚨 $ISSUES_FOUND critical issue(s) found"
            echo "💾 Backups may not be reliable for disaster recovery"
            echo "🔧 Immediate attention required"
            ;;
    esac
    
    echo
    echo "Backup Summary:"
    if execute_command "test -d $BACKUP_BASE_DIR"; then
        local total_backups=$(execute_command "ls -1d $BACKUP_BASE_DIR/20* 2>/dev/null | wc -l" || echo "0")
        local total_size=$(execute_command "du -sh $BACKUP_BASE_DIR 2>/dev/null | cut -f1" || echo "unknown")
        local latest_backup=$(execute_command "ls -1d $BACKUP_BASE_DIR/20* 2>/dev/null | sort -r | head -1" || echo "none")
        
        echo "  Total Backups: $total_backups"
        echo "  Total Size: $total_size"
        echo "  Latest Backup: $(basename "$latest_backup")"
        echo "  Backup Location: $BACKUP_BASE_DIR"
    fi
    echo
    
    if [[ "$VERIFICATION_STATUS" != "PASSED" ]]; then
        echo "Recommended Actions:"
        echo "  - Review backup creation process"
        echo "  - Check backup storage integrity"
        echo "  - Verify backup automation is working"
        echo "  - Consider creating new backup if issues persist"
        echo
    fi
}

# Main execution function
main() {
    log_info "Starting CloudToLocalLLM backup verification..."
    echo
    
    # List available backups
    local backup_dirs=$(list_available_backups)
    if [[ -z "$backup_dirs" ]]; then
        generate_verification_report
        exit 1
    fi
    echo
    
    # Check backup age and retention
    check_backup_age "$backup_dirs"
    echo
    
    # Verify the most recent backup
    local latest_backup=$(echo "$backup_dirs" | head -1)
    local backup_name=$(basename "$latest_backup")
    
    log_info "Verifying latest backup: $backup_name"
    echo
    
    # Run verification tests
    verify_backup_integrity "$latest_backup"
    echo
    
    check_backup_completeness "$latest_backup"
    echo
    
    test_backup_restoration "$latest_backup"
    echo
    
    ((BACKUPS_VERIFIED++))
    
    # Generate final report
    generate_verification_report
    
    # Exit with appropriate code
    case $VERIFICATION_STATUS in
        PASSED)
            log_success "Backup verification completed successfully!"
            exit 0
            ;;
        WARNING)
            log_warning "Backup verification completed with warnings"
            exit 1
            ;;
        FAILED)
            log_error "Backup verification failed"
            exit 2
            ;;
    esac
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Backup Verification Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script verifies backup reliability by checking:"
        echo "  - Backup availability and listing"
        echo "  - Archive integrity (tar.gz and SQL files)"
        echo "  - Backup completeness (required components)"
        echo "  - Restoration capability (test extraction)"
        echo "  - Backup age and retention policy"
        echo
        echo "Exit codes:"
        echo "  0 - PASSED (all verifications successful)"
        echo "  1 - WARNING (minor issues found)"
        echo "  2 - FAILED (critical issues found)"
        echo
        echo "Backup location: $BACKUP_BASE_DIR"
        echo "Test restore location: $TEST_RESTORE_DIR"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
