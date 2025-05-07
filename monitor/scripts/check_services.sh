#!/bin/bash
set -e

# Configuration
CHECK_INTERVAL=60  # Seconds between checks
LOG_FILE="/app/logs/service_status.json"
SERVICES=(
  "webapp:webapp:80:/health"
  "auth:auth:8080:/health"
  "beta_site:beta.cloudtolocalllm.online:443:/health"
  "main_site:cloudtolocalllm.online:443:/health"
)

# Initialize log directory
mkdir -p /app/logs

# Main loop
while true; do
  echo "Checking services at $(date)"
  
  # Initialize results object
  results="{}"
  
  # Check each service
  for service_config in "${SERVICES[@]}"; do
    # Parse service config
    IFS=':' read -r service_name host port path <<< "$service_config"
    
    echo "Checking $service_name at $host:$port$path"
    
    # Check if service is running (port is open)
    if nc -z -w 2 "$host" "$port" 2>/dev/null; then
      echo "$service_name is running on $host:$port"
      
      # Check health endpoint if it exists
      if [[ -n "$path" && "$path" != "null" ]]; then
        # For HTTPS
        if [[ "$port" -eq 443 ]]; then
          http_status=$(curl -s -k -o /dev/null -w "%{http_code}" "https://$host$path" 2>/dev/null || echo "000")
        else
          # For HTTP
          http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$host:$port$path" 2>/dev/null || echo "000")
        fi
        
        if [[ "$http_status" == "200" ]]; then
          status="true"
          message="Service is healthy (responded with 200 OK)"
        else
          status="false"
          message="Service is running but health check failed with status $http_status"
        fi
      else
        status="true"
        message="Service is running (no health check)"
      fi
    else
      echo "$service_name is NOT running on $host:$port"
      status="false"
      message="Service is not responding on $host:$port"
    fi
    
    # Add to results
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    service_json="{\"status\": $status, \"message\": \"$message\", \"timestamp\": \"$timestamp\"}"
    
    # Update results object
    results=$(echo "$results" | jq --arg service "$service_name" --argjson data "$service_json" '. + {($service): $data}')
  done
  
  # Save results to file
  echo "$results" > "$LOG_FILE"
  
  # Sleep until next check
  echo "Next check in $CHECK_INTERVAL seconds"
  sleep "$CHECK_INTERVAL"
done 