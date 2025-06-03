#!/usr/bin/env python3

import socket
import json
import time
import sys
from pathlib import Path

def get_tray_port():
    """Get the tray daemon port from the port file"""
    config_dir = Path.home() / ".cloudtolocalllm"
    port_file = config_dir / "tray_port"
    
    if not port_file.exists():
        print("❌ Tray port file not found. Is the tray daemon running?")
        return None
    
    try:
        with open(port_file, 'r') as f:
            port = int(f.read().strip())
        print(f"✅ Found tray daemon on port: {port}")
        return port
    except Exception as e:
        print(f"❌ Error reading port file: {e}")
        return None

def send_command_to_tray(command):
    """Send a command to the tray daemon to simulate menu clicks"""
    port = get_tray_port()
    if not port:
        return False
    
    try:
        print(f"📤 Connecting to tray daemon on port {port}...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('127.0.0.1', port))
        
        message = json.dumps({"command": command}) + "\n"
        print(f"📤 Sending command: {command}")
        sock.send(message.encode('utf-8'))
        
        # Wait a moment for the command to be processed
        time.sleep(1)
        
        sock.close()
        print(f"✅ Command {command} sent successfully")
        return True
        
    except Exception as e:
        print(f"❌ Error sending command {command}: {e}")
        return False

def test_navigation_commands():
    """Test the navigation commands that should trigger the new screens"""
    print("🧪 Testing Navigation Commands Programmatically")
    print("=" * 50)
    
    commands_to_test = [
        "DAEMON_SETTINGS",
        "CONNECTION_STATUS",
        "SHOW"
    ]
    
    print("⏳ Waiting 3 seconds for app to fully initialize...")
    time.sleep(3)
    
    for command in commands_to_test:
        print(f"\n🔧 Testing {command} command...")
        
        if send_command_to_tray(command):
            print(f"✅ {command} command sent successfully")
            print("   Check the Flutter app for navigation to the appropriate screen")
            print("   Look for debug messages in the app console")
        else:
            print(f"❌ Failed to send {command} command")
        
        # Wait between commands
        print("⏳ Waiting 3 seconds before next command...")
        time.sleep(3)
    
    print("\n🎯 All commands sent!")
    print("Check the Flutter application console for:")
    print("- 🔄 [EnhancedTrayService] messages")
    print("- 🧭 [Navigation] messages") 
    print("- 🔧 [Router] Building DaemonSettingsScreen")
    print("- 📊 [Router] Building ConnectionStatusScreen")
    print("- Screen initialization messages")

if __name__ == "__main__":
    print("CloudToLocalLLM Navigation Test")
    print("===============================")
    print()
    print("This script will programmatically send commands to the tray daemon")
    print("to test if the navigation to new screens works correctly.")
    print()
    print("Make sure CloudToLocalLLM is running before starting this test!")
    print()
    
    input("Press Enter to start the test...")
    
    test_navigation_commands()
    
    print("\n✨ Test complete!")
    print("Review the Flutter app console output for navigation debug messages.")
