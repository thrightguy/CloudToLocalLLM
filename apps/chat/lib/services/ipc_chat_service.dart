import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm_shared/cloudtolocalllm_shared.dart';

/// IPC service for the Chat application
/// 
/// Handles communication with the Tunnel and Tray applications
/// through TCP socket connections with comprehensive error handling.
class IPCChatService {
  late final AppLogger _logger;
  late final IPCServer _ipcServer;
  IPCClient? _tunnelClient;

  bool _isInitialized = false;
  StreamSubscription? _messageSubscription;

  // Callbacks for tray events
  VoidCallback? _onShowWindow;
  VoidCallback? _onHideWindow;
  VoidCallback? _onToggleWindow;
  VoidCallback? _onOpenSettings;
  VoidCallback? _onQuit;

  IPCChatService() {
    _logger = AppLogger('chat_ipc');
  }

  /// Initialize the IPC service
  Future<bool> initialize({
    VoidCallback? onShowWindow,
    VoidCallback? onHideWindow,
    VoidCallback? onToggleWindow,
    VoidCallback? onOpenSettings,
    VoidCallback? onQuit,
  }) async {
    if (_isInitialized) return true;

    _onShowWindow = onShowWindow;
    _onHideWindow = onHideWindow;
    _onToggleWindow = onToggleWindow;
    _onOpenSettings = onOpenSettings;
    _onQuit = onQuit;

    try {
      _logger.info('Initializing IPC Chat Service...');

      // Start IPC server for receiving commands from tray
      await _startIPCServer();

      // Connect to tunnel service
      await _connectToTunnel();

      _isInitialized = true;
      _logger.info('IPC Chat Service initialized successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize IPC Chat Service', e, stackTrace);
      return false;
    }
  }

  /// Start the IPC server for receiving commands from tray
  Future<void> _startIPCServer() async {
    _ipcServer = IPCServer(
      host: AppConfig.ipcHost,
      port: AppConfig.trayChatPort,
      serverId: IPCApplications.chat,
    );

    final started = await _ipcServer.start();
    if (!started) {
      throw Exception('Failed to start IPC server on port ${AppConfig.trayChatPort}');
    }

    // Listen for incoming messages
    _messageSubscription = _ipcServer.messageStream.listen(_handleIPCMessage);
    _logger.info('IPC server started on port ${AppConfig.trayChatPort}');
  }

  /// Connect to the tunnel service
  Future<void> _connectToTunnel() async {
    _tunnelClient = IPCClient(
      host: AppConfig.ipcHost,
      port: AppConfig.chatTunnelPort,
      clientId: IPCApplications.chat,
    );

    final connected = await _tunnelClient!.connect();
    if (connected) {
      _logger.info('Connected to tunnel service on port ${AppConfig.chatTunnelPort}');
    } else {
      _logger.warning('Failed to connect to tunnel service - will use direct Ollama connection');
    }
  }

  /// Handle incoming IPC messages
  void _handleIPCMessage(IPCMessage message) {
    _logger.debug('Received IPC message: ${message.type} from ${message.source}');

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
      
      case IPCMessageTypes.quitApplication:
        _onQuit?.call();
        break;
      
      case IPCMessageTypes.ping:
        _handlePing(message);
        break;
      
      default:
        _logger.warning('Unknown IPC message type: ${message.type}');
    }
  }

  /// Handle ping messages
  void _handlePing(IPCMessage message) {
    final pong = message.createResponse(
      responseType: IPCMessageTypes.pong,
      responsePayload: {
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'healthy',
      },
    );

    _ipcServer.sendToClient(message.source!, pong);
  }

  /// Send a stream request to the tunnel service
  Future<Stream<String>?> requestStream({
    required String model,
    required String message,
    List<Map<String, String>>? history,
  }) async {
    if (_tunnelClient == null || !_tunnelClient!.isConnected) {
      _logger.warning('Tunnel service not available - cannot stream');
      return null;
    }

    try {
      final streamRequest = IPCMessageFactory.createStreamRequest(
        model: model,
        message: message,
        history: history,
        source: IPCApplications.chat,
      );

      _logger.info('Sending stream request for model: $model');
      
      // Send the request
      await _tunnelClient!.sendMessage(streamRequest);

      // Return a stream that listens for stream responses
      return _tunnelClient!.messageStream
          .where((msg) => msg.type == IPCMessageTypes.streamResponse)
          .map((msg) => msg.payload['chunk'] as String? ?? '');
    } catch (e, stackTrace) {
      _logger.error('Failed to request stream from tunnel', e, stackTrace);
      return null;
    }
  }

  /// Check if tunnel service is available
  bool get isTunnelAvailable => _tunnelClient?.isConnected ?? false;

  /// Get tunnel service health status
  Future<bool> checkTunnelHealth() async {
    if (_tunnelClient == null || !_tunnelClient!.isConnected) {
      return false;
    }

    try {
      return await _tunnelClient!.ping(timeout: const Duration(seconds: 5));
    } catch (e) {
      _logger.warning('Tunnel health check failed: $e');
      return false;
    }
  }

  /// Send a health status update to tray
  Future<void> sendHealthStatus({
    required bool isHealthy,
    String? error,
  }) async {
    try {
      final statusMessage = IPCMessage(
        type: IPCMessageTypes.serviceStatus,
        id: 'health_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        payload: {
          'service': IPCApplications.chat,
          'healthy': isHealthy,
          'timestamp': DateTime.now().toIso8601String(),
          if (error != null) 'error': error,
        },
        source: IPCApplications.chat,
        target: IPCApplications.tray,
      );

      await _ipcServer.broadcast(statusMessage);
    } catch (e) {
      _logger.warning('Failed to send health status: $e');
    }
  }

  /// Dispose the service and clean up resources
  Future<void> dispose() async {
    try {
      _logger.info('Disposing IPC Chat Service...');

      await _messageSubscription?.cancel();
      await _tunnelClient?.dispose();
      await _ipcServer.dispose();

      _isInitialized = false;
      _logger.info('IPC Chat Service disposed');
    } catch (e, stackTrace) {
      _logger.error('Error disposing IPC Chat Service', e, stackTrace);
    }
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the number of connected IPC clients
  int get connectedClients => _ipcServer.clientCount;
}
