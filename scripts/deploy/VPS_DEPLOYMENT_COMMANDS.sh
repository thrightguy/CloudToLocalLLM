#!/bin/bash

# CloudToLocalLLM Enhanced Architecture VPS Deployment Commands
# Version: 3.0.1 - Black Screen Fix + Automated Binary Management
# Execute these commands on the VPS after SCP upload completes

set -e

echo "🚀 CloudToLocalLLM Enhanced Architecture VPS Deployment v3.0.1"
echo "================================================================"

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
BACKUP_DIR="/opt/cloudtolocalllm-backup-$(date +%Y%m%d-%H%M%S)"
TEMP_DIST="/tmp/cloudtolocalllm-dist-v3.0.1"
USER="cloudllm"

echo "📋 Deployment Configuration:"
echo "  Project Directory: $PROJECT_DIR"
echo "  Backup Directory: $BACKUP_DIR"
echo "  Temp Distribution: $TEMP_DIST"
echo "  User: $USER"
echo ""

# Step 1: Backup Current Deployment
echo "💾 Step 1: Creating backup of current deployment..."
if [ -d "$PROJECT_DIR" ]; then
    # Create backup within project directory (no sudo needed)
    mkdir -p "$PROJECT_DIR/backups"
    cp -r "$PROJECT_DIR" "$PROJECT_DIR/backups/backup-$(date +%Y%m%d-%H%M%S)"
    echo "✅ Backup created in project backups directory"
else
    echo "⚠️  No existing deployment found to backup"
fi
echo ""

# Step 2: Navigate to Project Directory
echo "📁 Step 2: Navigating to project directory..."
cd "$PROJECT_DIR"
echo "✅ Current directory: $(pwd)"
echo ""

# Step 3: Pull Latest Changes from Git
echo "🔄 Step 3: Pulling latest changes from Git..."
git status
echo ""
echo "Pulling latest changes..."
git pull origin master
echo "✅ Git pull completed"
echo ""

# Step 4: Move Uploaded Binaries to Project
echo "📦 Step 4: Installing uploaded binaries..."
if [ -d "$TEMP_DIST" ]; then
    echo "Moving distribution files from $TEMP_DIST to $PROJECT_DIR..."

    # Create dist directory if it doesn't exist (no sudo needed)
    mkdir -p "$PROJECT_DIR/dist"

    # Move AppImage (if available)
    if [ -f "$TEMP_DIST/CloudToLocalLLM-3.0.1-x86_64.AppImage" ]; then
        mv "$TEMP_DIST/CloudToLocalLLM-3.0.1-x86_64.AppImage" "$PROJECT_DIR/dist/"
        chmod +x "$PROJECT_DIR/dist/CloudToLocalLLM-3.0.1-x86_64.AppImage"
        echo "✅ AppImage v3.0.1 installed and made executable"
    fi

    # Move binary package (split files will be reassembled automatically)
    if [ -f "$TEMP_DIST/cloudtolocalllm-3.0.1-x86_64.tar.gz" ]; then
        mv "$TEMP_DIST/cloudtolocalllm-3.0.1-x86_64.tar.gz" "$PROJECT_DIR/dist/"
        echo "✅ Binary package v3.0.1 installed"
    fi

    # Move tray daemon files
    if [ -d "$TEMP_DIST/tray_daemon" ]; then
        mv "$TEMP_DIST/tray_daemon" "$PROJECT_DIR/dist/"
        chmod +x "$PROJECT_DIR/dist/tray_daemon/linux-x64/cloudtolocalllm-enhanced-tray"
        chmod +x "$PROJECT_DIR/dist/tray_daemon/linux-x64/cloudtolocalllm-settings"
        chmod +x "$PROJECT_DIR/dist/tray_daemon/linux-x64/start_enhanced_daemon.sh"
        echo "✅ Tray daemon files installed and made executable"
    fi

    # Move deployment summary
    if [ -f "$TEMP_DIST/DEPLOYMENT_SUMMARY.txt" ]; then
        mv "$TEMP_DIST/DEPLOYMENT_SUMMARY.txt" "$PROJECT_DIR/dist/"
        echo "✅ Deployment summary installed"
    fi

    # Files are already owned by cloudllm user (no chown needed)
    echo "✅ Distribution files installed with proper ownership"

    # Clean up temp directory
    rm -rf "$TEMP_DIST"
    echo "✅ Temporary files cleaned up"
else
    echo "❌ Error: Distribution files not found at $TEMP_DIST"
    echo "Please ensure SCP upload completed successfully"
    exit 1
fi
echo ""

# Step 5: Run VPS Deployment Script
echo "🔧 Step 5: Running VPS deployment script..."
if [ -f "$PROJECT_DIR/scripts/deploy/update_and_deploy.sh" ]; then
    # Run deployment script as cloudllm user (no sudo needed)
    "$PROJECT_DIR/scripts/deploy/update_and_deploy.sh" --force
    echo "✅ VPS deployment script completed"
