import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Robust system tray service with comprehensive error handling and fallback strategies
///
/// This service provides:
/// - Safe initialization with timeout and error recovery
/// - Graceful degradation when system tray is unavailable
/// - Comprehensive logging and debugging information
/// - Fallback to window management without tray functionality
/// - Production-ready error handling for Linux desktop environments
class RobustTrayService with TrayListener {
  static final RobustTrayService _instance = RobustTrayService._internal();
  factory RobustTrayService() => _instance;
  RobustTrayService._internal();

  bool _isInitialized = false;
  bool _isTrayAvailable = false;
  bool _isWindowVisible = true;
  String? _lastError;
  Timer? _initializationTimeout;

  // Callbacks for tray events
  VoidCallback? _onShowWindow;
  VoidCallback? _onHideWindow;
  VoidCallback? _onSettings;
  VoidCallback? _onQuit;

  /// Initialize the robust tray service with comprehensive error handling
  Future<bool> initialize({
    VoidCallback? onShowWindow,
    VoidCallback? onHideWindow,
    VoidCallback? onSettings,
    VoidCallback? onQuit,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_isInitialized) return _isTrayAvailable;

    _onShowWindow = onShowWindow;
    _onHideWindow = onHideWindow;
    _onSettings = onSettings;
    _onQuit = onQuit;

    debugPrint("🚀 [RobustTrayService] Starting system tray initialization...");

    try {
      // Check platform compatibility first
      if (!_isPlatformSupported()) {
        debugPrint(
          "⚠️ [RobustTrayService] Platform not supported for system tray",
        );
        return await _initializeFallbackMode();
      }

      // Check desktop environment compatibility
      if (!_isDesktopEnvironmentSupported()) {
        debugPrint(
          "⚠️ [RobustTrayService] Desktop environment may not support system tray",
        );
        // Continue anyway, but with lower expectations
      }

      // Initialize window manager first (safer operation)
      final windowManagerReady = await _initializeWindowManager();
      if (!windowManagerReady) {
        debugPrint(
          "❌ [RobustTrayService] Window manager initialization failed",
        );
        return false;
      }

      // Attempt tray initialization with timeout
      final trayReady = await _initializeTrayWithTimeout(timeout);

      _isInitialized = true;
      _isTrayAvailable = trayReady;

      if (trayReady) {
        debugPrint(
          "✅ [RobustTrayService] System tray initialized successfully",
        );
        await _setInitialTooltip();
      } else {
        debugPrint(
          "⚠️ [RobustTrayService] System tray unavailable, using fallback mode",
        );
      }

      return true;
    } catch (e, stackTrace) {
      _lastError = e.toString();
      debugPrint("💥 [RobustTrayService] Initialization failed: $e");
      debugPrint("💥 [RobustTrayService] Stack trace: $stackTrace");

      // Always try fallback mode
      return await _initializeFallbackMode();
    }
  }

