#!/usr/bin/env python3
"""
Test different pystray backends
"""

import sys
import os


def test_backends():
    """Test available pystray backends"""
    print("Testing pystray backends...")

    # Create a simple test icon (for potential future use)
    # icon_image = Image.new('RGB', (16, 16), color='blue')

    # Test different backends
    backends_to_test = []

    try:
        import pystray._xorg
        backends_to_test.append(('xorg', pystray._xorg))
        print("✓ X11/Xorg backend available")
    except ImportError:
        print("✗ X11/Xorg backend not available")

    try:
        import pystray._gtk
        backends_to_test.append(('gtk', pystray._gtk))
        print("✓ GTK backend available")
    except ImportError:
        print("✗ GTK backend not available")

    try:
        import pystray._appindicator
        backends_to_test.append(('appindicator', pystray._appindicator))
        print("✓ AppIndicator backend available")
    except ImportError:
        print("✗ AppIndicator backend not available")

    # Check environment variables that might affect backend selection
    print("\nEnvironment variables:")
    env_vars = ['DISPLAY', 'WAYLAND_DISPLAY', 'XDG_CURRENT_DESKTOP', 'XDG_SESSION_TYPE']
    for var in env_vars:
        value = os.environ.get(var, 'Not set')
        print(f"  {var}: {value}")

    return backends_to_test


def test_appindicator_specifically():
    """Test AppIndicator backend specifically"""
    print("\nTesting AppIndicator backend specifically...")

    try:
        # Try to import and use AppIndicator directly
        import gi
        gi.require_version('AppIndicator3', '0.1')
        from gi.repository import AppIndicator3

        print("✓ AppIndicator3 GI binding available")

        # Try to create an indicator
        indicator = AppIndicator3.Indicator.new(
            "test-indicator",
            "application-default-icon",
            AppIndicator3.IndicatorCategory.APPLICATION_STATUS
        )

        print("✓ AppIndicator3 indicator created successfully")

        # Set status
        indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        print("✓ AppIndicator3 status set to ACTIVE")

        return True

    except Exception as e:
        print(f"✗ AppIndicator3 test failed: {e}")
        return False


def main():
    print("CloudToLocalLLM System Tray Backend Test")
    print("=" * 40)

    # Test available backends
    backends = test_backends()

    # Test AppIndicator specifically
    appindicator_works = test_appindicator_specifically()

    print("\nSummary:")
    print(f"Available backends: {len(backends)}")
    for name, _ in backends:
        print(f"  - {name}")

    print(f"AppIndicator3 working: {appindicator_works}")

    # Recommendations
    print("\nRecommendations:")
    if appindicator_works:
        print("✓ AppIndicator3 is working - this should work well with KDE")
        print("  Try forcing pystray to use AppIndicator backend")
    else:
        print("✗ AppIndicator3 not working - may need to install packages")
        print("  Try: sudo pacman -S libappindicator-gtk3")

    return 0


if __name__ == '__main__':
    sys.exit(main())
