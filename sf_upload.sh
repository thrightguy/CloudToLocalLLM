#!/bin/bash

# SourceForge File Upload Script for CloudToLocalLLM
# Uploads binary files to SourceForge file hosting

set -e

VERSION=${1:-"v3.0.1"}
SF_USER="imrightguy"
SF_PROJECT="cloudtolocalllm"

echo "=== CloudToLocalLLM SourceForge Upload ==="
echo "Version: $VERSION"
echo "Project: $SF_PROJECT"
echo ""

# Create test archive
ARCHIVE_NAME="cloudtolocalllm-${VERSION}-binaries.tar.gz"

echo "📦 Creating archive: $ARCHIVE_NAME"
mkdir -p dist
echo "CloudToLocalLLM v$VERSION Binary Archive" > dist/README.txt
echo "This archive contains the binary files for CloudToLocalLLM" >> dist/README.txt
echo "Generated on: $(date)" >> dist/README.txt

tar -czf "$ARCHIVE_NAME" -C dist .

# Calculate checksum
echo "🔐 Calculating SHA256 checksum..."
CHECKSUM=$(sha256sum "$ARCHIVE_NAME" | cut -d' ' -f1)
echo "$CHECKSUM  $ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"

echo "✅ Archive created:"
echo "  File: $ARCHIVE_NAME"
echo "  Size: $(du -h "$ARCHIVE_NAME" | cut -f1)"
echo "  SHA256: $CHECKSUM"
echo ""

# Upload to SourceForge
echo "🚀 Uploading to SourceForge..."
echo "Target: $SF_USER@frs.sourceforge.net:/home/frs/project/$SF_PROJECT/"

rsync -avz --progress "$ARCHIVE_NAME" "$ARCHIVE_NAME.sha256" \
    "$SF_USER@frs.sourceforge.net:/home/frs/project/$SF_PROJECT/"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Upload successful!"
    echo "📁 Files available at:"
    echo "   https://sourceforge.net/projects/$SF_PROJECT/files/$ARCHIVE_NAME/download"
    echo "   https://sourceforge.net/projects/$SF_PROJECT/files/$ARCHIVE_NAME.sha256/download"
    echo ""
    echo "🔗 For AUR PKGBUILD, use:"
    echo "   source=(\"https://sourceforge.net/projects/$SF_PROJECT/files/$ARCHIVE_NAME/download\")"
    echo "   sha256sums=('$CHECKSUM')"
    echo ""
    echo "🧹 Cleaning up local files..."
    rm -f "$ARCHIVE_NAME" "$ARCHIVE_NAME.sha256"
else
    echo "❌ Upload failed!"
    exit 1
fi
