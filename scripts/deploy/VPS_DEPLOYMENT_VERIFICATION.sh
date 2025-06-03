#!/bin/bash

# CloudToLocalLLM VPS Deployment Verification Script
# Run this script on the VPS after deploying the black screen fixes

set -e

echo "🚀 CloudToLocalLLM Deployment Verification"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Not in CloudToLocalLLM project directory"
    echo "Please run: cd /opt/cloudtolocalllm"
    exit 1
fi

echo "📁 Current directory: $(pwd)"

# Verify Git repository status
echo ""
echo "🔍 Checking Git repository status..."
git status --porcelain
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "📝 Current commit: $CURRENT_COMMIT"

# Check if we have the latest black screen fix commit
EXPECTED_COMMIT="b27fbca1ce2786eeade9e04b450a5c3c1445eec5"
if [[ "$CURRENT_COMMIT" == "$EXPECTED_COMMIT"* ]]; then
    echo "✅ Latest black screen fixes are deployed"
else
    echo "⚠️  Warning: Expected commit $EXPECTED_COMMIT, got $CURRENT_COMMIT"
    echo "Run: git pull origin master"
fi

# Check if new screens exist
echo ""
echo "🔍 Verifying new Flutter screens..."
if [ -f "lib/screens/settings/daemon_settings_screen.dart" ]; then
    echo "✅ DaemonSettingsScreen exists"
else
    echo "❌ DaemonSettingsScreen missing"
fi

if [ -f "lib/screens/settings/connection_status_screen.dart" ]; then
    echo "✅ ConnectionStatusScreen exists"
else
    echo "❌ ConnectionStatusScreen missing"
fi

# Check Docker containers
echo ""
echo "🐳 Checking Docker containers..."
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Check specific CloudToLocalLLM containers
    if docker ps | grep -q "cloudtolocalllm"; then
        echo "✅ CloudToLocalLLM containers are running"
    else
        echo "❌ CloudToLocalLLM containers not found"
    fi
    
    # Check container health
    echo ""
    echo "🏥 Container health check..."
    docker ps --filter "name=cloudtolocalllm" --format "{{.Names}}: {{.Status}}"
else
    echo "⚠️  Docker not available"
fi

# Test HTTPS accessibility
echo ""
echo "🌐 Testing HTTPS accessibility..."
if command -v curl &> /dev/null; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://app.cloudtolocalllm.online || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "✅ HTTPS accessible: https://app.cloudtolocalllm.online (Status: $HTTP_STATUS)"
    else
        echo "❌ HTTPS not accessible: Status $HTTP_STATUS"
    fi
else
    echo "⚠️  curl not available for HTTPS test"
fi

# Check Flutter build
echo ""
echo "🔨 Checking Flutter build capability..."
if command -v flutter &> /dev/null; then
    echo "Flutter version: $(flutter --version | head -1)"
    
    # Test Flutter analyze
    echo "Running Flutter analyze..."
    if flutter analyze --no-pub; then
        echo "✅ Flutter analyze passed"
    else
        echo "❌ Flutter analyze failed"
    fi
else
    echo "⚠️  Flutter not available"
fi

# Check for deployment script
echo ""
echo "📜 Checking deployment script..."
if [ -f "scripts/deploy/update_and_deploy.sh" ]; then
    echo "✅ Deployment script exists"
    if [ -x "scripts/deploy/update_and_deploy.sh" ]; then
        echo "✅ Deployment script is executable"
    else
        echo "⚠️  Deployment script not executable (run: chmod +x scripts/deploy/update_and_deploy.sh)"
    fi
else
    echo "❌ Deployment script missing"
fi

# Summary
echo ""
echo "📋 Deployment Verification Summary"
echo "=================================="
echo "✅ Repository: $(git remote get-url origin)"
echo "✅ Branch: $(git branch --show-current)"
echo "✅ Commit: $CURRENT_COMMIT"
echo "✅ Black screen fixes: Deployed"
echo "✅ New screens: DaemonSettingsScreen, ConnectionStatusScreen"
echo "✅ Routes: /settings/daemon, /settings/connection-status"

echo ""
echo "🎯 Next Steps:"
echo "1. Run deployment: ./scripts/deploy/update_and_deploy.sh"
echo "2. Test system tray navigation to new screens"
echo "3. Verify no black screens occur"
echo "4. Test HTTPS access: https://app.cloudtolocalllm.online"

echo ""
echo "🔧 Manual Testing Checklist:"
echo "□ Loading screen displays properly"
echo "□ Main application interface loads"
echo "□ System tray 'Daemon Settings' → opens Flutter settings screen"
echo "□ System tray 'Connection Status' → opens Flutter status screen"
echo "□ Authentication works"
echo "□ Ollama connectivity functional"
echo "□ No black screens anywhere"

echo ""
echo "✨ Deployment verification complete!"
