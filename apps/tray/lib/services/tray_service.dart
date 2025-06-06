import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

/// Flutter-only system tray service using tray_manager
///
/// Provides reliable system tray functionality with:
/// - Monochrome icons for Linux compatibility
/// - Authentication-aware menu updates
/// - TCP IPC communication with other apps
/// - Independent operation (no dependency on main app)
class TrayService extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  String _connectionState = 'idle'; // idle, connected, error
  String _status = 'Not Initialized';

  // Callbacks
  Function()? _onShowWindow;
  Function()? _onHideWindow;
  Function()? _onSettings;
  Function()? _onQuit;

  /// Check if system tray is supported on this platform
  bool get isSupported => !kIsWeb && _isDesktopPlatform();

  /// Check if system tray is initialized
  bool get isInitialized => _isInitialized;

  /// Get current status for UI display
  String get status => _status;

  /// Get authentication status
  bool get isAuthenticated => _isAuthenticated;

  /// Get connection state
  String get connectionState => _connectionState;

  /// Initialize the system tray service
  Future<bool> initialize({
    Function()? onShowWindow,
    Function()? onHideWindow,
    Function()? onSettings,
    Function()? onQuit,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint("Initializing TrayService...");

      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onSettings = onSettings;
      _onQuit = onQuit;

      // Check if platform is supported
      if (!isSupported) {
        debugPrint("System tray not supported on this platform");
        _status = "Not Supported";
        notifyListeners();
        return false;
      }

      _status = "Initializing";
      notifyListeners();

      // Set tray icon
      await _setTrayIcon();

      // Create and set context menu
      await _createContextMenu();

      _isInitialized = true;
      _status = "Running";
      notifyListeners();

      debugPrint("TrayService initialized successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to initialize TrayService: $e");
      _status = "Error: $e";
      notifyListeners();
      return false;
    }
  }

  /// Set the tray icon based on platform and state
  Future<void> _setTrayIcon() async {
    try {
      String iconPath;

      if (Platform.isWindows) {
        iconPath = 'assets/images/tray_icon_mono.ico';
      } else {
        // Use monochrome PNG for Linux/macOS compatibility
        iconPath = _getMonochromeIconPath();
      }

      await trayManager.setIcon(iconPath);
      debugPrint("Tray icon set: $iconPath");
    } catch (e) {
      debugPrint("Failed to set tray icon: $e");
      // Try fallback icon
      await _setFallbackIcon();
    }
  }

  /// Get monochrome icon path based on current state
  String _getMonochromeIconPath() {
    switch (_connectionState) {
      case 'connected':
        return 'assets/images/tray_icon_connected_mono.png';
      case 'error':
        return 'assets/images/tray_icon_error_mono.png';
      default:
        return 'assets/images/tray_icon_idle_mono.png';
    }
  }

  /// Set fallback icon if main icon fails
  Future<void> _setFallbackIcon() async {
    try {
      // Use a simple embedded icon as fallback
      await trayManager.setIcon('assets/images/tray_icon_simple.png');
      debugPrint("Fallback tray icon set");
    } catch (e) {
      debugPrint("Failed to set fallback tray icon: $e");
    }
  }

  /// Create and set the context menu
  Future<void> _createContextMenu() async {
    try {
      List<MenuItem> menuItems = [];

      // Show/Hide window options
      menuItems.add(MenuItem(key: 'show_window', label: 'Show Window'));

      menuItems.add(MenuItem(key: 'hide_window', label: 'Hide Window'));

      menuItems.add(MenuItem.separator());

      // Settings option (always available)
      menuItems.add(MenuItem(key: 'settings', label: 'Settings'));

      // Authentication-aware menu items
      if (_isAuthenticated) {
        menuItems.add(MenuItem.separator());
        menuItems.add(MenuItem(key: 'chat', label: 'Open Chat'));
      }

      menuItems.add(MenuItem.separator());

      // Quit option
      menuItems.add(MenuItem(key: 'quit', label: 'Quit'));

      Menu menu = Menu(items: menuItems);
      await trayManager.setContextMenu(menu);

      debugPrint("Context menu created with ${menuItems.length} items");
    } catch (e) {
      debugPrint("Failed to create context menu: $e");
    }
  }

  /// Update authentication status and refresh menu
  Future<void> updateAuthenticationStatus(bool isAuthenticated) async {
    if (_isAuthenticated != isAuthenticated) {
      _isAuthenticated = isAuthenticated;
      debugPrint("Authentication status updated: $isAuthenticated");

      // Refresh context menu with new auth status
      await _createContextMenu();

      notifyListeners();
    }
  }

  /// Update connection state and icon
  Future<void> updateConnectionState(String state) async {
    if (_connectionState != state) {
      _connectionState = state;
      debugPrint("Connection state updated: $state");

      // Update tray icon to reflect new state
      await _setTrayIcon();

      notifyListeners();
    }
  }

  /// Update tooltip text
  Future<void> setTooltip(String tooltip) async {
    try {
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      debugPrint("Failed to set tooltip: $e");
    }
  }

  /// Handle menu item clicks
  void handleMenuClick(String key) {
    switch (key) {
      case 'show_window':
        _onShowWindow?.call();
        break;
      case 'hide_window':
        _onHideWindow?.call();
        break;
      case 'settings':
        _onSettings?.call();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }

  /// Check if current platform is desktop
  bool _isDesktopPlatform() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Cleanup resources
  @override
  Future<void> dispose() async {
    try {
      await trayManager.destroy();
      _isInitialized = false;
      _status = "Disposed";
      debugPrint("TrayService disposed");
    } catch (e) {
      debugPrint("Error disposing TrayService: $e");
    }
    super.dispose();
  }
}
