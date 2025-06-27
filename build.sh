#!/bin/bash
set -e

# Build the Docker image
docker build -t cloudtolocalllm-build -f Dockerfile.build .

# Run the build and package script in the Docker container
docker run --rm -v "$(pwd)/dist:/home/builder/dist" cloudtolocalllm-build
