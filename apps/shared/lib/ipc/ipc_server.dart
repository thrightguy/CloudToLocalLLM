import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ipc_message.dart';

/// IPC Server for receiving connections from other CloudToLocalLLM applications
///
/// Provides reliable TCP socket server with client management,
/// message broadcasting, and comprehensive error handling.
class IPCServer {
  final String host;
  final int port;
  final String serverId;

  ServerSocket? _serverSocket;
  bool _isRunning = false;
  final Map<String, Socket> _clients = {};
  final StreamController<IPCMessage> _messageController =
      StreamController.broadcast();

  /// Stream of incoming messages from all clients
  Stream<IPCMessage> get messageStream => _messageController.stream;

  /// Whether the server is currently running
  bool get isRunning => _isRunning;

  /// Number of connected clients
  int get clientCount => _clients.length;

  IPCServer({required this.host, required this.port, required this.serverId});

  /// Start the IPC server
  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      debugPrint('🚀 [IPCServer:$serverId] Starting server on $host:$port...');

      _serverSocket = await ServerSocket.bind(host, port);
      _isRunning = true;

      debugPrint('✅ [IPCServer:$serverId] Server started on $host:$port');

      // Listen for client connections
      _serverSocket!.listen(
        _handleClientConnection,
        onError: _handleServerError,
        onDone: _handleServerDone,
      );

      return true;
    } catch (e) {
      debugPrint('💥 [IPCServer:$serverId] Failed to start server: $e');
      return false;
    }
  }

  /// Stop the IPC server
  Future<void> stop() async {
    if (!_isRunning) return;

    debugPrint('🛑 [IPCServer:$serverId] Stopping server...');

    // Close all client connections
    for (final client in _clients.values) {
      await client.close();
    }
    _clients.clear();

    // Close server socket
    await _serverSocket?.close();
    _serverSocket = null;
    _isRunning = false;

    debugPrint('✅ [IPCServer:$serverId] Server stopped');
  }

  /// Send a message to a specific client
  Future<bool> sendToClient(String clientId, IPCMessage message) async {
    final client = _clients[clientId];
    if (client == null) {
      debugPrint('❌ [IPCServer:$serverId] Client $clientId not found');
      return false;
    }

    try {
      final messageJson = message.toJsonString();
      client.write('$messageJson\n');
      debugPrint('📤 [IPCServer:$serverId] Sent to $clientId: ${message.type}');
      return true;
    } catch (e) {
      debugPrint('💥 [IPCServer:$serverId] Failed to send to $clientId: $e');
      _removeClient(clientId);
      return false;
    }
  }

  /// Broadcast a message to all connected clients
  Future<int> broadcast(IPCMessage message) async {
    int successCount = 0;
    final clientIds = List<String>.from(_clients.keys);

    for (final clientId in clientIds) {
      if (await sendToClient(clientId, message)) {
        successCount++;
      }
    }

    debugPrint(
      '📡 [IPCServer:$serverId] Broadcast ${message.type} to $successCount/${clientIds.length} clients',
    );
    return successCount;
  }

  /// Send a response to a specific message
  Future<bool> sendResponse(
    IPCMessage originalMessage,
    String responseType,
    Map<String, dynamic> responsePayload,
  ) async {
    if (originalMessage.source == null) {
      debugPrint(
        '❌ [IPCServer:$serverId] Cannot respond - no source in original message',
      );
      return false;
    }

    final response = originalMessage.createResponse(
      responseType: responseType,
      responsePayload: responsePayload,
    );

    return await sendToClient(originalMessage.source!, response);
  }

  /// Handle new client connections
  void _handleClientConnection(Socket client) {
    final clientAddress =
        '${client.remoteAddress.address}:${client.remotePort}';
    final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';

    debugPrint(
      '🔌 [IPCServer:$serverId] New client connected: $clientAddress ($clientId)',
    );

    _clients[clientId] = client;

    // Set up client listeners
    client.listen(
      (data) => _handleClientData(clientId, data),
      onError: (error) => _handleClientError(clientId, error),
      onDone: () => _handleClientDisconnected(clientId),
    );

    // Send welcome message
    final welcomeMessage = IPCMessage(
      type: 'welcome',
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      payload: {'server_id': serverId, 'client_id': clientId},
      source: serverId,
      target: clientId,
    );

    sendToClient(clientId, welcomeMessage);
  }

  /// Handle data from a client
  void _handleClientData(String clientId, List<int> data) {
    try {
      final message = utf8.decode(data).trim();
      if (message.isEmpty) return;

      final ipcMessage = IPCMessage.fromJsonString(message);
      debugPrint(
        '📥 [IPCServer:$serverId] Received from $clientId: ${ipcMessage.type}',
      );

      // Update message source if not set
      final updatedMessage = IPCMessage(
        type: ipcMessage.type,
        id: ipcMessage.id,
        timestamp: ipcMessage.timestamp,
        payload: ipcMessage.payload,
        ackRequired: ipcMessage.ackRequired,
        source: ipcMessage.source ?? clientId,
        target: ipcMessage.target,
      );

      // Handle ping messages
      if (ipcMessage.type == IPCMessageTypes.ping) {
        final pong = ipcMessage.createResponse(
          responseType: IPCMessageTypes.pong,
          responsePayload: {'timestamp': DateTime.now().toIso8601String()},
        );
        sendToClient(clientId, pong);
      }

      // Broadcast message to listeners
      _messageController.add(updatedMessage);

      // Send acknowledgment if required
      if (ipcMessage.ackRequired && ipcMessage.type != IPCMessageTypes.ping) {
        final ack = ipcMessage.createAck();
        sendToClient(clientId, ack);
      }
    } catch (e) {
      debugPrint(
        '💥 [IPCServer:$serverId] Message parse error from $clientId: $e',
      );
    }
  }

  /// Handle client errors
  void _handleClientError(String clientId, error) {
    debugPrint('💥 [IPCServer:$serverId] Client $clientId error: $error');
    _removeClient(clientId);
  }

  /// Handle client disconnection
  void _handleClientDisconnected(String clientId) {
    debugPrint('🔌 [IPCServer:$serverId] Client $clientId disconnected');
    _removeClient(clientId);
  }

  /// Remove a client from the server
  void _removeClient(String clientId) {
    final client = _clients.remove(clientId);
    if (client != null) {
      client.close().catchError((e) {
        debugPrint(
          '💥 [IPCServer:$serverId] Error closing client $clientId: $e',
        );
      });
    }
  }

  /// Handle server errors
  void _handleServerError(Object error) {
    debugPrint('💥 [IPCServer:$serverId] Server error: $error');
  }

  /// Handle server shutdown
  void _handleServerDone() {
    debugPrint('🛑 [IPCServer:$serverId] Server socket closed');
    _isRunning = false;
  }

  /// Get list of connected client IDs
  List<String> getConnectedClients() {
    return List<String>.from(_clients.keys);
  }

  /// Check if a specific client is connected
  bool isClientConnected(String clientId) {
    return _clients.containsKey(clientId);
  }

  /// Dispose the server and clean up resources
  Future<void> dispose() async {
    await stop();
    await _messageController.close();
  }
}
