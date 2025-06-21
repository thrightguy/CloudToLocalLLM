import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import '../config/app_config.dart';
import '../models/streaming_message.dart';
import 'streaming_service.dart';
import 'auth_service.dart';

/// Cloud streaming service implementation
///
/// Handles streaming communication with cloud Ollama proxy through WebSocket
/// and HTTP streaming protocols.
class CloudStreamingService extends StreamingService {
  final String _baseUrl;
  final StreamingConfig _config;
  final AuthService _authService;
  final http.Client _httpClient;

  StreamingConnection _connection = StreamingConnection.disconnected();
  final BehaviorSubject<StreamingMessage> _messageSubject =
      BehaviorSubject<StreamingMessage>();

  WebSocket? _webSocket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  CloudStreamingService({
    String? baseUrl,
    StreamingConfig? config,
    required AuthService authService,
  }) : _baseUrl = baseUrl ?? AppConfig.cloudOllamaUrl,
       _config = config ?? StreamingConfig.cloud(),
       _authService = authService,
       _httpClient = http.Client() {
    if (kDebugMode) {
      debugPrint('☁️ [CloudStreaming] Service initialized');
      debugPrint('☁️ [CloudStreaming] Base URL: $_baseUrl');
      debugPrint('☁️ [CloudStreaming] Config: $_config');
    }
  }

  @override
  StreamingConnection get connection => _connection;

  @override
  Stream<StreamingMessage> get messageStream => _messageSubject.stream;

