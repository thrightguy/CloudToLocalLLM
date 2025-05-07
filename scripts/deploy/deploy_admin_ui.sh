#!/bin/bash
set -e

# Prerequisite checks
for cmd in git node npm docker; do
  if ! command -v $cmd &> /dev/null; then
    echo "$cmd not found. Installing..."
    if [[ "$cmd" == "git" ]]; then
      apt-get update && apt-get install -y git
    elif [[ "$cmd" == "node" || "$cmd" == "npm" ]]; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt-get install -y nodejs
    elif [[ "$cmd" == "docker" ]]; then
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh
      rm get-docker.sh
    fi
  fi
  echo "$cmd is installed."
done

# Go to deployment directory
cd /opt/cloudtolocalllm/portal

echo "Pulling latest code from GitHub..."
git pull origin master

echo "Building admin-ui..."
cd admin-ui
npm install
npm run build

cd ..
echo "Restarting Docker containers..."
docker-compose -f docker-compose.web.yml up -d --build

echo "Deployment complete." 