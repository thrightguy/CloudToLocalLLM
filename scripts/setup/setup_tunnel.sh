#!/bin/bash
echo "Setting up tunnel container..."

# Compile the Dart code
echo "Compiling Dart tunnel executable..."
dart pub get
dart compile exe lib/main.dart -o tunnel
if [ ! -f "tunnel" ]; then
    echo "ERROR: Tunnel executable not created"
    exit 1
fi
echo "Tunnel executable created"

# Start the tunnel server
echo "Starting tunnel server..."
./tunnel &

# Wait for the server to start
echo "Waiting for tunnel server to start..."
for i in {1..30}
do
    if netstat -tuln | grep -q ':8080'; then
        echo "Tunnel server is running on port 8080"
        break
    fi
    sleep 1
done

if ! netstat -tuln | grep -q ':8080'; then
    echo "ERROR: Tunnel server failed to start on port 8080"
    exit 1
fi

# Check connectivity to Ollama
echo "Checking connectivity to Ollama..."
if ! curl -s -f http://ollama:11434 >/dev/null; then
    echo "ERROR: Tunnel cannot reach Ollama on port 11434"
    exit 1
fi
echo "Tunnel can reach Ollama"

# Keep the container running
wait

# Create Dockerfile.tunnel
cat > Dockerfile.tunnel << 'EOL'
# Use Node.js as the base image for the tunnel service
FROM node:20-slim

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application
COPY . .

# Expose the tunnel port
EXPOSE 8080

# Start the tunnel service
CMD ["node", "tunnel.js"]
EOL

# Update docker-compose.yml
sed -i 's/dockerfile: Dockerfile/dockerfile: Dockerfile.tunnel/' docker-compose.yml

# Set proper permissions
chown cloudllm:cloudllm Dockerfile.tunnel
chown cloudllm:cloudllm docker-compose.yml
