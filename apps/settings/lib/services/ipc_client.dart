import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// TCP IPC Client for communicating with tray service
///
/// Provides TCP socket client for communication with CloudToLocalLLM tray service:
/// - Connects to tray service via TCP socket
/// - Sends commands and configuration updates
/// - Receives status updates and notifications
/// - Automatic reconnection on connection loss
class IPCClient extends ChangeNotifier {
  Socket? _socket;
  int? _trayPort;
  String _status = 'Disconnected';
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// Get current connection status
  String get status => _status;

  /// Check if connected to tray service
  bool get isConnected => _isConnected;

  /// Get tray service port
  int? get trayPort => _trayPort;

  /// Connect to tray service
  Future<bool> connectToTray() async {
    try {
      debugPrint("Attempting to connect to tray service...");
      _status = "Connecting";
      notifyListeners();

      // Read tray port from file
      _trayPort = await _readTrayPort();
      if (_trayPort == null) {
        debugPrint("Tray service port not found");
        _status = "Tray service not running";
        notifyListeners();
        return false;
      }

      // Connect to tray service
      _socket = await Socket.connect('127.0.0.1', _trayPort!)
          .timeout(_connectionTimeout);

      // Listen for messages from tray service
      _socket!.listen(
        _handleTrayMessage,
        onError: (error) {
          debugPrint("Tray connection error: $error");
          _handleConnectionLost();
        },
        onDone: () {
          debugPrint("Tray connection closed");
          _handleConnectionLost();
        },
      );

      _isConnected = true;
      _status = "Connected to tray service";
      _reconnectAttempts = 0;
      notifyListeners();

      // Start heartbeat
      _startHeartbeat();

      debugPrint("Connected to tray service on port $_trayPort");
      return true;
    } catch (e) {
      debugPrint("Failed to connect to tray service: $e");
      _status = "Connection failed: $e";
      _isConnected = false;
      notifyListeners();
      
      // Schedule reconnection attempt
      _scheduleReconnect();
      return false;
    }
  }

  /// Handle messages from tray service
  void _handleTrayMessage(List<int> data) {
    try {
      final message = utf8.decode(data).trim();
      if (message.isEmpty) return;

      final json = jsonDecode(message);
      final type = json['type'] as String?;

      debugPrint("Received from tray: $type");

      switch (type) {
        case 'welcome':
          debugPrint("Tray service welcome: ${json['message']}");
          break;
        case 'pong':
          // Heartbeat response
          break;
        case 'heartbeat':
          // Tray service heartbeat
          _sendCommand({'command': 'PING'});
          break;
        case 'status':
          debugPrint("Tray status: ${json['server_status']}");
          break;
        case 'error':
          debugPrint("Tray error: ${json['message']}");
          break;
        default:
          debugPrint("Unknown message type from tray: $type");
      }
    } catch (e) {
      debugPrint("Failed to handle tray message: $e");
    }
  }

  /// Send command to tray service
  Future<bool> _sendCommand(Map<String, dynamic> command) async {
    if (!_isConnected || _socket == null) {
      debugPrint("Cannot send command: not connected to tray service");
      return false;
    }

    try {
      final message = '${jsonEncode(command)}\n';
      _socket!.add(utf8.encode(message));
      return true;
    } catch (e) {
      debugPrint("Failed to send command to tray: $e");
      _handleConnectionLost();
      return false;
    }
  }

  /// Update authentication status in tray service
  Future<void> updateAuthStatus(bool isAuthenticated) async {
    await _sendCommand({
      'command': 'UPDATE_AUTH_STATUS',
      'authenticated': isAuthenticated,
    });
  }

  /// Update connection state in tray service
  Future<void> updateConnectionState(String state) async {
    await _sendCommand({
      'command': 'UPDATE_CONNECTION_STATE',
      'state': state, // idle, connected, error
    });
  }

  /// Request tray service status
  Future<void> requestStatus() async {
    await _sendCommand({'command': 'GET_STATUS'});
  }

  /// Send ping to tray service
  Future<void> ping() async {
    await _sendCommand({'command': 'PING'});
  }

  /// Read tray port from file
  Future<int?> _readTrayPort() async {
    try {
      final portFile = File(_getPortFilePath());

      if (!await portFile.exists()) {
        debugPrint("Tray port file not found: ${portFile.path}");
        return null;
      }

      final portStr = await portFile.readAsString();
      final port = int.tryParse(portStr.trim());
      
      if (port == null || port <= 0) {
        debugPrint("Invalid port in tray port file: $portStr");
        return null;
      }

      return port;
    } catch (e) {
      debugPrint("Failed to read tray port: $e");
      return null;
    }
  }

  /// Get the path to the tray port file
  String _getPortFilePath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final platform = Platform.operatingSystem;

    String configDir;
    if (platform == 'windows') {
      configDir = path.join(
          Platform.environment['LOCALAPPDATA'] ?? home, 'CloudToLocalLLM');
    } else if (platform == 'macos') {
      configDir =
          path.join(home, 'Library', 'Application Support', 'CloudToLocalLLM');
    } else {
      configDir = path.join(home, '.cloudtolocalllm');
    }

    return path.join(configDir, 'tray_port');
  }

  /// Handle connection lost
  void _handleConnectionLost() {
    _isConnected = false;
    _socket?.close();
    _socket = null;
    _heartbeatTimer?.cancel();
    
    _status = "Connection lost";
    notifyListeners();

    // Schedule reconnection
    _scheduleReconnect();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint("Max reconnection attempts reached");
      _status = "Tray service unavailable";
      notifyListeners();
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      _reconnectAttempts++;
      debugPrint("Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts");
      await connectToTray();
    });
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      ping();
    });
  }

  /// Disconnect from tray service
  Future<void> disconnect() async {
    try {
      debugPrint("Disconnecting from tray service...");
      
      _reconnectTimer?.cancel();
      _heartbeatTimer?.cancel();
      
      _socket?.close();
      _socket = null;
      _isConnected = false;
      _trayPort = null;
      _reconnectAttempts = 0;
      
      _status = "Disconnected";
      notifyListeners();

      debugPrint("Disconnected from tray service");
    } catch (e) {
      debugPrint("Error disconnecting from tray service: $e");
    }
  }

  /// Cleanup resources
  @override
  Future<void> dispose() async {
    await disconnect();
    super.dispose();
  }
}
