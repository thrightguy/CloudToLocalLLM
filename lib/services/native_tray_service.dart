import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'tunnel_manager_service.dart';

/// Native Flutter system tray service for CloudToLocalLLM v3.3.1+
///
/// Replaces the Python-based tray daemon with a pure Flutter implementation
/// using the tray_manager package for cross-platform system tray functionality.
class NativeTrayService with TrayListener {
  static final NativeTrayService _instance = NativeTrayService._internal();
  factory NativeTrayService() => _instance;
  NativeTrayService._internal();

  bool _isInitialized = false;
  bool _isSupported = false;
  TunnelManagerService? _tunnelManager;

  // Callbacks for tray events
  void Function()? _onShowWindow;
  void Function()? _onHideWindow;
  void Function()? _onSettings;
  void Function()? _onQuit;

  /// Check if system tray is supported on this platform
  bool get isSupported => _isSupported;

  /// Check if tray service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the native tray service
  Future<bool> initialize({
    required TunnelManagerService tunnelManager,
    void Function()? onShowWindow,
    void Function()? onHideWindow,
    void Function()? onSettings,
    void Function()? onQuit,
  }) async {
    if (_isInitialized) return true;

    try {
      debugPrint('🖥️ [NativeTray] Initializing native tray service...');

      // Check platform support
      _isSupported = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
      if (!_isSupported) {
        debugPrint(
          '🖥️ [NativeTray] System tray not supported on this platform',
        );
        return false;
      }

      // Store references
      _tunnelManager = tunnelManager;
      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onSettings = onSettings;
      _onQuit = onQuit;

      // Initialize tray manager
      await trayManager.setIcon(
        _getIconPath(TrayConnectionStatus.disconnected),
      );
      await trayManager.setToolTip('CloudToLocalLLM - Disconnected');

      // Set up context menu
      await _updateContextMenu();

      // Add listener for tray events
      trayManager.addListener(this);

      // Listen to tunnel manager status changes
      _tunnelManager!.addListener(_onTunnelStatusChanged);

      _isInitialized = true;
      debugPrint(
        '🖥️ [NativeTray] Native tray service initialized successfully',
      );

      // Update initial status
      _onTunnelStatusChanged();

      return true;
    } catch (e) {
      debugPrint(
        '🖥️ [NativeTray] Failed to initialize native tray service: $e',
      );
      // Don't fail the entire application if tray initialization fails
      return false;
    }
  }

  /// Handle tunnel manager status changes
  void _onTunnelStatusChanged() {
    if (!_isInitialized || _tunnelManager == null) return;

    final status = _tunnelManager!.getTrayConnectionStatus();
    _updateTrayIcon(status);
    _updateTooltip(status);
  }

  /// Update tray icon based on connection status
  Future<void> _updateTrayIcon(TrayConnectionStatus status) async {
    try {
      final iconPath = _getIconPath(status);
      await trayManager.setIcon(iconPath);
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Failed to update tray icon: $e');
    }
  }

  /// Update tooltip based on connection status
  Future<void> _updateTooltip(TrayConnectionStatus status) async {
    try {
      final tooltip = _getTooltipText(status);
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Failed to update tooltip: $e');
    }
  }

  /// Get icon path for connection status
  String _getIconPath(TrayConnectionStatus status) {
    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'assets/images/tray_icon_connected.png';
      case TrayConnectionStatus.partiallyConnected:
        return 'assets/images/tray_icon_partial.png';
      case TrayConnectionStatus.connecting:
        return 'assets/images/tray_icon_connecting.png';
      case TrayConnectionStatus.disconnected:
        return 'assets/images/tray_icon_disconnected.png';
    }
  }

  /// Get tooltip text for connection status
  String _getTooltipText(TrayConnectionStatus status) {
    if (_tunnelManager == null) {
      return 'CloudToLocalLLM - Initializing';
    }

    final connectionStatus = _tunnelManager!.connectionStatus;
    final ollamaStatus = connectionStatus['ollama'];
    final cloudStatus = connectionStatus['cloud'];

    switch (status) {
      case TrayConnectionStatus.allConnected:
        return 'CloudToLocalLLM - All Connected\nOllama: ${ollamaStatus?.endpoint ?? 'Unknown'}\nCloud: ${cloudStatus?.endpoint ?? 'Unknown'}';
      case TrayConnectionStatus.partiallyConnected:
        if (ollamaStatus?.isConnected == true) {
          return 'CloudToLocalLLM - Ollama Connected\nOllama: ${ollamaStatus!.endpoint}\nCloud: Disconnected';
        } else if (cloudStatus?.isConnected == true) {
          return 'CloudToLocalLLM - Cloud Connected\nOllama: Disconnected\nCloud: ${cloudStatus!.endpoint}';
        }
        return 'CloudToLocalLLM - Partially Connected';
      case TrayConnectionStatus.connecting:
        return 'CloudToLocalLLM - Connecting...';
      case TrayConnectionStatus.disconnected:
        return 'CloudToLocalLLM - Disconnected\nOllama: Disconnected\nCloud: Disconnected';
    }
  }

  /// Update context menu
  Future<void> _updateContextMenu() async {
    try {
      final menu = Menu(
        items: [
          MenuItem(key: 'show', label: 'Show CloudToLocalLLM'),
          MenuItem(key: 'hide', label: 'Hide CloudToLocalLLM'),
          MenuItem.separator(),
          MenuItem(key: 'status', label: 'Connection Status'),
          MenuItem(key: 'settings', label: 'Settings'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Failed to update context menu: $e');
    }
  }

  /// Dispose of the tray service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      debugPrint('🖥️ [NativeTray] Disposing native tray service...');

      // Remove listeners
      trayManager.removeListener(this);
      _tunnelManager?.removeListener(_onTunnelStatusChanged);

      // Destroy tray
      await trayManager.destroy();

      _isInitialized = false;
      debugPrint('🖥️ [NativeTray] Native tray service disposed');
    } catch (e) {
      debugPrint('🖥️ [NativeTray] Error disposing native tray service: $e');
    }
  }

  // TrayListener implementation

  @override
  void onTrayIconMouseDown() {
    debugPrint('🖥️ [NativeTray] Tray icon clicked');
    _onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    debugPrint('🖥️ [NativeTray] Tray icon right-clicked');
    // Context menu will be shown automatically
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('🖥️ [NativeTray] Menu item clicked: ${menuItem.key}');

    switch (menuItem.key) {
      case 'show':
        _onShowWindow?.call();
        break;
      case 'hide':
        _onHideWindow?.call();
        break;
      case 'status':
        _showConnectionStatus();
        break;
      case 'settings':
        _showSettings();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }

  /// Show connection status dialog
  void _showConnectionStatus() {
    debugPrint('🖥️ [NativeTray] Showing connection status');
    // This will be handled by the main app through navigation
    _onShowWindow?.call();
    // TODO: Navigate to connection status screen
  }

  /// Show settings interface
  void _showSettings() {
    debugPrint('🖥️ [NativeTray] Showing settings');
    // Bring window to foreground and navigate to settings
    _onShowWindow?.call();
    // The navigation will be handled by the main app
    _onSettings?.call();
  }

  /// Force update of tray status
  Future<void> updateStatus() async {
    if (_isInitialized && _tunnelManager != null) {
      _onTunnelStatusChanged();
    }
  }
}
