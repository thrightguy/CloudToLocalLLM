#!/bin/bash

# CloudToLocalLLM DEB Package Builder
# This script creates a .deb package for Debian/Ubuntu distributions

set -e

echo "🔨 Building CloudToLocalLLM DEB Package..."

# Configuration
APP_NAME="cloudtolocalllm"
VERSION="2.0.0"
ARCH="amd64"
BUILD_DIR="build/linux/x64/release/bundle"
PACKAGE_DIR="packaging/deb"
OUTPUT_DIR="dist"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Clean previous package files
rm -rf "$PACKAGE_DIR/usr/lib/$APP_NAME"
mkdir -p "$PACKAGE_DIR/usr/lib/$APP_NAME"

# Build the Flutter application
echo "📦 Building Flutter application..."
flutter build linux --release

# Copy application files
echo "📋 Copying application files..."
cp -r "$BUILD_DIR"/* "$PACKAGE_DIR/usr/lib/$APP_NAME/"

# Create launcher script
cat > "$PACKAGE_DIR/usr/bin/$APP_NAME" << 'EOF'
#!/bin/bash
cd /usr/lib/cloudtolocalllm
exec ./cloudtolocalllm "$@"
EOF

chmod +x "$PACKAGE_DIR/usr/bin/$APP_NAME"

# Copy icon (create a simple one if it doesn't exist)
if [ ! -f "assets/images/app_icon.png" ]; then
    echo "⚠️  No app icon found, creating placeholder..."
    # Create a simple placeholder icon
    convert -size 64x64 xc:blue -fill white -gravity center -pointsize 20 -annotate +0+0 "CTL" "$PACKAGE_DIR/usr/share/pixmaps/$APP_NAME.png" 2>/dev/null || {
        echo "📝 ImageMagick not available, copying placeholder..."
        cp "assets/images/tray_icon.png" "$PACKAGE_DIR/usr/share/pixmaps/$APP_NAME.png" 2>/dev/null || {
            echo "🔧 Creating minimal icon file..."
            touch "$PACKAGE_DIR/usr/share/pixmaps/$APP_NAME.png"
        }
    }
else
    cp "assets/images/app_icon.png" "$PACKAGE_DIR/usr/share/pixmaps/$APP_NAME.png"
fi

# Set permissions
find "$PACKAGE_DIR" -type f -exec chmod 644 {} \;
find "$PACKAGE_DIR" -type d -exec chmod 755 {} \;
chmod +x "$PACKAGE_DIR/usr/bin/$APP_NAME"
chmod +x "$PACKAGE_DIR/usr/lib/$APP_NAME/$APP_NAME"

# Calculate installed size
INSTALLED_SIZE=$(du -sk "$PACKAGE_DIR" | cut -f1)
echo "Installed-Size: $INSTALLED_SIZE" >> "$PACKAGE_DIR/DEBIAN/control"

# Build the package
echo "🏗️  Building DEB package..."
dpkg-deb --build "$PACKAGE_DIR" "$OUTPUT_DIR/${APP_NAME}_${VERSION}_${ARCH}.deb"

echo "✅ DEB package created: $OUTPUT_DIR/${APP_NAME}_${VERSION}_${ARCH}.deb"
echo ""
echo "📦 Installation instructions:"
echo "   sudo dpkg -i $OUTPUT_DIR/${APP_NAME}_${VERSION}_${ARCH}.deb"
echo "   sudo apt-get install -f  # Fix dependencies if needed"
echo ""
echo "🗑️  Uninstallation:"
echo "   sudo apt-get remove $APP_NAME"
