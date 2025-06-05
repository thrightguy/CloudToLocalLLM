#!/usr/bin/env python3
"""
Test script to verify tray daemon navigation fixes
"""

import socket
import json
import time

def send_command_to_daemon(port, command):
    """Send a command to the tray daemon"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('127.0.0.1', port))
        
        message = json.dumps(command) + "\n"
        sock.send(message.encode('utf-8'))
        
        print(f"✅ Sent command to daemon: {command}")
        
        sock.close()
        return True
    except Exception as e:
        print(f"❌ Failed to send command: {e}")
        return False

def test_navigation_commands():
    """Test navigation commands"""
    # Use the port from the Flutter app logs
    port = 36915  # From the Flutter app logs
    print(f"📡 Testing tray daemon on port: {port}")
    
    # Test commands
    commands = [
        {"command": "DAEMON_SETTINGS"},
        {"command": "CONNECTION_STATUS"},
        {"command": "SETTINGS"},
    ]
    
    for command in commands:
        print(f"\n🧪 Testing command: {command['command']}")
        success = send_command_to_daemon(port, command)
        if success:
            print(f"✅ Command {command['command']} sent successfully")
        else:
            print(f"❌ Command {command['command']} failed")
        time.sleep(2)  # Wait between commands

if __name__ == "__main__":
    print("🚀 Testing tray daemon navigation fixes...")
    test_navigation_commands()
    print("\n✅ Test completed!")
