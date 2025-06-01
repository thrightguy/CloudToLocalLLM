import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/tunnel_message.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

enum TunnelStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class TunnelService extends ChangeNotifier {
  final AuthService _authService;
  
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  TunnelStatus _status = TunnelStatus.disconnected;
  String? _error;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;
  
  // Statistics
  int _messagesSent = 0;
  int _messagesReceived = 0;
  DateTime? _lastConnected;
  DateTime? _lastMessageTime;
  
  TunnelService(this._authService);
  
  // Getters
  TunnelStatus get status => _status;
  String? get error => _error;
  bool get isConnected => _status == TunnelStatus.connected;
  bool get isConnecting => _status == TunnelStatus.connecting;
  int get messagesSent => _messagesSent;
  int get messagesReceived => _messagesReceived;
  DateTime? get lastConnected => _lastConnected;
  DateTime? get lastMessageTime => _lastMessageTime;
  
  Future<void> initialize() async {
    AppLogger.info('Initializing TunnelService...');
    
    // Listen to auth state changes
    _authService.addListener(_onAuthStateChanged);
    
    // Start connection if authenticated
    if (_authService.isAuthenticated) {
      await connect();
    }
    
    AppLogger.info('TunnelService initialized');
  }
  
  void _onAuthStateChanged() {
    if (_authService.isAuthenticated && _status == TunnelStatus.disconnected) {
      connect();
    } else if (!_authService.isAuthenticated && _status != TunnelStatus.disconnected) {
      disconnect();
    }
  }
  
  Future<void> connect() async {
    if (_status == TunnelStatus.connecting || _status == TunnelStatus.connected) {
      return;
    }
    
    if (!_authService.isAuthenticated) {
      _setError('Not authenticated');
      return;
    }
    
    _setStatus(TunnelStatus.connecting);
    _clearError();
    
    try {
      AppLogger.info('Connecting to cloud relay...');
      
      // Register bridge with cloud service
      await _registerBridge();
      
      // Establish WebSocket connection
      await _establishWebSocketConnection();
      
      _setStatus(TunnelStatus.connected);
      _lastConnected = DateTime.now();
      _reconnectAttempts = 0;
      
      // Start heartbeat
      _startHeartbeat();
      
      AppLogger.info('Connected to cloud relay successfully');
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to connect to cloud relay: $e', e, stackTrace);
      _setError('Connection failed: $e');
      _setStatus(TunnelStatus.error);
      
      // Schedule reconnection
      _scheduleReconnect();
    }
  }
  
  Future<void> disconnect() async {
    AppLogger.info('Disconnecting from cloud relay...');
    
    _shouldReconnect = false;
    _stopHeartbeat();
    _stopReconnectTimer();
    
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    
    _setStatus(TunnelStatus.disconnected);
    AppLogger.info('Disconnected from cloud relay');
  }
  
  Future<void> _registerBridge() async {
    final registerData = {
      'bridge_id': 'flutter-desktop-bridge',
      'version': AppConfig.appVersion,
      'platform': AppConfig.platformName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final response = await http.post(
      Uri.parse(AppConfig.cloudRegisterUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_authService.accessToken}',
      },
      body: jsonEncode(registerData),
    ).timeout(AppConfig.networkTimeout);
    
    if (response.statusCode != 200) {
      throw Exception('Bridge registration failed: ${response.statusCode}');
    }
    
    AppLogger.info('Bridge registered with cloud service');
  }
  
  Future<void> _establishWebSocketConnection() async {
    final wsUri = Uri.parse(AppConfig.cloudWebSocketUrl);
    
    _channel = WebSocketChannel.connect(
      wsUri,
      protocols: ['cloudtolocalllm-bridge'],
    );
    
    // Add authorization header if possible
    // Note: WebSocket headers are limited, so we'll send auth in first message
    
    // Listen to messages
    _channel!.stream.listen(
      _onWebSocketMessage,
      onError: _onWebSocketError,
      onDone: _onWebSocketClosed,
    );
    
    // Send authentication message
    await _sendAuthMessage();
    
    AppLogger.info('WebSocket connection established');
  }
  
  Future<void> _sendAuthMessage() async {
    final authMessage = TunnelMessage(
      type: TunnelMessageType.auth,
      id: _generateMessageId(),
      data: {
        'access_token': _authService.accessToken,
        'bridge_id': 'flutter-desktop-bridge',
      },
      timestamp: DateTime.now(),
    );
    
    await _sendMessage(authMessage);
  }
  
