import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Service for managing window state and visibility using window_manager_plus
class WindowManagerService {
  static final WindowManagerService _instance =
      WindowManagerService._internal();
  factory WindowManagerService() => _instance;
  WindowManagerService._internal();

  bool _isWindowVisible = true;
  bool _isMinimizedToTray = false;
  bool _isInitialized = false;

  /// Initialize the window manager service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize window_manager if not on web
      if (!kIsWeb) {
        await windowManager.ensureInitialized();
        await windowManager.setPreventClose(true);
        _isInitialized = true;
        debugPrint("🪟 [WindowManager] Window manager service initialized");
      }
    } catch (e) {
      debugPrint("🪟 [WindowManager] Failed to initialize window manager: $e");
    }
  }

  /// Show the application window
  Future<void> showWindow() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.show();
        await windowManager.focus();
      }
      _isWindowVisible = true;
      _isMinimizedToTray = false;
      debugPrint("🪟 [WindowManager] Window shown");
    } catch (e) {
      debugPrint("🪟 [WindowManager] Failed to show window: $e");
    }
  }

  /// Hide the application window to system tray
  Future<void> hideToTray() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.hide();
      }
      _isWindowVisible = false;
      _isMinimizedToTray = true;
      debugPrint("🪟 [WindowManager] Window hidden to tray");
    } catch (e) {
      debugPrint("🪟 [WindowManager] Failed to hide window: $e");
    }
  }

  /// Minimize the window (but keep it in taskbar)
  Future<void> minimizeWindow() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.minimize();
      }
      _isWindowVisible = false;
      _isMinimizedToTray = false;
      debugPrint("🪟 [WindowManager] Window minimized");
    } catch (e) {
      debugPrint("🪟 [WindowManager] Failed to minimize window: $e");
    }
  }

  /// Maximize the window
  Future<void> maximizeWindow() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.maximize();
      }
      _isWindowVisible = true;
      _isMinimizedToTray = false;
      debugPrint("🪟 [WindowManager] Window maximized");
    } catch (e) {
      debugPrint("🪟 [WindowManager] Failed to maximize window: $e");
    }
  }

  /// Toggle window visibility
  Future<void> toggleWindow() async {
    if (_isWindowVisible) {
      await hideToTray();
    } else {
      await showWindow();
    }
  }

  /// Force close the application (for quit functionality)
  Future<void> forceClose() async {
    try {
      if (!kIsWeb && _isInitialized) {
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      }
      debugPrint("🪟 [WindowManager] Application force closed");
    } catch (e) {
      debugPrint("🪟 [WindowManager] Failed to force close: $e");
    }
  }

  /// Check if window is currently visible
  bool get isWindowVisible => _isWindowVisible;

  /// Check if window is minimized to tray
  bool get isMinimizedToTray => _isMinimizedToTray;

  /// Check if window manager is initialized
  bool get isInitialized => _isInitialized;

  /// Set window visibility state (for internal tracking)
  void setWindowVisible(bool visible) {
    _isWindowVisible = visible;
    if (visible) {
      _isMinimizedToTray = false;
    }
  }

  /// Handle window close event (should minimize to tray instead of closing)
  Future<bool> handleWindowClose() async {
    try {
      await hideToTray();
      debugPrint(
        "🪟 [WindowManager] Window close intercepted, minimized to tray",
      );
      return false; // Prevent actual window close
    } catch (e) {
      debugPrint("🪟 [WindowManager] Failed to handle window close: $e");
      return true; // Allow close if error occurs
    }
  }

  /// Dispose of the window manager service
  void dispose() {
    debugPrint("🪟 [WindowManager] Window manager service disposed");
  }
}
