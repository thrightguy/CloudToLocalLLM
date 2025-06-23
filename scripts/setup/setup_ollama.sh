#!/bin/bash
echo "Setting up Ollama container..."

# Start the Ollama server in the background
/bin/ollama serve &

# Wait for the server to start
echo "Waiting for Ollama server to start..."
for i in {1..60}
do
    if curl -s -f http://localhost:11434 >/dev/null; then
        echo "Ollama server is running"
        break
    fi
    sleep 1
done

if ! curl -s -f http://localhost:11434 >/dev/null; then
    echo "ERROR: Ollama server failed to start"
    exit 1
fi

# Install tinyllama model
echo "Installing tinyllama model..."
/bin/ollama pull tinyllama

# Verify the model is installed
if ! /bin/ollama list | grep -q 'tinyllama'; then
    echo "ERROR: tinyllama model not found"
    exit 1
fi
echo "tinyllama model installed successfully"

# Keep the container running
wait
