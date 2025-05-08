#!/bin/bash

# Fix Android embedding issues in Docker build context
# This script is meant to be run in the Docker container during build

set -e  # Exit on error

echo "[DOCKER] Fixing Android embedding for Docker build..."

# Create directory structure if it doesn't exist
mkdir -p /app/android/app/src/main/kotlin/com/example/CloudToLocalLLM
mkdir -p /app/android/app/src/main/java/com/example/CloudToLocalLLM

# If AndroidManifest.xml exists, update it
if [ -f "/app/android/app/src/main/AndroidManifest.xml" ]; then
  echo "[DOCKER] Updating AndroidManifest.xml"
  
  # Add FlutterApplication if needed
  if ! grep -q 'android:name="io.flutter.app.FlutterApplication"' /app/android/app/src/main/AndroidManifest.xml; then
    sed -i 's/<application/<application android:name="io.flutter.app.FlutterApplication"/g' /app/android/app/src/main/AndroidManifest.xml
  fi
  
  # Add Flutter embedding metadata if needed
  if ! grep -q 'flutterEmbedding.*2' /app/android/app/src/main/AndroidManifest.xml; then
    sed -i '/<\/activity>/i \        <meta-data android:name="flutterEmbedding" android:value="2" \/>' /app/android/app/src/main/AndroidManifest.xml
  fi
fi

# Create or update MainActivity.kt
echo "[DOCKER] Creating MainActivity.kt with V2 embedding"
cat > /app/android/app/src/main/kotlin/com/example/CloudToLocalLLM/MainActivity.kt << 'EOF'
package com.example.CloudToLocalLLM

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
EOF

# Also create MainActivity.java as fallback
echo "[DOCKER] Creating MainActivity.java as fallback"
cat > /app/android/app/src/main/java/com/example/CloudToLocalLLM/MainActivity.java << 'EOF'
package com.example.CloudToLocalLLM;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
}
EOF

# Update build.gradle if it exists
if [ -f "/app/android/app/build.gradle" ]; then
  echo "[DOCKER] Updating build.gradle"
  
  # Set compileSdkVersion to at least 31
  sed -i 's/compileSdkVersion.*/compileSdkVersion 31/g' /app/android/app/build.gradle
  
  # Ensure minSdkVersion is at least 16
  if grep -q "minSdkVersion" /app/android/app/build.gradle; then
    CURRENT_MIN_SDK=$(grep -o "minSdkVersion [0-9]*" /app/android/app/build.gradle | awk '{print $2}')
    if [ -n "$CURRENT_MIN_SDK" ] && [ "$CURRENT_MIN_SDK" -lt 16 ]; then
      sed -i 's/minSdkVersion.*/minSdkVersion 16/g' /app/android/app/build.gradle
    fi
  else
    # If minSdkVersion is not defined, add it
    sed -i '/android {/a \    defaultConfig {\n        minSdkVersion 16\n    }' /app/android/app/build.gradle
  fi
fi

echo "[DOCKER] Android embedding V2 setup completed for Docker build" 