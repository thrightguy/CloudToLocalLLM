#!/bin/bash
echo "Checking Ollama container..."

# Check if Ollama server is running
if ! curl -s -f http://localhost:11434 >/dev/null; then
    echo "ERROR: Ollama server not running on port 11434"
    exit 1
fi
echo "Ollama server is running"

# Install tinyllama model
echo "Installing tinyllama model..."
/bin/ollama pull tinyllama

# Verify the model is installed
if ! /bin/ollama list | grep -q 'tinyllama'; then
    echo "ERROR: tinyllama model not found"
    exit 1
fi
echo "tinyllama model installed successfully"