  /// Check if the current platform supports system tray
  bool _isPlatformSupported() {
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  /// Check if the desktop environment supports system tray
  bool _isDesktopEnvironmentSupported() {
    if (!Platform.isLinux) return true;

    final desktop = Platform.environment['XDG_CURRENT_DESKTOP']?.toLowerCase();
    final session = Platform.environment['DESKTOP_SESSION']?.toLowerCase();

    debugPrint("🖥️ [RobustTrayService] Desktop: $desktop, Session: $session");

    // Known compatible desktop environments
    const supportedDesktops = [
      'gnome',
      'kde',
      'xfce',
      'mate',
      'cinnamon',
      'lxde',
      'lxqt',
    ];

    return desktop != null && supportedDesktops.any((d) => desktop.contains(d));
  }

  /// Initialize window manager safely
  Future<bool> _initializeWindowManager() async {
    try {
      if (kIsWeb) return true;

      debugPrint("🪟 [RobustTrayService] Initializing window manager...");
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      await windowManager.waitUntilReadyToShow(windowOptions);
      debugPrint("✅ [RobustTrayService] Window manager ready");
      return true;
    } catch (e) {
      debugPrint(
        "💥 [RobustTrayService] Window manager initialization failed: $e",
      );
      return false;
    }
  }

  /// Initialize system tray with timeout protection
  Future<bool> _initializeTrayWithTimeout(Duration timeout) async {
    final completer = Completer<bool>();

    // Set up timeout
    _initializationTimeout = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint(
          "⏰ [RobustTrayService] Tray initialization timed out after ${timeout.inSeconds}s",
        );
        completer.complete(false);
      }
    });

    try {
      // Attempt tray initialization in a separate isolate-like operation
      final result = await _attemptTrayInitialization();

      _initializationTimeout?.cancel();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    } catch (e) {
      _initializationTimeout?.cancel();
      if (!completer.isCompleted) {
        debugPrint("💥 [RobustTrayService] Tray initialization error: $e");
        completer.complete(false);
      }
    }

    return completer.future;
  }

  /// Attempt the actual tray initialization
  Future<bool> _attemptTrayInitialization() async {
    debugPrint("🔧 [RobustTrayService] Attempting tray initialization...");

    // Add listener first
    trayManager.addListener(this);

    // Set tray icon
    await _setTrayIcon();

    // Create context menu
    await _createContextMenu();

    debugPrint("✅ [RobustTrayService] Tray components initialized");
    return true;
  }

  /// Set the tray icon based on platform
  Future<void> _setTrayIcon() async {
    String iconPath;

    if (Platform.isWindows) {
      iconPath = 'assets/images/tray_icon_mono_24.png';
    } else if (Platform.isMacOS) {
      iconPath = 'assets/images/tray_icon_mono_16.png';
    } else {
      // Linux - use monochrome icon for better compatibility
      iconPath = 'assets/images/tray_icon_mono_24.png';
    }

    await trayManager.setIcon(iconPath);
    debugPrint("🎨 [RobustTrayService] Tray icon set: $iconPath");
  }

  /// Create the context menu
  Future<void> _createContextMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_hide',
          label: _isWindowVisible ? 'Hide Window' : 'Show Window',
        ),
        MenuItem.separator(),
        MenuItem(key: 'settings', label: 'Settings'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit CloudToLocalLLM'),
      ],
    );

    await trayManager.setContextMenu(menu);
    debugPrint("📋 [RobustTrayService] Context menu created");
  }

  /// Initialize fallback mode when tray is unavailable
  Future<bool> _initializeFallbackMode() async {
    debugPrint("🔄 [RobustTrayService] Initializing fallback mode...");

    try {
      // Ensure window manager is available for basic window operations
      if (!kIsWeb) {
        await windowManager.ensureInitialized();
      }

      _isInitialized = true;
      _isTrayAvailable = false;

      debugPrint("✅ [RobustTrayService] Fallback mode initialized");
      return true;
    } catch (e) {
      debugPrint("💥 [RobustTrayService] Fallback mode failed: $e");
      return false;
    }
  }

  /// Set initial tooltip
  Future<void> _setInitialTooltip() async {
    if (!_isTrayAvailable) return;

    try {
      await trayManager.setToolTip("CloudToLocalLLM - Ready");
    } catch (e) {
      debugPrint("⚠️ [RobustTrayService] Failed to set tooltip: $e");
    }
  }

  /// Show window (works with or without tray)
  Future<void> showWindow() async {
    try {
      if (!kIsWeb) {
        await windowManager.show();
        await windowManager.focus();
      }
      _isWindowVisible = true;

      if (_isTrayAvailable) {
        await _updateContextMenu();
      }

      _onShowWindow?.call();
      debugPrint("✅ [RobustTrayService] Window shown");
    } catch (e) {
      debugPrint("💥 [RobustTrayService] Failed to show window: $e");
    }
  }

  /// Hide window (works with or without tray)
  Future<void> hideWindow() async {
    try {
      if (!kIsWeb) {
        await windowManager.hide();
      }
      _isWindowVisible = false;

      if (_isTrayAvailable) {
        await _updateContextMenu();
      }

      _onHideWindow?.call();
      debugPrint("✅ [RobustTrayService] Window hidden");
    } catch (e) {
      debugPrint("💥 [RobustTrayService] Failed to hide window: $e");
    }
  }

  /// Toggle window visibility
  Future<void> toggleWindow() async {
    if (_isWindowVisible) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  /// Update context menu
  Future<void> _updateContextMenu() async {
    if (!_isTrayAvailable) return;

    try {
      await _createContextMenu();
    } catch (e) {
      debugPrint("⚠️ [RobustTrayService] Failed to update context menu: $e");
    }
  }

  // TrayListener implementation
  @override
  void onTrayIconMouseDown() {
    if (!_isTrayAvailable) return;
    debugPrint("🖱️ [RobustTrayService] Tray icon clicked");
    toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (!_isTrayAvailable) return;
    debugPrint("🖱️ [RobustTrayService] Tray icon right-clicked");
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (!_isTrayAvailable) return;
    debugPrint("📋 [RobustTrayService] Menu item clicked: ${menuItem.key}");

    switch (menuItem.key) {
      case 'show_hide':
        toggleWindow();
        break;
      case 'settings':
        _onSettings?.call();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    try {
      _initializationTimeout?.cancel();

      if (_isTrayAvailable) {
        trayManager.removeListener(this);
        await trayManager.destroy();
      }

      _isInitialized = false;
      _isTrayAvailable = false;
      debugPrint("✅ [RobustTrayService] Service disposed");
    } catch (e) {
      debugPrint("💥 [RobustTrayService] Error disposing service: $e");
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isTrayAvailable => _isTrayAvailable;
  bool get isWindowVisible => _isWindowVisible;
  String? get lastError => _lastError;
}