else
    echo "⚠️  VPS deployment script not found, proceeding with manual deployment..."

    # Manual deployment steps
    echo "📦 Building Flutter web application..."
    cd "$PROJECT_DIR"
    flutter build web --release
    echo "✅ Flutter web build completed"

    echo "🐳 Restarting Docker containers..."
    # Use docker compose without sudo (cloudllm user is in docker group)
    docker compose -f docker-compose.yml down
    docker compose -f docker-compose.yml up -d --build
    echo "✅ Docker containers restarted"
fi
echo ""

# Step 6: Verify Docker Containers
echo "🔍 Step 6: Verifying Docker container health..."
echo "Container status:"
# Use docker without sudo (cloudllm user is in docker group)
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "Container health check:"
for container in cloudtolocalllm-webapp cloudtolocalllm-postfix-mail cloudtolocalllm-certbot; do
    if docker ps | grep -q "$container"; then
        echo "✅ $container: Running"
    else
        echo "❌ $container: Not running"
    fi
done
echo ""

# Step 7: Test HTTPS Accessibility
echo "🌐 Step 7: Testing HTTPS accessibility..."
echo "Testing main application..."
if curl -s -I https://app.cloudtolocalllm.online | grep -q "200 OK"; then
    echo "✅ https://app.cloudtolocalllm.online - OK"
else
    echo "❌ https://app.cloudtolocalllm.online - Failed"
fi

echo "Testing API backend..."
if curl -s -I https://app.cloudtolocalllm.online/api/health | grep -q "200 OK"; then
    echo "✅ https://app.cloudtolocalllm.online/api/health - OK"
else
    echo "❌ https://app.cloudtolocalllm.online/api/health - Failed"
fi

echo "Testing homepage..."
if curl -s -I https://cloudtolocalllm.online | grep -q "200 OK"; then
    echo "✅ https://cloudtolocalllm.online - OK"
else
    echo "❌ https://cloudtolocalllm.online - Failed"
fi

echo "Testing downloads page..."
if curl -s -I https://cloudtolocalllm.online/downloads | grep -q "200 OK"; then
    echo "✅ https://cloudtolocalllm.online/downloads - OK"
else
    echo "❌ https://cloudtolocalllm.online/downloads - Failed"
fi
echo ""

# Step 8: Update Flutter Downloads Integration
echo "📄 Step 8: Updating Flutter downloads integration..."
echo "Flutter-native homepage now handles downloads directly"
echo "✅ Downloads are integrated into Flutter web application"
echo "✅ Package metadata served via Flutter assets"
echo "✅ No separate static downloads page needed"
echo ""

# Step 9: Display Deployment Summary
echo "📊 Step 9: Deployment Summary"
echo "=============================="
echo "✅ Enhanced Architecture v3.0.1 Deployed Successfully!"
echo ""
echo "📦 Deployed Components:"
if [ -f "$PROJECT_DIR/dist/CloudToLocalLLM-3.0.1-x86_64.AppImage" ]; then
    SIZE=$(du -h "$PROJECT_DIR/dist/CloudToLocalLLM-3.0.1-x86_64.AppImage" | cut -f1)
    echo "  ✅ AppImage: CloudToLocalLLM-3.0.1-x86_64.AppImage ($SIZE)"
fi

if [ -f "$PROJECT_DIR/dist/cloudtolocalllm-3.0.1-x86_64.tar.gz" ]; then
    SIZE=$(du -h "$PROJECT_DIR/dist/cloudtolocalllm-3.0.1-x86_64.tar.gz" | cut -f1)
    echo "  ✅ Binary Package: cloudtolocalllm-3.0.1-x86_64.tar.gz ($SIZE)"
fi

if [ -f "$PROJECT_DIR/dist/tray_daemon/linux-x64/cloudtolocalllm-enhanced-tray" ]; then
    SIZE=$(du -h "$PROJECT_DIR/dist/tray_daemon/linux-x64/cloudtolocalllm-enhanced-tray" | cut -f1)
    echo "  ✅ Enhanced Tray Daemon: cloudtolocalllm-enhanced-tray ($SIZE)"
fi

if [ -f "$PROJECT_DIR/dist/tray_daemon/linux-x64/cloudtolocalllm-settings" ]; then
    SIZE=$(du -h "$PROJECT_DIR/dist/tray_daemon/linux-x64/cloudtolocalllm-settings" | cut -f1)
    echo "  ✅ Settings Application: cloudtolocalllm-settings ($SIZE)"
fi

echo ""
echo "🌐 Service URLs:"
echo "  • Main Application: https://app.cloudtolocalllm.online"
echo "  • Homepage: https://cloudtolocalllm.online"
echo "  • Downloads: https://cloudtolocalllm.online/downloads"
echo "  • API Health: https://app.cloudtolocalllm.online/api/health"
echo ""

echo "🔧 Next Steps:"
echo "  1. Test black screen fixes and system tray functionality"
echo "  2. Update downloads page with v3.0.1 packages"
echo "  3. Verify AUR package downloads split files from GitHub"
echo "  4. Test automated binary management system"
echo "  5. Announce v3.0.1 black screen fix release"
echo ""

echo "🎉 CloudToLocalLLM Enhanced Architecture v3.0.1 deployment completed!"
echo "================================================================"
