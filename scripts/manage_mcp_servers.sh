#!/bin/bash

# Configuration
CONFIG_FILE="../config/mcp_servers.json"
PID_DIR="../.mcp_pids"
LOG_DIR="../.mcp_logs"

# Create necessary directories
mkdir -p "$PID_DIR"
mkdir -p "$LOG_DIR"

# Function to get server names from config
get_server_names() {
    jq -r '.mcpServers | keys[]' "$CONFIG_FILE"
}

# Function to start a server
start_server() {
    local server_name=$1
    local server_config=$(jq -r ".mcpServers.$server_name" "$CONFIG_FILE")
    
    # Extract command and arguments
    local cmd=$(echo "$server_config" | jq -r '.command')
    local args=$(echo "$server_config" | jq -r '.args[]' | tr '\n' ' ')
    
    # Create environment variables
    local env_vars=""
    while IFS="=" read -r key value; do
        env_vars="$env_vars $key=$value"
    done < <(echo "$server_config" | jq -r '.env | to_entries | .[] | "\(.key)=\(.value)"')
    
    # Start the server
    echo "Starting $server_name..."
    cd "$(dirname "$0")" || exit 1
    eval "$env_vars $cmd $args" > "$LOG_DIR/${server_name}.log" 2>&1 &
    echo $! > "$PID_DIR/${server_name}.pid"
    echo "$server_name started with PID $(cat "$PID_DIR/${server_name}.pid")"
}

# Function to stop a server
stop_server() {
    local server_name=$1
    local pid_file="$PID_DIR/${server_name}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        echo "Stopping $server_name (PID: $pid)..."
        kill "$pid" 2>/dev/null
        rm "$pid_file"
        echo "$server_name stopped"
    else
        echo "$server_name is not running"
    fi
}

# Function to check server status
check_status() {
    local server_name=$1
    local pid_file="$PID_DIR/${server_name}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null; then
            echo "$server_name is running (PID: $pid)"
        else
            echo "$server_name is not running (stale PID file)"
            rm "$pid_file"
        fi
    else
        echo "$server_name is not running"
    fi
}

# Main script logic
case "$1" in
    "start")
        if [ -z "$2" ]; then
            # Start all servers
            while read -r server_name; do
                start_server "$server_name"
            done < <(get_server_names)
        else
            # Start specific server
            start_server "$2"
        fi
        ;;
    "stop")
        if [ -z "$2" ]; then
            # Stop all servers
            while read -r server_name; do
                stop_server "$server_name"
            done < <(get_server_names)
        else
            # Stop specific server
            stop_server "$2"
        fi
        ;;
    "status")
        if [ -z "$2" ]; then
            # Check status of all servers
            while read -r server_name; do
                check_status "$server_name"
            done < <(get_server_names)
        else
            # Check status of specific server
            check_status "$2"
        fi
        ;;
    "restart")
        if [ -z "$2" ]; then
            # Restart all servers
            while read -r server_name; do
                stop_server "$server_name"
                start_server "$server_name"
            done < <(get_server_names)
        else
            # Restart specific server
            stop_server "$2"
            start_server "$2"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart} [server_name]"
        echo "If server_name is not provided, the action will be applied to all servers"
        exit 1
        ;;
esac 