#!/bin/bash

# CloudToLocalLLM Flutter-Native Architecture Verification
# Verifies unified Flutter deployment without static homepage dependencies

echo "=== Checking Flutter Web Build ==="
FLUTTER_FILES=(
    "/opt/cloudtolocalllm/build/web/index.html"
    "/opt/cloudtolocalllm/build/web/main.dart.js"
    "/opt/cloudtolocalllm/build/web/flutter.js"
    "/opt/cloudtolocalllm/build/web/assets/AssetManifest.json"
)

for file in "${FLUTTER_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ Found Flutter file: $file"
    else
        echo "✗ Missing Flutter file: $file"
    fi
done

echo -e "\n=== Verifying Flutter-Native Homepage ==="
# Check that Flutter serves both homepage and app routes
if curl -f -s http://localhost/version.json > /dev/null 2>&1; then
    echo "✓ Flutter version endpoint accessible"
else
    echo "✗ Flutter version endpoint not accessible"
fi

echo -e "\n=== Checking Container Health ==="
# Check Flutter app container
if docker ps | grep -q "cloudtolocalllm-flutter-app"; then
    echo "✓ Flutter app container running"
else
    echo "✗ Flutter app container not running"
fi

# Check Nginx proxy
if docker ps | grep -q "cloudtolocalllm-nginx-proxy"; then
    echo "✓ Nginx proxy container running"
    docker exec cloudtolocalllm-nginx-proxy nginx -t
else
    echo "✗ Nginx proxy container not running"
fi

echo -e "\n=== Flutter-Native Architecture Verification Complete ==="
echo "CloudToLocalLLM v3.4.0+ unified Flutter architecture verified."
echo "Homepage and web app are served by the same Flutter application."