  void _onWebSocketMessage(dynamic data) {
    try {
      _lastMessageTime = DateTime.now();
      _messagesReceived++;
      
      final messageData = jsonDecode(data as String);
      final message = TunnelMessage.fromJson(messageData);
      
      AppLogger.debug('Received message: ${message.type}');
      
      switch (message.type) {
        case TunnelMessageType.ping:
          _handlePing(message);
          break;
        case TunnelMessageType.request:
          _handleOllamaRequest(message);
          break;
        case TunnelMessageType.auth:
          _handleAuthResponse(message);
          break;
        default:
          AppLogger.warning('Unknown message type: ${message.type}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to process WebSocket message: $e', e, stackTrace);
    }
  }
  
  void _onWebSocketError(error) {
    AppLogger.error('WebSocket error: $error');
    _setError('WebSocket error: $error');
    _setStatus(TunnelStatus.error);
    _scheduleReconnect();
  }
  
  void _onWebSocketClosed() {
    AppLogger.info('WebSocket connection closed');
    _channel = null;
    
    if (_status != TunnelStatus.disconnected) {
      _setStatus(TunnelStatus.disconnected);
      _scheduleReconnect();
    }
  }
  
  Future<void> _handlePing(TunnelMessage message) async {
    final pongMessage = TunnelMessage(
      type: TunnelMessageType.pong,
      id: message.id,
      timestamp: DateTime.now(),
    );
    
    await _sendMessage(pongMessage);
  }
  
  Future<void> _handleOllamaRequest(TunnelMessage message) async {
    try {
      final method = message.data?['method'] as String? ?? 'GET';
      final path = message.data?['path'] as String? ?? '/';
      final headers = Map<String, String>.from(message.data?['headers'] ?? {});
      final body = message.data?['body'] as String?;
      
      // Build Ollama URL
      final ollamaUrl = '${AppConfig.defaultOllamaUrl}$path';
      
      // Create HTTP request
      final request = http.Request(method, Uri.parse(ollamaUrl));
      
      // Add headers
      headers.forEach((key, value) {
        request.headers[key] = value;
      });
      
      // Add body if present
      if (body != null) {
        request.body = body;
      }
      
      // Send request to Ollama
      final streamedResponse = await request.send().timeout(AppConfig.ollamaTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      // Send response back through tunnel
      final responseMessage = TunnelMessage(
        type: TunnelMessageType.response,
        id: message.id,
        data: {
          'status': response.statusCode,
          'headers': response.headers,
          'body': response.body,
        },
        timestamp: DateTime.now(),
      );
      
      await _sendMessage(responseMessage);
      
      AppLogger.debug('Forwarded request to Ollama: $method $path -> ${response.statusCode}');
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to handle Ollama request: $e', e, stackTrace);
      
      // Send error response
      final errorMessage = TunnelMessage(
        type: TunnelMessageType.response,
        id: message.id,
        data: {
          'status': 500,
          'error': 'Internal server error: $e',
        },
        timestamp: DateTime.now(),
      );
      
      await _sendMessage(errorMessage);
    }
  }
  
  void _handleAuthResponse(TunnelMessage message) {
    final success = message.data?['success'] as bool? ?? false;
    if (success) {
      AppLogger.info('Authentication with cloud relay successful');
    } else {
      final error = message.data?['error'] as String? ?? 'Authentication failed';
      AppLogger.error('Authentication with cloud relay failed: $error');
      _setError('Authentication failed: $error');
      _setStatus(TunnelStatus.error);
    }
  }
  
  Future<void> _sendMessage(TunnelMessage message) async {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }
    
    final messageJson = jsonEncode(message.toJson());
    _channel!.sink.add(messageJson);
    _messagesSent++;
    
    AppLogger.debug('Sent message: ${message.type}');
  }
  
  void _startHeartbeat() {
    _stopHeartbeat();
    
    _heartbeatTimer = Timer.periodic(AppConfig.heartbeatInterval, (timer) {
      if (_status == TunnelStatus.connected) {
        _sendHeartbeat();
      }
    });
  }
  
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  Future<void> _sendHeartbeat() async {
    try {
      final pingMessage = TunnelMessage(
        type: TunnelMessageType.ping,
        id: _generateMessageId(),
        timestamp: DateTime.now(),
      );
      
      await _sendMessage(pingMessage);
    } catch (e) {
      AppLogger.error('Failed to send heartbeat: $e');
    }
  }
  
  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectAttempts >= AppConfig.maxReconnectAttempts) {
      AppLogger.info('Max reconnection attempts reached or reconnection disabled');
      return;
    }
    
    _stopReconnectTimer();
    
    final delay = Duration(
      seconds: (AppConfig.reconnectDelay.inSeconds * 
                (1 << _reconnectAttempts.clamp(0, 5))).clamp(1, 300),
    );
    
    AppLogger.info('Scheduling reconnection in ${delay.inSeconds} seconds (attempt ${_reconnectAttempts + 1})');
    
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _setStatus(TunnelStatus.reconnecting);
      connect();
    });
  }
  
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  
  String _generateMessageId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  void _setStatus(TunnelStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    disconnect();
    super.dispose();
  }
}
