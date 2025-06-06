import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ipc_message.dart';

/// IPC Client for communicating with other CloudToLocalLLM applications
///
/// Provides reliable TCP socket communication with automatic reconnection,
/// message acknowledgment, and comprehensive error handling.
class IPCClient {
  final String host;
  final int port;
  final String clientId;
  final Duration connectionTimeout;
  final Duration messageTimeout;
  final int maxReconnectAttempts;

  Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final StreamController<IPCMessage> _messageController =
      StreamController.broadcast();
  final Map<String, Completer<IPCMessage>> _pendingMessages = {};

  /// Stream of incoming messages
  Stream<IPCMessage> get messageStream => _messageController.stream;

  /// Whether the client is currently connected
  bool get isConnected => _isConnected;

  IPCClient({
    required this.host,
    required this.port,
    required this.clientId,
    this.connectionTimeout = const Duration(seconds: 5),
    this.messageTimeout = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
  });

  /// Connect to the IPC server
  Future<bool> connect() async {
    if (_isConnected || _isConnecting) return _isConnected;

    _isConnecting = true;
    debugPrint('🔌 [IPCClient:$clientId] Connecting to $host:$port...');

    try {
      _socket = await Socket.connect(host, port).timeout(connectionTimeout);

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      debugPrint('✅ [IPCClient:$clientId] Connected to $host:$port');

      // Set up socket listeners
      _setupSocketListeners();

      // Start heartbeat
      _startHeartbeat();

      return true;
    } catch (e) {
      _isConnecting = false;
      debugPrint('💥 [IPCClient:$clientId] Connection failed: $e');

      // Schedule reconnection if within retry limits
      if (_reconnectAttempts < maxReconnectAttempts) {
        _scheduleReconnect();
      }

      return false;
    }
  }

  /// Disconnect from the IPC server
  Future<void> disconnect() async {
    debugPrint('🔌 [IPCClient:$clientId] Disconnecting...');

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }

    _isConnected = false;
    _isConnecting = false;

    // Complete any pending messages with error
    for (final completer in _pendingMessages.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Client disconnected'));
      }
    }
    _pendingMessages.clear();

    debugPrint('✅ [IPCClient:$clientId] Disconnected');
  }

  /// Send a message and optionally wait for response
  Future<IPCMessage?> sendMessage(
    IPCMessage message, {
    bool waitForResponse = false,
    Duration? timeout,
  }) async {
    if (!_isConnected) {
      throw Exception('Client not connected');
    }

    final messageJson = message.toJsonString();
    debugPrint('📤 [IPCClient:$clientId] Sending: ${message.type}');

    try {
      _socket!.write('$messageJson\n');

      if (waitForResponse || message.ackRequired) {
        final responseTimeout = timeout ?? messageTimeout;
        final completer = Completer<IPCMessage>();
        _pendingMessages[message.id] = completer;

        // Set up timeout
        Timer(responseTimeout, () {
          if (!completer.isCompleted) {
            _pendingMessages.remove(message.id);
            completer.completeError(
              TimeoutException('Message timeout', responseTimeout),
            );
          }
        });

        return await completer.future;
      }

      return null;
    } catch (e) {
      debugPrint('💥 [IPCClient:$clientId] Send error: $e');
      rethrow;
    }
  }

  /// Send a message without waiting for response
  Future<void> sendMessageAsync(IPCMessage message) async {
    await sendMessage(message, waitForResponse: false);
  }

  /// Send a ping message to test connectivity
  Future<bool> ping({Duration? timeout}) async {
    try {
      final pingMessage = IPCMessageFactory.createPing(
        source: clientId,
        target: 'server',
      );

      final response = await sendMessage(
        pingMessage,
        waitForResponse: true,
        timeout: timeout ?? const Duration(seconds: 5),
      );

      return response?.type == IPCMessageTypes.pong;
    } catch (e) {
      debugPrint('💥 [IPCClient:$clientId] Ping failed: $e');
      return false;
    }
  }

  /// Set up socket event listeners
  void _setupSocketListeners() {
    _socket!.listen(
      _handleSocketData,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
    );
  }

  /// Handle incoming socket data
  void _handleSocketData(List<int> data) {
    try {
      final message = utf8.decode(data).trim();
      if (message.isEmpty) return;

      final ipcMessage = IPCMessage.fromJsonString(message);
      debugPrint('📥 [IPCClient:$clientId] Received: ${ipcMessage.type}');

      // Handle acknowledgments and responses
      if (ipcMessage.type == IPCMessageTypes.ack ||
          _pendingMessages.containsKey(ipcMessage.payload['original_id'])) {
        final originalId = ipcMessage.payload['original_id'] ?? ipcMessage.id;
        final completer = _pendingMessages.remove(originalId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(ipcMessage);
        }
      }

      // Broadcast message to listeners
      _messageController.add(ipcMessage);

      // Send acknowledgment if required
      if (ipcMessage.ackRequired) {
        final ack = ipcMessage.createAck();
        sendMessageAsync(ack);
      }
    } catch (e) {
      debugPrint('💥 [IPCClient:$clientId] Message parse error: $e');
    }
  }

  /// Handle socket errors
  void _handleSocketError(Object error) {
    debugPrint('💥 [IPCClient:$clientId] Socket error: $error');
    _handleDisconnection();
  }

  /// Handle socket disconnection
  void _handleSocketDone() {
    debugPrint('🔌 [IPCClient:$clientId] Socket disconnected');
    _handleDisconnection();
  }

  /// Handle disconnection and attempt reconnection
  void _handleDisconnection() {
    _isConnected = false;
    _heartbeatTimer?.cancel();

    if (_reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      debugPrint('❌ [IPCClient:$clientId] Max reconnection attempts reached');
    }
  }

  /// Schedule automatic reconnection
  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    debugPrint(
      '🔄 [IPCClient:$clientId] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxReconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () async {
      await connect();
    });
  }

  /// Start heartbeat to maintain connection
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_isConnected) {
        final success = await ping();
        if (!success) {
          debugPrint('💔 [IPCClient:$clientId] Heartbeat failed');
          _handleDisconnection();
        }
      }
    });
  }

  /// Dispose the client and clean up resources
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }
}
