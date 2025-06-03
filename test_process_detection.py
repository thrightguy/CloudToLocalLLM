#!/usr/bin/env python3

import psutil
import sys

def test_process_detection():
    """Test if we can detect the CloudToLocalLLM process"""
    print("🔍 Testing CloudToLocalLLM process detection...")
    print("=" * 50)
    
    found_processes = []
    
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                name = proc.info['name'].lower()
                cmdline = ' '.join(proc.info['cmdline']).lower() if proc.info['cmdline'] else ''
                
                # Check if this looks like a CloudToLocalLLM process
                if 'cloudtolocalllm' in name or 'cloudtolocalllm' in cmdline:
                    found_processes.append({
                        'pid': proc.info['pid'],
                        'name': proc.info['name'],
                        'cmdline': proc.info['cmdline']
                    })
                    print(f"✅ Found CloudToLocalLLM process:")
                    print(f"   PID: {proc.info['pid']}")
                    print(f"   Name: {proc.info['name']}")
                    print(f"   Command: {' '.join(proc.info['cmdline']) if proc.info['cmdline'] else 'N/A'}")
                    print()
                    
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
                
    except Exception as e:
        print(f"❌ Error during process detection: {e}")
        return False
    
    if found_processes:
        print(f"✅ Found {len(found_processes)} CloudToLocalLLM process(es)")
        return True
    else:
        print("❌ No CloudToLocalLLM processes found")
        print("\n🔍 Let's check all running processes that might be related:")
        
        # Look for any processes that might be Flutter or related
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                name = proc.info['name'].lower()
                cmdline = ' '.join(proc.info['cmdline']).lower() if proc.info['cmdline'] else ''
                
                if any(keyword in name or keyword in cmdline for keyword in ['flutter', 'dart', 'com.example']):
                    print(f"🔍 Related process:")
                    print(f"   PID: {proc.info['pid']}")
                    print(f"   Name: {proc.info['name']}")
                    print(f"   Command: {' '.join(proc.info['cmdline']) if proc.info['cmdline'] else 'N/A'}")
                    print()
                    
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return False

if __name__ == "__main__":
    print("CloudToLocalLLM Process Detection Test")
    print("=====================================")
    print()
    
    if test_process_detection():
        print("🎯 Process detection is working correctly!")
        sys.exit(0)
    else:
        print("❌ Process detection failed!")
        print("\n💡 Suggestions:")
        print("1. Make sure CloudToLocalLLM is running")
        print("2. Check if the process name pattern needs updating")
        print("3. Run this test while the app is running")
        sys.exit(1)
