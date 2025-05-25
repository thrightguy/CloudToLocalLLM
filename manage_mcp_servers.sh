#!/bin/bash

# Configuration
CONFIG_FILE="config/mcp_servers.json"
PID_DIR=".mcp_pids"

# Create PID directory if it doesn't exist
mkdir -p "$PID_DIR"

# Function to start a server
start_server() {
    local server_name=$1
    local pid_file="$PID_DIR/${server_name}.pid"
    
    # Check if server is already running
    if [ -f "$pid_file" ] && kill -0 $(cat "$pid_file") 2>/dev/null; then
        echo "Server $server_name is already running (PID: $(cat "$pid_file"))"
        return
    fi
    
    # Get server configuration
    local command=$(jq -r ".mcpServers.$server_name.command" "$CONFIG_FILE")
    local args=$(jq -r ".mcpServers.$server_name.args[]" "$CONFIG_FILE" | tr '\n' ' ')
    local env_vars=$(jq -r ".mcpServers.$server_name.env | to_entries | map(\"\(.key)=\(.value)\") | .[]" "$CONFIG_FILE" 2>/dev/null)
    
    # Start server
    if [ -n "$env_vars" ]; then
        $env_vars $command $args > "logs/${server_name}.log" 2>&1 &
    else
        $command $args > "logs/${server_name}.log" 2>&1 &
    fi
    
    # Save PID
    echo $! > "$pid_file"
    echo "Started $server_name (PID: $!)"
}

# Function to stop a server
stop_server() {
    local server_name=$1
    local pid_file="$PID_DIR/${server_name}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            echo "Stopped $server_name (PID: $pid)"
        else
            echo "Server $server_name is not running (stale PID file)"
        fi
        rm "$pid_file"
    else
        echo "No PID file found for $server_name"
    fi
}

# Function to check server status
check_status() {
    local server_name=$1
    local pid_file="$PID_DIR/${server_name}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            echo "$server_name: Running (PID: $pid)"
        else
            echo "$server_name: Not running (stale PID file)"
        fi
    else
        echo "$server_name: Not running"
    fi
}

# Main script logic
case "$1" in
    "start")
        # Create logs directory if it doesn't exist
        mkdir -p logs
        
        # Start all servers
        for server in $(jq -r '.mcpServers | keys[]' "$CONFIG_FILE"); do
            start_server "$server"
        done
        ;;
    "stop")
        # Stop all servers
        for server in $(jq -r '.mcpServers | keys[]' "$CONFIG_FILE"); do
            stop_server "$server"
        done
        ;;
    "restart")
        $0 stop
        sleep 2
        $0 start
        ;;
    "status")
        # Check status of all servers
        for server in $(jq -r '.mcpServers | keys[]' "$CONFIG_FILE"); do
            check_status "$server"
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0 