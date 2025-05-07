#!/bin/bash

# Update system and install Docker
sudo apt update
sudo apt install -y docker.io docker-compose

# Add user to docker group
sudo usermod -aG docker cloudllm

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Clone repository
cd /home/cloudllm
git clone https://github.com/thrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM

# Start containers
docker compose up -d

# Show container status
docker compose ps 