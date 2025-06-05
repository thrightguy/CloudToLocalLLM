#!/usr/bin/env python3
"""
Test AppIndicator backend specifically
"""

import sys
import time
import threading
from PIL import Image
import pystray
from pystray import MenuItem as Item


def create_test_icon():
    """Create a simple test icon"""
    # Create a simple 16x16 icon with transparency
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    # Draw a simple pattern
    for x in range(16):
        for y in range(16):
            if (x + y) % 4 == 0:
                img.putpixel((x, y), (255, 255, 255, 255))
    return img


def on_clicked(icon, item):
    """Handle menu item click"""
    print(f"Menu item clicked: {item}")


def on_show(icon, item):
    """Handle show"""
    print("Show requested")


def on_quit(icon, item):
    """Handle quit"""
    print("Quit requested")
    icon.stop()


def test_appindicator_tray():
    """Test AppIndicator tray specifically"""
    print("Testing AppIndicator tray...")

    try:
        # Force pystray to use AppIndicator backend
        import pystray._appindicator

        # Create test icon
        icon_image = create_test_icon()

        # Create menu
        menu = pystray.Menu(
            Item("Show CloudToLocalLLM", on_show),
            Item("Test Item", on_clicked),
            pystray.Menu.SEPARATOR,
            Item("Quit", on_quit)
        )

        # Create tray icon using AppIndicator backend
        print("Creating AppIndicator tray icon...")
        icon = pystray.Icon(
            "cloudtolocalllm-test",
            icon_image,
            "CloudToLocalLLM Test",
            menu
        )

        # AppIndicator should be used automatically if available

        print("Starting AppIndicator tray...")
        print("Look for the tray icon in your system tray!")
        print("Right-click to see the menu, or press Ctrl+C to stop")

        # Run the tray
        icon.run()

        print("Tray stopped")
        return True

    except Exception as e:
        print(f"AppIndicator test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_with_timeout():
    """Test tray with timeout to see if it works"""
    print("Testing AppIndicator with timeout...")

    success = False

    def run_tray():
        nonlocal success
        try:
            icon_image = create_test_icon()
            menu = pystray.Menu(
                Item("Test", on_clicked),
                Item("Quit", on_quit)
            )

            icon = pystray.Icon("test-timeout", icon_image, "Test", menu)

            # AppIndicator should be used automatically if available

            print("Starting tray with AppIndicator backend...")
            icon.run()
            success = True

        except Exception as e:
            print(f"Tray error: {e}")

    # Run in thread with timeout
    tray_thread = threading.Thread(target=run_tray, daemon=True)
    tray_thread.start()

    # Wait and check
    time.sleep(3)

    if tray_thread.is_alive():
        print("✓ AppIndicator tray is running!")
        print("Check your system tray for the icon")
        return True
    else:
        print("✗ AppIndicator tray failed to start")
        return False


def main():
    print("CloudToLocalLLM AppIndicator Test")
    print("=" * 35)

    # Test 1: Quick timeout test
    print("\n1. Quick AppIndicator test...")
    if test_with_timeout():
        print("AppIndicator backend appears to be working!")

        # Test 2: Full interactive test
        print("\n2. Full interactive test")
        response = input("Run full interactive test? (y/N): ").lower()

        if response == 'y':
            test_appindicator_tray()
        else:
            print("Skipping interactive test")
    else:
        print("AppIndicator backend test failed")
        return 1

    return 0


if __name__ == '__main__':
    sys.exit(main())
