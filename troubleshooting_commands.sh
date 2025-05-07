#!/bin/bash

# Check the systemd service status in detail
systemctl status cloudtolocalllm.service

# Check the journal logs for the service
journalctl -xeu cloudtolocalllm.service

# Check if docker and docker-compose are installed
docker --version
docker-compose --version

# Check if docker is running
systemctl status docker

# Verify the docker-compose files exist
ls -la /opt/cloudtolocalllm/portal/docker-compose.auth.yml
ls -la /opt/cloudtolocalllm/portal/docker-compose.web.yml

# Try running the docker-compose command manually to see the output
cd /opt/cloudtolocalllm/portal
docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml config 