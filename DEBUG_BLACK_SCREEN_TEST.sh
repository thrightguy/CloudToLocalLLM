#!/bin/bash

# CloudToLocalLLM Black Screen Debug Test Script
# This script will run the application with comprehensive logging to debug navigation issues

set -e

echo "🐛 CloudToLocalLLM Black Screen Debug Test"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Not in CloudToLocalLLM project directory"
    echo "Please run: cd /home/rightguy/Dev/CloudToLocalLLM"
    exit 1
fi

echo "📁 Current directory: $(pwd)"

# Create debug log directory
DEBUG_LOG_DIR="debug_logs"
mkdir -p "$DEBUG_LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$DEBUG_LOG_DIR/black_screen_debug_$TIMESTAMP.log"

echo "📝 Debug logs will be saved to: $LOG_FILE"

# Function to cleanup processes
cleanup() {
    echo ""
    echo "🧹 Cleaning up processes..."
    
    # Kill any running CloudToLocalLLM processes
    pkill -f "cloudtolocalllm" || true
    pkill -f "enhanced_tray_daemon" || true
    
    # Kill any Python tray daemons
    pkill -f "cloudtolocalllm-tray" || true
    
    echo "✅ Cleanup complete"
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo ""
echo "🔍 Pre-flight checks..."

# Check if debug build exists
if [ ! -f "build/linux/x64/debug/bundle/cloudtolocalllm" ]; then
    echo "❌ Debug build not found. Building now..."
    flutter build linux --debug
fi

# Check if tray daemon exists
if [ ! -f "/usr/bin/cloudtolocalllm-tray" ]; then
    echo "⚠️  System tray daemon not found at /usr/bin/cloudtolocalllm-tray"
    echo "   This may cause tray functionality to fail"
fi

echo "✅ Pre-flight checks complete"

echo ""
echo "🚀 Starting CloudToLocalLLM with debug logging..."
echo "   Log file: $LOG_FILE"
echo "   Press Ctrl+C to stop and view logs"

# Start the application with debug logging
echo "Starting application at $(date)" > "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Run the application and capture all output
./build/linux/x64/debug/bundle/cloudtolocalllm 2>&1 | tee -a "$LOG_FILE" &
APP_PID=$!

echo "🎯 Application started with PID: $APP_PID"
echo ""
echo "📋 TESTING INSTRUCTIONS:"
echo "========================"
echo ""
echo "1. 🪟 Wait for the application to fully load"
echo "2. 🔍 Look for the system tray icon (usually in top-right corner)"
echo "3. 🖱️  Right-click the system tray icon"
echo "4. 🔧 Click 'Daemon Settings' - WATCH FOR BLACK SCREEN"
echo "5. 📊 Click 'Connection Status' - WATCH FOR BLACK SCREEN"
echo "6. 🪟 Click 'Show Window' - WATCH FOR BLACK SCREEN"
echo ""
echo "🔍 WHAT TO LOOK FOR:"
echo "==================="
echo "- Debug messages starting with 🔧, 📊, 🪟 in the terminal"
echo "- Navigation messages starting with 🧭"
echo "- Router messages starting with 🔧 [Router] or 📊 [Router]"
echo "- Screen initialization messages"
echo "- Any error messages or exceptions"
echo ""
echo "📝 LOGGING DETAILS:"
echo "=================="
echo "- All output is being logged to: $LOG_FILE"
echo "- Look for patterns like:"
echo "  * 🔧 [TrayDaemon] DAEMON_SETTINGS command sent"
echo "  * 🔄 [EnhancedTrayService] Received command: DAEMON_SETTINGS"
echo "  * 🧭 [Navigation] Attempting to navigate to route: /settings/daemon"
echo "  * 🔧 [Router] Building DaemonSettingsScreen"
echo "  * 🔧 [DaemonSettingsScreen] Initializing screen"
echo ""

# Wait for user input or application to exit
echo "⏳ Waiting for testing... (Press Enter when done testing, or Ctrl+C to stop)"
read -r

# Application is still running, let's check the logs
echo ""
echo "📊 ANALYSIS: Checking debug logs for navigation issues..."
echo "========================================================="

# Check if the log file has the expected debug messages
echo ""
echo "🔍 Checking for system tray initialization..."
if grep -q "🚀 \[SystemTray\]" "$LOG_FILE"; then
    echo "✅ System tray initialization found"
    grep "🚀 \[SystemTray\]" "$LOG_FILE" | tail -5
else
    echo "❌ System tray initialization NOT found"
fi

echo ""
echo "🔍 Checking for tray daemon commands..."
if grep -q "📤 \[TrayDaemon\]" "$LOG_FILE"; then
    echo "✅ Tray daemon commands found"
    grep "📤 \[TrayDaemon\]" "$LOG_FILE" | tail -10
else
    echo "❌ Tray daemon commands NOT found"
fi

echo ""
echo "🔍 Checking for enhanced tray service messages..."
if grep -q "🔄 \[EnhancedTrayService\]" "$LOG_FILE"; then
    echo "✅ Enhanced tray service messages found"
    grep "🔄 \[EnhancedTrayService\]" "$LOG_FILE" | tail -10
else
    echo "❌ Enhanced tray service messages NOT found"
fi

echo ""
echo "🔍 Checking for navigation attempts..."
if grep -q "🧭 \[Navigation\]" "$LOG_FILE"; then
    echo "✅ Navigation attempts found"
    grep "🧭 \[Navigation\]" "$LOG_FILE" | tail -10
else
    echo "❌ Navigation attempts NOT found"
fi

echo ""
echo "🔍 Checking for router screen building..."
if grep -q "\[Router\] Building" "$LOG_FILE"; then
    echo "✅ Router screen building found"
    grep "\[Router\] Building" "$LOG_FILE" | tail -5
else
    echo "❌ Router screen building NOT found"
fi

echo ""
echo "🔍 Checking for screen initialization..."
if grep -q "Screen\] Initializing screen" "$LOG_FILE"; then
    echo "✅ Screen initialization found"
    grep "Screen\] Initializing screen" "$LOG_FILE" | tail -5
else
    echo "❌ Screen initialization NOT found"
fi

echo ""
echo "🔍 Checking for errors..."
if grep -q "❌\|💥\|ERROR\|Exception" "$LOG_FILE"; then
    echo "⚠️  Errors found:"
    grep "❌\|💥\|ERROR\|Exception" "$LOG_FILE" | tail -10
else
    echo "✅ No obvious errors found"
fi

echo ""
echo "📋 SUMMARY:"
echo "==========="
echo "Full debug log saved to: $LOG_FILE"
echo ""
echo "🔍 To analyze the complete log:"
echo "cat $LOG_FILE | grep -E '🔧|📊|🪟|🧭|❌|💥'"
echo ""
echo "🔍 To see just navigation flow:"
echo "cat $LOG_FILE | grep -E 'TrayDaemon.*SETTINGS|EnhancedTrayService.*SETTINGS|Navigation.*settings|Router.*Settings|Screen.*Initializing'"

# Kill the application
kill $APP_PID 2>/dev/null || true

echo ""
echo "✨ Debug test complete!"
echo "📝 Review the log file for detailed analysis: $LOG_FILE"
