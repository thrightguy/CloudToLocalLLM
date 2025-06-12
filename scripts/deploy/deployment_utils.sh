#!/bin/bash

# CloudToLocalLLM Deployment Utilities Library v3.5.5+
# Provides robust network operations, retry logic, and timeout handling
# for deployment scripts to prevent hanging and connectivity issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_TIMEOUT=30
DEFAULT_MAX_RETRIES=3
DEFAULT_RETRY_DELAY=5
SSH_TIMEOUT=10
GIT_TIMEOUT=60

# Enhanced logging functions with timestamp and context
utils_log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [UTILS]${NC} $1"
}

utils_log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [UTILS] ✅${NC} $1"
}

utils_log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [UTILS] ⚠️${NC} $1"
}

utils_log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [UTILS] ❌${NC} $1"
}

utils_log_verbose() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [UTILS] [VERBOSE]${NC} $1"
    fi
}

# Retry function with exponential backoff
# Usage: retry_with_backoff <max_retries> <command> [args...]
retry_with_backoff() {
    local max_retries=$1
    shift
    local attempt=1
    local delay=$DEFAULT_RETRY_DELAY

    while [[ $attempt -le $max_retries ]]; do
        utils_log_verbose "Attempt $attempt/$max_retries: $*"
        
        if "$@"; then
            utils_log_verbose "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [[ $attempt -eq $max_retries ]]; then
            utils_log_error "Command failed after $max_retries attempts: $*"
            return 1
        fi
        
        utils_log_warning "Attempt $attempt failed, retrying in ${delay}s..."
        sleep $delay
        
        # Exponential backoff with jitter
        delay=$((delay * 2 + RANDOM % 5))
        ((attempt++))
    done
}

# Robust SSH execution with timeout and retry
# Usage: ssh_execute <host> <command> [timeout] [max_retries]
ssh_execute() {
    local host="$1"
    local command="$2"
    local timeout="${3:-$SSH_TIMEOUT}"
    local max_retries="${4:-$DEFAULT_MAX_RETRIES}"
    
    utils_log_verbose "SSH execute: $host -> $command"
    
    local ssh_cmd="ssh -o ConnectTimeout=$timeout -o BatchMode=yes -o StrictHostKeyChecking=no"
    
    retry_with_backoff $max_retries timeout $((timeout + 10)) $ssh_cmd "$host" "$command"
}

# Test SSH connectivity
# Usage: test_ssh_connectivity <host> [timeout] [max_retries]
test_ssh_connectivity() {
    local host="$1"
    local timeout="${2:-$SSH_TIMEOUT}"
    local max_retries="${3:-$DEFAULT_MAX_RETRIES}"
    
    utils_log "Testing SSH connectivity to $host..."
    
    if ssh_execute "$host" "echo 'SSH connectivity test successful'" "$timeout" "$max_retries"; then
        utils_log_success "SSH connectivity to $host verified"
        return 0
    else
        utils_log_error "SSH connectivity to $host failed"
        return 1
    fi
}

# Robust git operations with timeout and retry
# Usage: git_execute <operation> [args...] [timeout] [max_retries]
git_execute() {
    local operation="$1"
    shift
    local timeout="${GIT_TIMEOUT}"
    local max_retries="${DEFAULT_MAX_RETRIES}"
    
    # Extract timeout and max_retries if provided as last arguments
    if [[ "$1" =~ ^[0-9]+$ ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
        timeout="$1"
        max_retries="$2"
        shift 2
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
        timeout="$1"
        shift
    fi
    
    utils_log_verbose "Git execute: $operation $*"
    
    case "$operation" in
        "pull")
            retry_with_backoff $max_retries timeout $timeout git pull "$@"
            ;;
        "push")
            retry_with_backoff $max_retries timeout $timeout git push "$@"
            ;;
        "clone")
            retry_with_backoff $max_retries timeout $timeout git clone "$@"
            ;;
        "fetch")
            retry_with_backoff $max_retries timeout $timeout git fetch "$@"
            ;;
        *)
            # For other git operations, execute directly with timeout
            timeout $timeout git "$operation" "$@"
            ;;
    esac
}

# Check if git repository is clean
# Usage: check_git_clean [force_mode]
check_git_clean() {
    local force_mode="${1:-false}"
    
    utils_log "Checking git repository status..."
    
    if ! git diff --quiet || ! git diff --cached --quiet; then
        if [[ "$force_mode" == "true" ]]; then
            utils_log_warning "Uncommitted changes detected but continuing with force mode"
            return 0
        else
            utils_log_error "Uncommitted changes detected. Commit or stash changes first."
            return 1
        fi
    fi
    
    utils_log_success "Git repository is clean"
    return 0
}

