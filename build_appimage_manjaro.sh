#!/bin/bash

# CloudToLocalLLM AppImage Builder for Manjaro/Arch Linux
# This script creates a portable AppImage package

set -e

echo "🔨 Building CloudToLocalLLM AppImage for Manjaro Linux..."

# Configuration
APP_NAME="CloudToLocalLLM"
VERSION="2.0.0"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="packaging/appimage/CloudToLocalLLM.AppDir"
OUTPUT_DIR="dist"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Clean and create AppDir
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/pixmaps"

# Build the Flutter application
echo "📦 Building Flutter application..."
flutter build linux --release

# Build the tray daemon
echo "🔧 Building tray daemon..."
./scripts/build/build_tray_daemon.sh

# Copy application files
echo "📋 Copying application files..."
cp -r "$BUILD_DIR" "$APPDIR/usr/lib/cloudtolocalllm"

# Copy tray daemon
echo "📋 Copying tray daemon..."
mkdir -p "$APPDIR/bin"
cp "dist/tray_daemon/linux-x64/cloudtolocalllm-tray" "$APPDIR/bin/"

# Create AppRun script
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"

# Set up environment for system tray
export QT_QPA_PLATFORM_PLUGIN_PATH="${HERE}/usr/lib/qt/plugins"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS}"

cd "${HERE}/usr/lib/cloudtolocalllm"
exec "${HERE}/usr/lib/cloudtolocalllm/cloudtolocalllm" "$@"
EOF

chmod +x "$APPDIR/AppRun"

# Create desktop file
cat > "$APPDIR/cloudtolocalllm.desktop" << 'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Local LLM Management with Cloud Interface
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Terminal=false
Type=Application
Categories=Development;Utility;
StartupWMClass=cloudtolocalllm
StartupNotify=true
Keywords=LLM;AI;Ollama;Machine Learning;Local;
X-AppImage-Version=2.0.0
EOF

# Copy desktop file to standard location
cp "$APPDIR/cloudtolocalllm.desktop" "$APPDIR/usr/share/applications/"

# Create a simple icon using ImageMagick or copy existing
if command -v convert &> /dev/null; then
    echo "🎨 Creating application icon..."
    convert -size 128x128 xc:'#2196F3' -fill white -gravity center \
            -font DejaVu-Sans-Bold -pointsize 24 -annotate +0+0 'CTL' \
            "$APPDIR/cloudtolocalllm.png"
else
    echo "📝 Using placeholder icon..."
    if [ -f "assets/images/tray_icon.png" ]; then
        cp "assets/images/tray_icon.png" "$APPDIR/cloudtolocalllm.png"
    else
        # Create minimal PNG header for a 1x1 transparent pixel
        echo -e '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x18\xdd\x8d\xb4\x1c\x00\x00\x00\x00IEND\xaeB`\x82' > "$APPDIR/cloudtolocalllm.png"
    fi
fi

# Copy icon to standard location
cp "$APPDIR/cloudtolocalllm.png" "$APPDIR/usr/share/pixmaps/"

# Download appimagetool if not present
APPIMAGETOOL="packaging/appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo "📥 Downloading appimagetool..."
    mkdir -p packaging
    wget -O "$APPIMAGETOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$APPIMAGETOOL"
fi

# Build AppImage
echo "🏗️  Building AppImage..."
ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_DIR/$APP_NAME-$VERSION-x86_64.AppImage"

# Make the AppImage executable
chmod +x "$OUTPUT_DIR/$APP_NAME-$VERSION-x86_64.AppImage"

echo "✅ AppImage created: $OUTPUT_DIR/$APP_NAME-$VERSION-x86_64.AppImage"
echo ""
echo "📦 Usage instructions:"
echo "   ./$OUTPUT_DIR/$APP_NAME-$VERSION-x86_64.AppImage"
echo ""
echo "🔧 Features included:"
echo "   ✅ System tray integration"
echo "   ✅ Direct Ollama connectivity (localhost:11434)"
echo "   ✅ Auth0 authentication (localhost:8080/callback)"
echo "   ✅ Portable - no installation required"
echo ""
echo "🚀 To test the application:"
echo "   ./$OUTPUT_DIR/$APP_NAME-$VERSION-x86_64.AppImage"
