import 'package:flutter/foundation.dart';
import 'tray_ipc_client.dart';

/// Flutter-only system tray manager using IPC client
///
/// This replaces the Python daemon with a Flutter-only architecture:
/// - Communicates with separate Flutter tray service via TCP IPC
/// - No Python dependencies or external processes
/// - Unified Flutter ecosystem for all components
/// - Simplified deployment and maintenance
/// - Better integration with Flutter app lifecycle
class SystemTrayManager {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;
  SystemTrayManager._internal();

  // IPC client for communicating with tray service
  late TrayIPCClient _ipcClient;
  bool _isInitialized = false;

  /// Check if system tray is supported on this platform
  bool get isSupported => !kIsWeb && _isDesktopPlatform();

  /// Check if system tray is initialized and running
  bool get isInitialized => _isInitialized && _ipcClient.isConnected;

  /// Get current tray service status for UI display
  String get status {
    if (!isSupported) return "Not Supported";
    if (!_isInitialized) return "Not Initialized";
    return _ipcClient.status;
  }

  /// Get tray service port
  int? get trayPort => _ipcClient.trayPort;

  /// Initialize the system tray manager with Flutter-only IPC
  Future<bool> initialize({
    Function()? onShowWindow,
    Function()? onHideWindow,
    Function()? onQuit,
    Function()? onSettings,
    Function()? onOllamaTest,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint("Initializing SystemTrayManager with Flutter-only IPC...");

      // Check if platform is supported
      if (!isSupported) {
        debugPrint("System tray not supported on this platform");
        return false;
      }

      // Initialize IPC client
      _ipcClient = TrayIPCClient();

      // Connect to tray service
      final success = await _ipcClient.initialize(
        onShowWindow: onShowWindow,
        onHideWindow: onHideWindow,
        onSettings: () {
          debugPrint("Tray requested: Open settings");
          // Launch settings app
          _launchSettingsApp();
        },
        onQuit: onQuit,
      );

      if (success) {
        _isInitialized = true;
        debugPrint("SystemTrayManager initialized successfully");
        return true;
      } else {
        debugPrint("Failed to connect to tray service");
        return false;
      }
    } catch (e) {
      debugPrint("Failed to initialize SystemTrayManager: $e");
      return false;
    }
  }

  /// Launch the settings app
  Future<void> _launchSettingsApp() async {
    try {
      // TODO: Implement settings app launch
      // This could be done via Process.start or by sending a message to a launcher service
      debugPrint("Settings app launch requested - not yet implemented");
    } catch (e) {
      debugPrint("Failed to launch settings app: $e");
    }
  }

  /// Update the authentication status in tray service
  Future<void> updateAuthenticationStatus(bool isAuthenticated) async {
    if (_isInitialized) {
      await _ipcClient.updateAuthStatus(isAuthenticated);
      debugPrint("Sent auth status to tray service: $isAuthenticated");
    }
  }

  /// Update the connection state in tray service
  Future<void> updateConnectionState(String state) async {
    if (_isInitialized) {
      await _ipcClient.updateConnectionState(state);
      debugPrint("Sent connection state to tray service: $state");
    }
  }

  /// Set tooltip (legacy method - now handled by tray service)
  Future<void> setTooltip(String tooltip) async {
    // Tooltip is now managed by the tray service itself
    debugPrint("Tooltip update requested: $tooltip");
  }

  /// Update icon state (legacy method - now handled by tray service)
  Future<void> updateIconState(String state) async {
    // Icon state is now managed by the tray service based on connection state
    await updateConnectionState(state);
  }

  /// Dispose of the system tray manager
  Future<void> dispose() async {
    try {
      debugPrint("Disposing SystemTrayManager...");

      if (_isInitialized) {
        await _ipcClient.dispose();
      }

      _isInitialized = false;
      debugPrint("SystemTrayManager disposed");
    } catch (e) {
      debugPrint("Error disposing SystemTrayManager: $e");
    }
  }

  /// Check if running on desktop platform
  bool _isDesktopPlatform() {
    return !kIsWeb;
  }
}