# Robust curl operations with retry
# Usage: curl_with_retry <url> [curl_args...] [max_retries]
curl_with_retry() {
    local url="$1"
    shift
    local max_retries="${DEFAULT_MAX_RETRIES}"
    local curl_args=()
    
    # Parse arguments to extract max_retries if provided
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--max-retries" ]]; then
            max_retries="$2"
            shift 2
        else
            curl_args+=("$1")
            shift
        fi
    done
    
    utils_log_verbose "Curl with retry: $url"
    
    retry_with_backoff $max_retries curl -f -s --connect-timeout $DEFAULT_TIMEOUT "${curl_args[@]}" "$url"
}

# Check network connectivity
# Usage: check_network_connectivity [host]
check_network_connectivity() {
    local host="${1:-8.8.8.8}"
    
    utils_log "Checking network connectivity to $host..."
    
    if ping -c 1 -W 5 "$host" &> /dev/null; then
        utils_log_success "Network connectivity verified"
        return 0
    else
        utils_log_error "Network connectivity failed"
        return 1
    fi
}

# Robust command execution with timeout
# Usage: execute_with_timeout <timeout> <command> [args...]
execute_with_timeout() {
    local timeout_duration="$1"
    shift
    
    utils_log_verbose "Executing with timeout ${timeout_duration}s: $*"
    
    if timeout "$timeout_duration" "$@"; then
        utils_log_verbose "Command completed within timeout"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            utils_log_error "Command timed out after ${timeout_duration}s: $*"
        else
            utils_log_error "Command failed with exit code $exit_code: $*"
        fi
        return $exit_code
    fi
}

# Wait for service to be ready
# Usage: wait_for_service <url> [timeout] [check_interval]
wait_for_service() {
    local url="$1"
    local timeout="${2:-60}"
    local check_interval="${3:-5}"
    local elapsed=0
    
    utils_log "Waiting for service to be ready: $url"
    
    while [[ $elapsed -lt $timeout ]]; do
        if curl -f -s --connect-timeout 5 "$url" &> /dev/null; then
            utils_log_success "Service is ready: $url"
            return 0
        fi
        
        utils_log_verbose "Service not ready, waiting ${check_interval}s... (${elapsed}/${timeout}s elapsed)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    utils_log_error "Service failed to become ready within ${timeout}s: $url"
    return 1
}

# Validate required tools
# Usage: validate_required_tools <tool1> <tool2> ...
validate_required_tools() {
    local missing_tools=()
    
    utils_log "Validating required tools..."
    
    for tool in "$@"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            utils_log_error "Required tool not found: $tool"
        else
            utils_log_verbose "✓ Tool available: $tool"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        utils_log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    utils_log_success "All required tools are available"
    return 0
}

# Create backup with timestamp
# Usage: create_timestamped_backup <source_dir> <backup_base_dir>
create_timestamped_backup() {
    local source_dir="$1"
    local backup_base_dir="$2"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$backup_base_dir/backup-$timestamp"
    
    if [[ ! -d "$source_dir" ]]; then
        utils_log_warning "Source directory does not exist: $source_dir"
        return 0
    fi
    
    utils_log "Creating backup: $source_dir -> $backup_dir"
    
    mkdir -p "$backup_dir"
    if cp -r "$source_dir"/* "$backup_dir/" 2>/dev/null; then
        utils_log_success "Backup created: $backup_dir"
        echo "$backup_dir"
        return 0
    else
        utils_log_error "Failed to create backup"
        return 1
    fi
}

# Cleanup function for temporary files
# Usage: cleanup_temp_files <temp_dir1> <temp_dir2> ...
cleanup_temp_files() {
    for temp_dir in "$@"; do
        if [[ -d "$temp_dir" ]]; then
            utils_log_verbose "Cleaning up temporary directory: $temp_dir"
            rm -rf "$temp_dir"
        fi
    done
}

# Signal handler for graceful shutdown
# Usage: setup_signal_handlers <cleanup_function>
setup_signal_handlers() {
    local cleanup_function="$1"

    # Only set up signal handlers if cleanup function is provided and callable
    if [[ -n "$cleanup_function" ]] && declare -F "$cleanup_function" &> /dev/null; then
        trap "$cleanup_function" EXIT
        trap "$cleanup_function; exit 130" INT
        trap "$cleanup_function; exit 143" TERM
        utils_log_verbose "Signal handlers set up for: $cleanup_function"
    else
        utils_log_warning "Invalid cleanup function provided to setup_signal_handlers: $cleanup_function"
        return 1
    fi
}

# Deployment utilities library loaded successfully
# Call utils_log_success manually if needed: utils_log_success "Deployment utilities library loaded"
