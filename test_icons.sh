#!/bin/bash

echo "=== CloudToLocalLLM Icon Test Script ==="
echo

# Test 1: Check if custom icons exist in source
echo "1. Checking source icon files..."
ICONS_TO_CHECK=(
    "assets/images/app_icon.png"
    "assets/images/tray_icon.png"
    "assets/images/tray_icon_16.png"
    "assets/images/tray_icon_24.png"
    "web/icons/Icon-192.png"
    "web/icons/Icon-512.png"
    "web/favicon.png"
    "linux/icons/cloudtolocalllm-16.png"
    "linux/icons/cloudtolocalllm-32.png"
    "linux/icons/cloudtolocalllm-48.png"
    "linux/icons/cloudtolocalllm-64.png"
    "linux/icons/cloudtolocalllm-128.png"
)

for icon in "${ICONS_TO_CHECK[@]}"; do
    if [ -f "$icon" ]; then
        echo "  ✓ Found: $icon"
    else
        echo "  ✗ Missing: $icon"
    fi
done

echo

# Test 2: Check if icons are in build bundle
echo "2. Checking build bundle icons..."
BUILD_ICONS=(
    "build/linux/x64/release/bundle/data/flutter_assets/assets/images/app_icon.png"
    "build/linux/x64/release/bundle/data/flutter_assets/assets/images/tray_icon.png"
    "build/linux/x64/release/bundle/data/flutter_assets/assets/images/tray_icon_16.png"
    "build/linux/x64/release/bundle/data/flutter_assets/assets/images/tray_icon_24.png"
)

for icon in "${BUILD_ICONS[@]}"; do
    if [ -f "$icon" ]; then
        echo "  ✓ Found: $icon"
    else
        echo "  ✗ Missing: $icon"
    fi
done

echo

# Test 3: Check desktop entry
echo "3. Checking desktop entry..."
DESKTOP_FILE="aur-package/cloudtolocalllm.desktop"
if [ -f "$DESKTOP_FILE" ]; then
    echo "  ✓ Desktop file exists: $DESKTOP_FILE"
    ICON_LINE=$(grep "^Icon=" "$DESKTOP_FILE")
    echo "  Icon setting: $ICON_LINE"
else
    echo "  ✗ Desktop file missing: $DESKTOP_FILE"
fi

echo
echo "=== Icon Test Complete ==="
