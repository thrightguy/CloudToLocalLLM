#!/bin/bash

# Fix Flutter Docker build issues related to running as root
# This script modifies Dockerfile configurations to suppress root user warnings

set -e  # Exit on error

echo "[STATUS] Fixing Flutter Docker build configurations..."

# Find all Dockerfiles in the project
DOCKERFILES=$(find . -name "Dockerfile*" -type f)

for dockerfile in $DOCKERFILES; do
  echo "[STATUS] Processing $dockerfile"
  
  # Backup the original file
  cp "$dockerfile" "${dockerfile}.bak"
  
  # Check if the file contains flutter commands
  if grep -q "flutter " "$dockerfile"; then
    echo "[STATUS] $dockerfile contains Flutter commands, adding environment variables"
    
    # Add environment variables to suppress Flutter warnings about running as root
    # Insert after the FROM line for the Flutter image
    sed -i '/FROM.*flutter/a ENV FLUTTER_ROOT=/flutter \
ENV PUB_CACHE=/flutter/.pub-cache \
ENV FLUTTER_SUPPRESS_ANALYTICS=true \
ENV NO_COLOR=true \
ENV FLUTTER_NO_ROOT_WARNING=true' "$dockerfile"
    
    echo "[STATUS] Updated $dockerfile"
  else
    echo "[STATUS] $dockerfile does not contain Flutter commands, skipping"
  fi
done

# Check Docker Compose files too
COMPOSE_FILES=$(find . -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -type f)

for composefile in $COMPOSE_FILES; do
  echo "[STATUS] Processing $composefile"
  
  # Backup the original file
  cp "$composefile" "${composefile}.bak"
  
  # Check if the file contains flutter services or commands
  if grep -q "flutter" "$composefile"; then
    echo "[STATUS] $composefile contains Flutter references, adding environment variables"
    
    # This is a bit trickier for YAML files, using a different approach
    # Adding a note to manually check the file
    echo "[NOTICE] $composefile may need manual modification to add FLUTTER_NO_ROOT_WARNING=true"
    echo "# FLUTTER_NO_ROOT_WARNING=true should be added to environment" >> "$composefile"
  else
    echo "[STATUS] $composefile does not contain Flutter references, skipping"
  fi
done

echo "[STATUS] Checking specific Flutter web build configurations..."

# Specifically check webapp Dockerfile which is likely used for web builds
if [ -f "./Dockerfile.web" ]; then
  echo "[STATUS] Found Dockerfile.web, updating Flutter web build command"
  cp "./Dockerfile.web" "./Dockerfile.web.bak"
  
  # Update the Flutter build web command to include --no-tree-shake-icons which can help with build issues
  sed -i 's/flutter build web --release/flutter build web --release --no-tree-shake-icons/g' "./Dockerfile.web"
fi

echo "[STATUS] Docker build configurations updated"
echo "[STATUS] You may need to rebuild your Docker images" 