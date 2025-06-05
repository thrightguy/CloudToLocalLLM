#!/usr/bin/env python3
"""
Simple test script to debug system tray issues
"""

import sys
import time
import threading
from PIL import Image
import pystray
from pystray import MenuItem as Item


def create_test_icon():
    """Create a simple test icon"""
    # Create a simple 16x16 red square
    img = Image.new('RGB', (16, 16), color='red')
    return img


def on_clicked(icon, item):
    """Handle tray icon click"""
    print(f"Tray icon clicked: {item}")


def on_quit(icon, item):
    """Handle quit"""
    print("Quit requested")
    icon.stop()


def test_basic_tray():
    """Test basic system tray functionality"""
    print("Testing basic system tray functionality...")

    try:
        # Create test icon
        print("Creating test icon...")
        icon_image = create_test_icon()

        # Create menu
        print("Creating menu...")
        menu = pystray.Menu(
            Item("Test Item", on_clicked),
            pystray.Menu.SEPARATOR,
            Item("Quit", on_quit)
        )

        # Create tray icon
        print("Creating tray icon...")
        icon = pystray.Icon(
            "test_tray",
            icon_image,
            "Test Tray Icon",
            menu
        )

        print("Starting tray icon...")
        print(
            "If you see this message and the script hangs, "
            "the issue is with pystray.run()"
        )

        # This should show the tray icon
        icon.run()

        print("Tray icon stopped")

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()


def test_tray_support():
    """Test if system tray is supported"""
    print("Testing system tray support...")

    try:
        # Try to create a minimal icon to test support
        test_image = Image.new('RGBA', (16, 16), (255, 0, 0, 255))
        test_icon = pystray.Icon("test", test_image)
        print("✓ pystray.Icon creation successful")

        # Check if we can access the icon properties
        print(f"✓ Icon name: {test_icon.name}")
        print(f"✓ Icon title: {test_icon.title}")

        return True

    except Exception as e:
        print(f"✗ System tray support test failed: {e}")
        return False


def test_with_timeout():
    """Test tray with a timeout to avoid hanging"""
    print("Testing tray with timeout...")

    def run_tray():
        try:
            icon_image = create_test_icon()
            menu = pystray.Menu(Item("Quit", on_quit))
            icon = pystray.Icon("test_timeout", icon_image, "Test Timeout", menu)

            print("Starting tray with timeout...")
            icon.run()

        except Exception as e:
            print(f"Tray error: {e}")

    # Run tray in a separate thread
    tray_thread = threading.Thread(target=run_tray, daemon=True)
    tray_thread.start()

    # Wait for 5 seconds
    print("Waiting 5 seconds...")
    time.sleep(5)

    if tray_thread.is_alive():
        print("✓ Tray thread is still running (good sign)")
    else:
        print("✗ Tray thread exited (potential issue)")


def main():
    print("CloudToLocalLLM System Tray Debug Tool")
    print("=" * 40)

    # Test 1: Check basic support
    print("\n1. Testing system tray support...")
    if not test_tray_support():
        print("System tray support test failed. Exiting.")
        return 1

    # Test 2: Test with timeout
    print("\n2. Testing tray with timeout...")
    test_with_timeout()

    # Test 3: Ask user if they want to test full tray
    print("\n3. Full tray test (may hang if there are issues)")
    response = input("Do you want to run the full tray test? (y/N): ").lower()

    if response == 'y':
        print("Running full tray test...")
        print("Press Ctrl+C to stop if it hangs")
        test_basic_tray()
    else:
        print("Skipping full tray test")

    print("Debug test completed")
    return 0


if __name__ == '__main__':
    sys.exit(main())
