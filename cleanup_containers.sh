#!/bin/bash

echo "Stopping all running containers..."
docker stop $(docker ps -q)

echo "Removing all containers..."
docker rm $(docker ps -a -q)

echo "Cleaning up unused networks..."
docker network prune -f

echo "Cleaning up unused volumes..."
docker volume prune -f

echo "Removing dangling images..."
docker image prune -f

echo "Cleaning Docker build cache..."
docker builder prune -f

echo "Cleanup completed successfully!" 