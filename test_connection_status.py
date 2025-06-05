#!/usr/bin/env python3
"""
Test script to send connection status updates to tray daemon
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

def test_connection_status_update():
    """Test connection status update"""
    port = 36915  # From the Flutter app logs
    print(f"📡 Testing connection status update on port: {port}")
    
    # Test connection status update
    status_update = {
        "command": "UPDATE_CONNECTION_STATUS",
        "status": {
            "connected": True,
            "connection_type": "ollama",
            "version": "0.9.0",
            "models": ["qwen2.5-coder:7b", "gemma3:latest", "qwen3:latest", "deepseek-r1:latest"],
            "timestamp": "2025-06-05T07:35:00Z"
        }
    }
    
    print(f"\n🧪 Testing connection status update")
    success = send_command_to_daemon(port, status_update)
    if success:
        print(f"✅ Connection status update sent successfully")
    else:
        print(f"❌ Connection status update failed")

if __name__ == "__main__":
    print("🚀 Testing connection status updates...")
    test_connection_status_update()
    print("\n✅ Test completed!")
