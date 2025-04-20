#!/bin/bash
echo "Setting up cloud container..."

# Install dependencies (curl for connectivity checks)
apt-get update && apt-get install -y curl

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
npm install express

# Start the Node.js server
echo "Starting Node.js server..."
node server.js &

# Wait for the server to start
echo "Waiting for Node.js server to start..."
for i in {1..30}
do
    if curl -s -f http://localhost:3000 >/dev/null; then
        echo "Node.js server is running on port 3000"
        break
    fi
    sleep 1
done

if ! curl -s -f http://localhost:3000 >/dev/null; then
    echo "ERROR: Node.js server failed to start on port 3000"
    exit 1
fi

# Check connectivity to tunnel
echo "Checking connectivity to tunnel..."
if ! curl -s -f http://tunnel:8080/api/llm >/dev/null; then
    echo "ERROR: Cloud cannot reach tunnel on port 8080"
    exit 1
fi
echo "Cloud can reach tunnel"

# Keep the container running
wait
