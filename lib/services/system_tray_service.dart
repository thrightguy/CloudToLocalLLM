import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

/// Service for managing system tray functionality
class SystemTrayService with TrayListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  bool _isInitialized = false;
  Function()? _onShowWindow;
  Function()? _onHideWindow;
  Function()? _onQuit;

  /// Initialize the system tray
  Future<bool> initialize({
    Function()? onShowWindow,
    Function()? onHideWindow,
    Function()? onQuit,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint("Starting system tray initialization...");

      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onQuit = onQuit;

      // Add this service as a listener
      trayManager.addListener(this);

      // Set the tray icon - try multiple approaches
      await _setTrayIcon();
      debugPrint("System tray icon set successfully");

      // Set up context menu
      await _setupContextMenu();
      debugPrint("System tray context menu set successfully");

      _isInitialized = true;
      debugPrint("System tray initialized successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to initialize system tray: $e");
      return false;
    }
  }

  /// Set up the context menu for the system tray
  Future<void> _setupContextMenu() async {
    final Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show CloudToLocalLLM',
        ),
        MenuItem(
          key: 'hide_window',
          label: 'Hide to Tray',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'settings',
          label: 'Settings',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'Quit',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  /// Try multiple approaches to set the tray icon
  Future<void> _setTrayIcon() async {
    if (Platform.isLinux) {
      // Try different approaches for Linux - prioritize custom icons for branding
      final approaches = [
        // Try custom icons first for proper branding
        () async {
          final iconPath = _getTrayIconPath();
          debugPrint("Trying custom CloudToLocalLLM icon: $iconPath");
          await trayManager.setIcon(iconPath);
        },
        // Try app icon as fallback
        () async {
          final iconPath = _getAppIconPath();
          debugPrint("Trying app icon: $iconPath");
          await trayManager.setIcon(iconPath);
        },
        // Try system icons as last resort
        () async {
          debugPrint("Trying system icon: application-x-executable");
          await trayManager.setIcon("application-x-executable");
        },
        () async {
          debugPrint("Trying system icon: applications-system");
          await trayManager.setIcon("applications-system");
        },
        () async {
          debugPrint("Trying system icon: computer");
          await trayManager.setIcon("computer");
        },
      ];

      for (final approach in approaches) {
        try {
          await approach();
          debugPrint("Successfully set tray icon");
          return;
        } catch (e) {
          debugPrint("Failed to set tray icon: $e");
        }
      }

      debugPrint("All tray icon approaches failed");
    } else {
      // For Windows/macOS, use custom icon
      final iconPath = _getTrayIconPath();
      debugPrint("Setting tray icon with path: $iconPath");
      await trayManager.setIcon(iconPath);
    }
  }

  /// Get the app icon path for fallback
  String _getAppIconPath() {
    if (Platform.isLinux) {
      final iconPaths = [
        // Try different sizes and locations for app icon
        'data/flutter_assets/assets/images/app_icon.png',
        '${Directory.current.path}/data/flutter_assets/assets/images/app_icon.png',
        '${Directory.current.path}/assets/images/app_icon.png',
        'assets/images/app_icon.png',
        './app_icon.png',
        'app_icon.png',
      ];

      for (final iconPath in iconPaths) {
        final file = File(iconPath);
        if (file.existsSync()) {
          debugPrint("Found app icon at: $iconPath");
          return iconPath;
        }
      }

      debugPrint("No app icon found, using fallback path");
      return 'assets/images/app_icon.png';
    } else if (Platform.isWindows) {
      return 'assets/images/app_icon.ico';
    } else {
      // macOS
      return 'assets/images/app_icon.png';
    }
  }

  /// Get the appropriate tray icon path for the current platform
  String _getTrayIconPath() {
    // For Linux, try multiple icon paths and sizes as system tray can be picky
    if (Platform.isLinux) {
      final iconPaths = [
        // Try different sizes in current directory first
        'tray_icon_16.png',
        'tray_icon_24.png',
        'tray_icon.png',
        './tray_icon_16.png',
        './tray_icon_24.png',
        './tray_icon.png',
        // Try data directory with different sizes
        'data/flutter_assets/assets/images/tray_icon_16.png',
        'data/flutter_assets/assets/images/tray_icon_24.png',
        'data/flutter_assets/assets/images/tray_icon.png',
        // Try absolute paths with different sizes
        '${Directory.current.path}/tray_icon_16.png',
        '${Directory.current.path}/tray_icon_24.png',
        '${Directory.current.path}/tray_icon.png',
        '${Directory.current.path}/assets/images/tray_icon_16.png',
        '${Directory.current.path}/assets/images/tray_icon_24.png',
        '${Directory.current.path}/assets/images/tray_icon.png',
        '${Directory.current.path}/data/flutter_assets/assets/images/tray_icon_16.png',
        '${Directory.current.path}/data/flutter_assets/assets/images/tray_icon_24.png',
        '${Directory.current.path}/data/flutter_assets/assets/images/tray_icon.png',
        // Try relative paths as fallback
        'assets/images/tray_icon_16.png',
        'assets/images/tray_icon_24.png',
        'assets/images/tray_icon.png',
      ];

      for (final iconPath in iconPaths) {
        final file = File(iconPath);
        if (file.existsSync()) {
          debugPrint("Found tray icon at: $iconPath");
          return iconPath;
        }
      }

      debugPrint("No tray icon found, using fallback path");
      return 'assets/images/tray_icon.png';
    } else if (Platform.isWindows) {
      return 'assets/images/tray_icon.ico';
    } else {
      // macOS
      return 'assets/images/tray_icon.png';
    }
  }

  /// Update the tray tooltip
  Future<void> setTooltip(String tooltip) async {
    if (_isInitialized) {
      try {
        await trayManager.setToolTip(tooltip);
      } catch (e) {
        debugPrint(
            "Failed to set tooltip (this is normal on some Linux systems): $e");
      }
    }
  }

  /// Show a notification from the system tray
  Future<void> showNotification({
    required String title,
    required String message,
  }) async {
    if (_isInitialized) {
      // Note: tray_manager package doesn't have built-in notifications
      // You might want to use a separate notification package
      debugPrint("Notification: $title - $message");
    }
  }

  /// Destroy the system tray
  Future<void> destroy() async {
    if (_isInitialized) {
      trayManager.removeListener(this);
      await trayManager.destroy();
      _isInitialized = false;
      debugPrint("System tray destroyed");
    }
  }

  /// Check if system tray is supported on this platform
  static bool isSupported() {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Get the current initialization status
  bool get isInitialized => _isInitialized;

  // TrayListener implementation
  @override
  void onTrayIconMouseDown() {
    debugPrint("Tray icon clicked");
    _onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint("Tray icon right-clicked");
    // Context menu will be shown automatically
  }

  @override
  void onTrayIconRightMouseUp() {
    // Not used
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint("Tray menu item clicked: ${menuItem.key}");

    switch (menuItem.key) {
      case 'show_window':
        _onShowWindow?.call();
        break;
      case 'hide_window':
        _onHideWindow?.call();
        break;
      case 'settings':
        _onShowWindow?.call(); // For now, just show the window
        break;
      case 'quit':
        _onQuit?.call();
        break;
      default:
        debugPrint("Unknown menu item: ${menuItem.key}");
    }
  }
}