  @override
  Future<void> establishConnection() async {
    if (_connection.isActive) {
      debugPrint('☁️ [CloudStreaming] Connection already active');
      return;
    }

    _connection = StreamingConnection.connecting(_baseUrl);
    notifyListeners();

    try {
      final stopwatch = Stopwatch()..start();

      // Test basic connectivity first
      final response = await _httpClient
          .get(Uri.parse('$_baseUrl/api/version'), headers: _getHeaders())
          .timeout(_config.connectionTimeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['version'] as String?;

        _connection = StreamingConnection.connected(_baseUrl).copyWith(
          latency: Duration(milliseconds: stopwatch.elapsedMilliseconds),
        );

        // Reset retry state on successful connection

        if (_config.enableHeartbeat) {
          _startHeartbeat();
        }

        // Establish WebSocket connection for streaming
        await _establishWebSocket();

        notifyListeners();

        debugPrint(
          '☁️ [CloudStreaming] Connected to cloud proxy v$version '
          '(${stopwatch.elapsedMilliseconds}ms)',
        );
      } else {
        throw StreamingException(
          'Failed to connect: HTTP ${response.statusCode}',
          code: 'HTTP_ERROR',
        );
      }
    } catch (e) {
      _connection = StreamingConnection.error(
        'Connection failed: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();

      debugPrint('☁️ [CloudStreaming] Connection error: $e');
      rethrow;
    }
  }

  @override
  Future<void> closeConnection() async {
    debugPrint('☁️ [CloudStreaming] Closing connection');

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _webSocket?.close();
    _webSocket = null;

    _connection = StreamingConnection.disconnected();
    notifyListeners();
  }

  @override
  Stream<StreamingMessage> streamResponse({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) async* {
    if (!_connection.isActive) {
      await establishConnection();
    }

    _connection = _connection.copyWith(
      state: StreamingConnectionState.streaming,
      lastActivity: DateTime.now(),
    );
    notifyListeners();

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    int sequence = 0;

    try {
      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': prompt},
      ];

      final requestBody = {
        'model': model,
        'messages': messages,
        'stream': true,
      };

      debugPrint('☁️ [CloudStreaming] Starting stream for model: $model');

      final request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'));
      request.headers.addAll(_getHeaders());
      request.headers['Accept'] = 'application/x-ndjson';
      request.body = json.encode(requestBody);

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(_config.streamTimeout);

      if (streamedResponse.statusCode != 200) {
        throw StreamingException(
          'Stream request failed: HTTP ${streamedResponse.statusCode}',
          code: 'STREAM_ERROR',
        );
      }

      // Process streaming response
      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          try {
            final data = json.decode(line);
            final content = data['message']?['content'] as String? ?? '';
            final done = data['done'] as bool? ?? false;

            final message = StreamingMessage.chunk(
              id: messageId,
              conversationId: conversationId,
              chunk: content,
              sequence: sequence++,
              model: model,
            );

            yield message;
            _messageSubject.add(message);

            if (done) {
              final completeMessage = StreamingMessage.complete(
                id: messageId,
                conversationId: conversationId,
                sequence: sequence,
                model: model,
              );

              yield completeMessage;
              _messageSubject.add(completeMessage);
              break;
            }
          } catch (e) {
            debugPrint('☁️ [CloudStreaming] Error parsing chunk: $e');
          }
        }
      }

      _connection = _connection.copyWith(
        state: StreamingConnectionState.connected,
        lastActivity: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      final errorMessage = StreamingMessage.error(
        id: messageId,
        conversationId: conversationId,
        error: e.toString(),
        sequence: sequence,
      );

      yield errorMessage;
      _messageSubject.add(errorMessage);

      _connection = StreamingConnection.error(
        'Streaming failed: $e',
        endpoint: _baseUrl,
      );
      notifyListeners();

      debugPrint('☁️ [CloudStreaming] Stream error: $e');
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await establishConnection();
      return _connection.isActive;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    if (!_connection.isActive) {
      await establishConnection();
    }

    try {
      final response = await _httpClient
          .get(Uri.parse('$_baseUrl/api/tags'), headers: _getHeaders())
          .timeout(_config.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models =
            (data['models'] as List?)
                ?.map((model) => model['name'] as String)
                .toList() ??
            [];

        debugPrint('☁️ [CloudStreaming] Found ${models.length} models');
        return models;
      } else {
        throw StreamingException(
          'Failed to get models: HTTP ${response.statusCode}',
          code: 'HTTP_ERROR',
        );
      }
    } catch (e) {
      debugPrint('☁️ [CloudStreaming] Error getting models: $e');
      return [];
    }
  }

  /// Get headers for HTTP requests
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add authentication if available
    if (_authService.isAuthenticated.value) {
      final accessToken = _authService.getAccessToken();
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    return headers;
  }

  /// Establish WebSocket connection for real-time communication
  Future<void> _establishWebSocket() async {
    try {
      final wsUrl = _baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final wsUri = Uri.parse('$wsUrl/ws/stream');

      _webSocket = await WebSocket.connect(wsUri.toString());

      _webSocket!.listen(
        (data) {
          try {
            final message = json.decode(data);
            _handleWebSocketMessage(message);
          } catch (e) {
            debugPrint(
              '☁️ [CloudStreaming] Error parsing WebSocket message: $e',
            );
          }
        },
        onError: (error) {
          debugPrint('☁️ [CloudStreaming] WebSocket error: $error');
          _webSocket = null;
        },
        onDone: () {
          debugPrint('☁️ [CloudStreaming] WebSocket connection closed');
          _webSocket = null;
        },
      );

      debugPrint('☁️ [CloudStreaming] WebSocket connection established');
    } catch (e) {
      debugPrint('☁️ [CloudStreaming] Failed to establish WebSocket: $e');
      // WebSocket is optional, continue without it
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'ping':
        // Respond to ping with pong
        _webSocket?.add(json.encode({'type': 'pong'}));
        break;
      case 'status':
        // Handle status updates
        debugPrint('☁️ [CloudStreaming] Status update: ${message['status']}');
        break;
      default:
        debugPrint('☁️ [CloudStreaming] Unknown message type: $type');
    }
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_webSocket != null) {
        _webSocket!.add(
          json.encode({
            'type': 'ping',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      }
    });
  }

  @override
  void dispose() {
    debugPrint('☁️ [CloudStreaming] Disposing service');
    closeConnection();
    _messageSubject.close();
    _httpClient.close();
    super.dispose();
  }
}
