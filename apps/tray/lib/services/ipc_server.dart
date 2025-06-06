import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// TCP IPC Server for tray service communication
///
/// Provides TCP socket server for communication with other CloudToLocalLLM apps:
/// - Chat app can send commands (SHOW/HIDE/SETTINGS/QUIT)
/// - Settings app can send configuration updates
/// - Supports JSON protocol for structured communication
/// - Automatic port assignment and port file management
class IPCServer extends ChangeNotifier {
  ServerSocket? _server;
  int? _port;
  String _status = 'Not Started';
  final List<Socket> _clients = [];
  Timer? _heartbeatTimer;

  /// Get current server status
  String get status => _status;

  /// Get server port (null if not started)
  int? get port => _port;

  /// Start the IPC server
  Future<bool> start() async {
    try {
      debugPrint("Starting IPC server...");
      _status = "Starting";
      notifyListeners();

      // Start server on any available port
      _server = await ServerSocket.bind('127.0.0.1', 0);
      _port = _server!.port;

      debugPrint("IPC server started on port $_port");

      // Write port to file for other apps to discover
      await _writePortFile();

      // Listen for client connections
      _server!.listen(_handleClientConnection);

      // Start heartbeat timer
      _startHeartbeat();

      _status = "Running on port $_port";
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint("Failed to start IPC server: $e");
      _status = "Error: $e";
      notifyListeners();
      return false;
    }
  }

  /// Handle new client connection
  void _handleClientConnection(Socket client) {
    debugPrint(
      "New IPC client connected: ${client.remoteAddress}:${client.remotePort}",
    );

    _clients.add(client);

    // Listen for messages from client
    client.listen(
      (data) => _handleClientMessage(client, data),
      onError: (error) {
        debugPrint("Client error: $error");
        _removeClient(client);
      },
      onDone: () {
        debugPrint("Client disconnected");
        _removeClient(client);
      },
    );

    // Send welcome message
    _sendToClient(client, {
      'type': 'welcome',
      'message': 'Connected to CloudToLocalLLM Tray Service',
      'version': '3.3.0',
    });
  }

  /// Handle message from client
  void _handleClientMessage(Socket client, List<int> data) {
    try {
      final message = utf8.decode(data).trim();
      if (message.isEmpty) return;

      final json = jsonDecode(message);
      final command = json['command'] as String?;

      debugPrint("Received IPC command: $command");

      switch (command) {
        case 'PING':
          _sendToClient(client, {
            'type': 'pong',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          break;
        case 'GET_STATUS':
          _sendToClient(client, {
            'type': 'status',
            'server_status': _status,
            'port': _port,
            'clients': _clients.length,
          });
          break;
        case 'UPDATE_AUTH_STATUS':
          final isAuthenticated = json['authenticated'] as bool? ?? false;
          debugPrint("Received auth status update: $isAuthenticated");
          // This would be handled by the tray service
          break;
        case 'UPDATE_CONNECTION_STATE':
          final state = json['state'] as String? ?? 'idle';
          debugPrint("Received connection state update: $state");
          // This would be handled by the tray service
          break;
        default:
          debugPrint("Unknown IPC command: $command");
          _sendToClient(client, {
            'type': 'error',
            'message': 'Unknown command: $command',
          });
      }
    } catch (e) {
      debugPrint("Failed to handle client message: $e");
      _sendToClient(client, {
        'type': 'error',
        'message': 'Invalid message format',
      });
    }
  }

  /// Send message to specific client
  void _sendToClient(Socket client, Map<String, dynamic> message) {
    try {
      final jsonMessage = '${jsonEncode(message)}\n';
      client.add(utf8.encode(jsonMessage));
    } catch (e) {
      debugPrint("Failed to send message to client: $e");
    }
  }

  /// Send command to all connected clients
  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (_clients.isEmpty) {
      debugPrint("No clients connected to send command: ${command['command']}");
      return;
    }

    for (final client in List.from(_clients)) {
      _sendToClient(client, command);
    }

    debugPrint(
      "Sent command to ${_clients.length} clients: ${command['command']}",
    );
  }

  /// Remove client from list
  void _removeClient(Socket client) {
    _clients.remove(client);
    try {
      client.close();
    } catch (e) {
      debugPrint("Error closing client socket: $e");
    }
  }

  /// Write port number to file for discovery
  Future<void> _writePortFile() async {
    try {
      final portFile = File(_getPortFilePath());

      // Ensure directory exists
      await portFile.parent.create(recursive: true);

      // Write port number
      await portFile.writeAsString(_port.toString());

      debugPrint("Port file written: ${portFile.path}");
    } catch (e) {
      debugPrint("Failed to write port file: $e");
    }
  }

  /// Get the path to the port file
  String _getPortFilePath() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final platform = Platform.operatingSystem;

    String configDir;
    if (platform == 'windows') {
      configDir = path.join(
        Platform.environment['LOCALAPPDATA'] ?? home,
        'CloudToLocalLLM',
      );
    } else if (platform == 'macos') {
      configDir = path.join(
        home,
        'Library',
        'Application Support',
        'CloudToLocalLLM',
      );
    } else {
      configDir = path.join(home, '.cloudtolocalllm');
    }

    return path.join(configDir, 'tray_port');
  }

  /// Start heartbeat timer to keep connections alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendHeartbeat();
    });
  }

  /// Send heartbeat to all clients
  void _sendHeartbeat() {
    if (_clients.isNotEmpty) {
      sendCommand({
        'type': 'heartbeat',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Stop the IPC server
  Future<void> stop() async {
    try {
      debugPrint("Stopping IPC server...");

      _heartbeatTimer?.cancel();

      // Close all client connections
      for (final client in List.from(_clients)) {
        _removeClient(client);
      }
      _clients.clear();

      // Close server
      await _server?.close();
      _server = null;
      _port = null;

      // Remove port file
      try {
        final portFile = File(_getPortFilePath());
        if (await portFile.exists()) {
          await portFile.delete();
        }
      } catch (e) {
        debugPrint("Failed to remove port file: $e");
      }

      _status = "Stopped";
      notifyListeners();

      debugPrint("IPC server stopped");
    } catch (e) {
      debugPrint("Error stopping IPC server: $e");
      _status = "Error stopping: $e";
      notifyListeners();
    }
  }

  /// Cleanup resources
  @override
  Future<void> dispose() async {
    await stop();
    super.dispose();
  }
}
