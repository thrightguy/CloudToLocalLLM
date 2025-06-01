import 'dart:io';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_notifications/desktop_notifications.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';

class TrayService {
  final SystemTray _systemTray = SystemTray();
  late NotificationsClient _notificationsClient;
  
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger.info('Initializing system tray...');
      
      // Initialize notifications
      _notificationsClient = NotificationsClient();
      await _notificationsClient.init(
        appName: AppConfig.notificationAppName,
        appIcon: AppConfig.trayIconPath,
      );
      
      // Initialize system tray
      await _initializeSystemTray();
      
      _isInitialized = true;
      AppLogger.info('System tray initialized successfully');
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize system tray: $e', e, stackTrace);
      rethrow;
    }
  }
  
  Future<void> _initializeSystemTray() async {
    // Set tray icon
    await _systemTray.initSystemTray(
      title: AppConfig.appName,
      iconPath: AppConfig.trayIconPath,
    );
    
    // Create context menu
    await _createContextMenu();
    
    // Set up tray callbacks
    _systemTray.registerSystemTrayEventHandler((eventName) {
      AppLogger.debug('System tray event: $eventName');
      
      if (eventName == kSystemTrayEventClick) {
        _handleTrayClick();
      } else if (eventName == kSystemTrayEventRightClick) {
        _handleTrayRightClick();
      }
    });
  }
  
  Future<void> _createContextMenu() async {
    final menu = Menu();
    
    // Status item (non-clickable)
    await menu.buildFrom([
      MenuItemLabel(
        label: 'CloudToLocalLLM Bridge',
        enabled: false,
      ),
      MenuSeparator(),
      
      // Connection controls
      MenuItemLabel(
        label: 'Connect',
        name: 'connect',
        enabled: true,
      ),
      MenuItemLabel(
        label: 'Disconnect',
        name: 'disconnect',
        enabled: false,
      ),
      MenuSeparator(),
      
      // Authentication controls
      MenuItemLabel(
        label: 'Login',
        name: 'login',
        enabled: true,
      ),
      MenuItemLabel(
        label: 'Logout',
        name: 'logout',
        enabled: false,
      ),
      MenuSeparator(),
      
      // Application controls
      MenuItemLabel(
        label: 'Show Window',
        name: 'show',
        enabled: true,
      ),
      MenuItemLabel(
        label: 'Settings',
        name: 'settings',
        enabled: true,
      ),
      MenuItemLabel(
        label: 'About',
        name: 'about',
        enabled: true,
      ),
      MenuSeparator(),
      
      // Quit
      MenuItemLabel(
        label: 'Quit',
        name: 'quit',
        enabled: true,
      ),
    ]);
    
    await _systemTray.setContextMenu(menu);
  }
  
  void _handleTrayClick() async {
    // Toggle window visibility on tray click
    try {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    } catch (e) {
      AppLogger.error('Failed to toggle window visibility: $e');
    }
  }
  
  void _handleTrayRightClick() {
    // Context menu is automatically shown by the system tray
    AppLogger.debug('Tray right-clicked - context menu should appear');
  }
  
  void showContextMenu() {
    // This method can be called to programmatically show the context menu
    // Implementation depends on the system tray library capabilities
  }
  
  void handleMenuItemClick(MenuItem menuItem) {
    AppLogger.debug('Menu item clicked: ${menuItem.key}');
    
    switch (menuItem.key) {
      case 'connect':
        _handleConnect();
        break;
      case 'disconnect':
        _handleDisconnect();
        break;
      case 'login':
        _handleLogin();
        break;
      case 'logout':
        _handleLogout();
        break;
      case 'show':
        _handleShowWindow();
        break;
      case 'settings':
        _handleSettings();
        break;
      case 'about':
        _handleAbout();
        break;
      case 'quit':
        _handleQuit();
        break;
      default:
        AppLogger.warning('Unknown menu item: ${menuItem.key}');
    }
  }
  
  void _handleConnect() {
    AppLogger.info('User requested connection via tray menu');
    // TODO: Implement connection logic
    showNotification('Connecting...', 'Attempting to connect to cloud relay');
  }
  
  void _handleDisconnect() {
    AppLogger.info('User requested disconnection via tray menu');
    // TODO: Implement disconnection logic
    showNotification('Disconnected', 'Disconnected from cloud relay');
  }
  
  void _handleLogin() {
    AppLogger.info('User requested login via tray menu');
    // TODO: Implement login logic
  }
  
  void _handleLogout() {
    AppLogger.info('User requested logout via tray menu');
    // TODO: Implement logout logic
    showNotification('Logged Out', 'Successfully logged out');
  }
  
  void _handleShowWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      AppLogger.error('Failed to show window: $e');
    }
  }
  
  void _handleSettings() {
    AppLogger.info('User requested settings via tray menu');
    // TODO: Implement settings dialog
    showNotification('Settings', 'Settings functionality coming soon');
  }
  
  void _handleAbout() {
    AppLogger.info('User requested about via tray menu');
    
    final aboutText = '''
${AppConfig.appName} v${AppConfig.appVersion}

${AppConfig.appDescription}

Features:
• Secure Auth0 authentication
• WebSocket tunnel to cloud relay
• System tray integration
• Automatic reconnection

Visit: ${AppConfig.homepageUrl}
    ''';
    
    showNotification('About ${AppConfig.appName}', aboutText);
  }
  
  void _handleQuit() async {
    AppLogger.info('User requested quit via tray menu');
    
    try {
      // Clean shutdown
      await dispose();
      exit(0);
    } catch (e) {
      AppLogger.error('Error during shutdown: $e');
      exit(1);
    }
  }
  
  Future<void> updateTrayIcon(String iconPath) async {
    if (!_isInitialized) return;
    
    try {
      await _systemTray.setImage(iconPath);
      AppLogger.debug('Tray icon updated: $iconPath');
    } catch (e) {
      AppLogger.error('Failed to update tray icon: $e');
    }
  }
  
  Future<void> updateTrayTooltip(String tooltip) async {
    if (!_isInitialized) return;
    
    try {
      await _systemTray.setToolTip(tooltip);
      AppLogger.debug('Tray tooltip updated: $tooltip');
    } catch (e) {
      AppLogger.error('Failed to update tray tooltip: $e');
    }
  }
  
  Future<void> showNotification(String title, String message, {
    String? iconPath,
    Duration? timeout,
  }) async {
    try {
      await _notificationsClient.notify(
        title,
        body: message,
        appIcon: iconPath ?? AppConfig.trayIconPath,
        timeout: timeout ?? AppConfig.notificationDuration,
      );
      
      AppLogger.debug('Notification shown: $title');
    } catch (e) {
      AppLogger.error('Failed to show notification: $e');
    }
  }
  
  Future<void> updateConnectionStatus(bool isConnected) async {
    if (!_isInitialized) return;
    
    final iconPath = isConnected 
        ? AppConfig.trayIconConnectedPath 
        : AppConfig.trayIconDisconnectedPath;
    
    final tooltip = isConnected 
        ? '${AppConfig.appName} - Connected'
        : '${AppConfig.appName} - Disconnected';
    
    await updateTrayIcon(iconPath);
    await updateTrayTooltip(tooltip);
    
    // Update menu items based on connection status
    await _updateMenuItems(isConnected);
  }
  
  Future<void> _updateMenuItems(bool isConnected) async {
    // TODO: Update menu item states based on connection status
    // This would require rebuilding the context menu with updated states
  }
  
  Future<void> updateAuthStatus(bool isAuthenticated) async {
    if (!_isInitialized) return;
    
    // TODO: Update menu item states based on authentication status
    await _updateMenuItems(isAuthenticated);
  }
  
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      AppLogger.info('Disposing system tray...');
      await _systemTray.destroy();
      _isInitialized = false;
      AppLogger.info('System tray disposed');
    } catch (e) {
      AppLogger.error('Error disposing system tray: $e');
    }
  }
}
