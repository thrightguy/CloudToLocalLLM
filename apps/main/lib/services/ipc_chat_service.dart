import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm_shared/cloudtolocalllm_shared.dart';

/// IPC Chat Service for handling inter-process communication
/// 
/// This service manages communication between the main chat application
/// and other CloudToLocalLLM components (tray daemon, tunnel manager).
class IPCChatService {
  static const String _defaultHost = 'localhost';
  static const int _defaultPort = 8183;
  
  IPCServer? _server;
  bool _isInitialized = false;
  
  // Event callbacks
  VoidCallback? _onShowWindow;
  VoidCallback? _onHideWindow;
  VoidCallback? _onToggleWindow;
  VoidCallback? _onOpenSettings;
  VoidCallback? _onQuit;
  
  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Whether the server is running
  bool get isRunning => _server?.isRunning ?? false;
  
  /// Number of connected clients
  int get clientCount => _server?.clientCount ?? 0;
  
  /// Initialize the IPC service
  Future<bool> initialize({
    VoidCallback? onShowWindow,
    VoidCallback? onHideWindow,
    VoidCallback? onToggleWindow,
    VoidCallback? onOpenSettings,
    VoidCallback? onQuit,
    String host = _defaultHost,
    int port = _defaultPort,
  }) async {
    if (_isInitialized) return true;
    
    try {
      debugPrint('🚀 [IPCChatService] Initializing IPC service on $host:$port...');
      
      // Store callbacks
      _onShowWindow = onShowWindow;
      _onHideWindow = onHideWindow;
      _onToggleWindow = onToggleWindow;
      _onOpenSettings = onOpenSettings;
      _onQuit = onQuit;
      
      // Create and start IPC server
      _server = IPCServer(
        host: host,
        port: port,
        serverId: 'chat_app',
      );
      
      // Listen for incoming messages
      _server!.messageStream.listen(_handleIPCMessage);
      
      // Start the server
      final success = await _server!.start();
      
      if (success) {
        _isInitialized = true;
        debugPrint('✅ [IPCChatService] IPC service initialized successfully');
        return true;
      } else {
        debugPrint('❌ [IPCChatService] Failed to start IPC server');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('💥 [IPCChatService] Initialization failed: $e');
      debugPrint('💥 [IPCChatService] Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Handle incoming IPC messages
  void _handleIPCMessage(IPCMessage message) {
    try {
      debugPrint('📥 [IPCChatService] Received message: ${message.type}');
      
      switch (message.type) {
        case IPCMessageTypes.showWindow:
          _onShowWindow?.call();
          break;
          
        case IPCMessageTypes.hideWindow:
          _onHideWindow?.call();
          break;
          
        case IPCMessageTypes.toggleWindow:
          _onToggleWindow?.call();
          break;
          
        case IPCMessageTypes.openSettings:
          _onOpenSettings?.call();
          break;
          
        case IPCMessageTypes.quit:
          _onQuit?.call();
          break;
          
        default:
          debugPrint('⚠️ [IPCChatService] Unknown message type: ${message.type}');
      }
    } catch (e) {
      debugPrint('💥 [IPCChatService] Error handling message: $e');
    }
  }
  
  /// Send a message to all connected clients
  Future<int> broadcast(IPCMessage message) async {
    if (!_isInitialized || _server == null) {
      debugPrint('❌ [IPCChatService] Cannot broadcast: service not initialized');
      return 0;
    }
    
    return await _server!.broadcast(message);
  }
  
  /// Send a message to a specific client
  Future<bool> sendToClient(String clientId, IPCMessage message) async {
    if (!_isInitialized || _server == null) {
      debugPrint('❌ [IPCChatService] Cannot send: service not initialized');
      return false;
    }
    
    return await _server!.sendToClient(clientId, message);
  }
  
  /// Stop the IPC service
  Future<void> stop() async {
    if (_server != null) {
      debugPrint('🛑 [IPCChatService] Stopping IPC service...');
      await _server!.stop();
      _server = null;
    }
    _isInitialized = false;
  }
  
  /// Dispose of the service
  void dispose() {
    stop();
  }
}

/// IPC Message Types for chat application
class IPCMessageTypes {
  static const String showWindow = 'show_window';
  static const String hideWindow = 'hide_window';
  static const String toggleWindow = 'toggle_window';
  static const String openSettings = 'open_settings';
  static const String quit = 'quit';
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String ack = 'ack';
}
