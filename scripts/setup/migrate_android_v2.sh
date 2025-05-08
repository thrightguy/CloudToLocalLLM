#!/bin/bash

# Comprehensive script to migrate Android embedding to V2
# This is required for compatibility with device_info_plus and other plugins

set -e  # Exit on error

MANIFEST_FILE="android/app/src/main/AndroidManifest.xml"
ACTIVITY_FILE="android/app/src/main/kotlin/com/example/CloudToLocalLLM/MainActivity.kt"

echo "[STATUS] Starting comprehensive Android V2 embedding migration..."

# 1. Update AndroidManifest.xml
if grep -q 'android:name="io.flutter.embedding.android.NormalTheme"' $MANIFEST_FILE; then
  echo "[STATUS] NormalTheme already set in AndroidManifest.xml"
else
  echo "[STATUS] Adding NormalTheme to AndroidManifest.xml"
  sed -i 's/<application/<application\n        android:name="io.flutter.app.FlutterApplication"/g' $MANIFEST_FILE
fi

# Ensure flutterEmbedding meta-data is set to 2
if grep -q 'flutterEmbedding.*2' $MANIFEST_FILE; then
  echo "[STATUS] Flutter embedding V2 already present in manifest"
else
  echo "[STATUS] Adding Flutter embedding V2 to AndroidManifest.xml"
  sed -i '/<\/activity>/i\                <meta-data android:name="flutterEmbedding" android:value="2" \/>' $MANIFEST_FILE
fi

# 2. Update MainActivity.kt to ensure it extends FlutterActivity
if [ -f "$ACTIVITY_FILE" ]; then
  echo "[STATUS] Checking MainActivity.kt..."
  
  # Check if file already uses FlutterActivity
  if grep -q "import io.flutter.embedding.android.FlutterActivity" $ACTIVITY_FILE; then
    echo "[STATUS] MainActivity.kt already imports FlutterActivity"
  else
    echo "[STATUS] Updating MainActivity.kt to use FlutterActivity"
    
    # Create backup
    cp $ACTIVITY_FILE ${ACTIVITY_FILE}.bak
    
    # Update the file with proper V2 embedding
    cat > $ACTIVITY_FILE << 'EOF'
package com.example.CloudToLocalLLM

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    // V2 embedding doesn't require overriding configureFlutterEngine
}
EOF
  fi
else
  echo "[WARNING] MainActivity.kt not found at expected location: $ACTIVITY_FILE"
  echo "[STATUS] Looking for MainActivity in other locations..."
  
  # Try to find the MainActivity file
  FOUND_ACTIVITY=$(find android/app/src/main -name "MainActivity.kt")
  
  if [ -n "$FOUND_ACTIVITY" ]; then
    echo "[STATUS] Found MainActivity at: $FOUND_ACTIVITY"
    ACTIVITY_FILE=$FOUND_ACTIVITY
    
    # Update the found file
    cp $ACTIVITY_FILE ${ACTIVITY_FILE}.bak
    
    # Update the file with proper V2 embedding
    cat > $ACTIVITY_FILE << 'EOF'
package $(dirname $ACTIVITY_FILE | sed 's/\//./' | sed 's/.*kotlin.//')

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    // V2 embedding doesn't require overriding configureFlutterEngine
}
EOF
  else
    echo "[ERROR] Could not find MainActivity.kt file"
    exit 1
  fi
fi

# 3. Check build.gradle to ensure it uses the correct Android SDK version
GRADLE_FILE="android/app/build.gradle"
echo "[STATUS] Checking build.gradle for proper configuration..."

# Ensure compileSdkVersion is at least 31 (Android 12)
if grep -q "compileSdkVersion 31" $GRADLE_FILE || grep -q "compileSdkVersion 32" $GRADLE_FILE || grep -q "compileSdkVersion 33" $GRADLE_FILE || grep -q "compileSdkVersion 34" $GRADLE_FILE; then
  echo "[STATUS] compileSdkVersion is already set to a compatible version"
else
  echo "[STATUS] Updating compileSdkVersion to 31"
  sed -i 's/compileSdkVersion.*/compileSdkVersion 31/g' $GRADLE_FILE
fi

# Ensure minSdkVersion is at least 16
CURRENT_MIN_SDK=$(grep -o "minSdkVersion [0-9]*" $GRADLE_FILE | awk '{print $2}')
if [ -n "$CURRENT_MIN_SDK" ] && [ "$CURRENT_MIN_SDK" -lt 16 ]; then
  echo "[STATUS] Updating minSdkVersion to 16"
  sed -i 's/minSdkVersion.*/minSdkVersion 16/g' $GRADLE_FILE
fi

echo "[STATUS] Android V2 embedding migration completed"
echo "[STATUS] You may need to run 'flutter clean' before rebuilding" 