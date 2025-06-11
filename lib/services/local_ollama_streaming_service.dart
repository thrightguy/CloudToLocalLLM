import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import '../config/app_config.dart';
import '../models/ollama_connection_error.dart';
import '../models/streaming_message.dart';
import 'streaming_service.dart';

/// Local Ollama streaming service implementation
///
/// Handles direct streaming communication with local Ollama instance
/// using HTTP streaming and Server-Sent Events.
class LocalOllamaStreamingService extends StreamingService {
  final String _baseUrl;
  final StreamingConfig _config;
  final http.Client _httpClient;

  StreamingConnection _connection = StreamingConnection.disconnected();
  final BehaviorSubject<StreamingMessage> _messageSubject =
      BehaviorSubject<StreamingMessage>();

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  ConnectionRetryState _retryState = ConnectionRetryState.initial();
  OllamaConnectionError? _lastConnectionError;
  bool _isCircuitBreakerOpen = false;

  LocalOllamaStreamingService({String? baseUrl, StreamingConfig? config})
    : _baseUrl = baseUrl ?? AppConfig.defaultOllamaUrl,
      _config = config ?? StreamingConfig.local(),
      _httpClient = http.Client() {
    if (kDebugMode) {
      debugPrint('🦙 [LocalOllamaStreaming] Service initialized');
      debugPrint('🦙 [LocalOllamaStreaming] Base URL: $_baseUrl');
      debugPrint('🦙 [LocalOllamaStreaming] Config: $_config');
    }
  }

  @override
  StreamingConnection get connection => _connection;

  @override
  Stream<StreamingMessage> get messageStream => _messageSubject.stream;

  @override
  Future<void> establishConnection() async {
    if (_connection.isActive) {
      debugPrint('🦙 [LocalOllamaStreaming] Connection already active');
      return;
    }

    _connection = StreamingConnection.connecting(_baseUrl);
    _publishStatusEvent();
    notifyListeners();

    try {
      final stopwatch = Stopwatch()..start();

      // Test basic connectivity
      final response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/api/version'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_config.connectionTimeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['version'] as String?;

        _connection = StreamingConnection.connected(_baseUrl).copyWith(
          latency: Duration(milliseconds: stopwatch.elapsedMilliseconds),
        );

        // Reset retry state on successful connection
        _retryState = ConnectionRetryState.initial();
        _lastConnectionError = null;
        _isCircuitBreakerOpen = false;

        if (_config.enableHeartbeat) {
          _startHeartbeat();
        }

        _publishStatusEvent();
        notifyListeners();

        debugPrint(
          '🦙 [LocalOllamaStreaming] Connected to Ollama v$version '
          '(${stopwatch.elapsedMilliseconds}ms)',
        );
      } else {
        throw StreamingException(
          'Failed to connect: HTTP ${response.statusCode}',
          code: 'HTTP_ERROR',
        );
      }
    } catch (e) {
      // Classify the error for better handling
      _lastConnectionError = OllamaConnectionError.fromException(e);

      _connection = StreamingConnection.error(
        _lastConnectionError!.userFriendlyMessage,
        endpoint: _baseUrl,
      );
      _publishStatusEvent();
      notifyListeners();

      debugPrint(
        '🦙 [LocalOllamaStreaming] Connection failed: ${_lastConnectionError!.userFriendlyMessage}',
      );

      // Implement smart retry logic with exponential backoff
      if (_shouldRetry()) {
        _scheduleReconnect();
      } else {
        _openCircuitBreaker();
      }

      rethrow;
    }
  }

  @override
  Future<void> closeConnection() async {
    debugPrint('🦙 [LocalOllamaStreaming] Closing connection');

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _connection = StreamingConnection.disconnected();
    _publishStatusEvent();
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
    _publishStatusEvent();
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

      debugPrint('🦙 [LocalOllamaStreaming] Starting stream for model: $model');

      final request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/x-ndjson',
      });
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

      await for (final chunk
          in streamedResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;

        try {
          final data = json.decode(chunk);

          if (data['done'] == true) {
            // Stream completed
            final completeMessage = StreamingMessage.complete(
              id: messageId,
              conversationId: conversationId,
              sequence: sequence++,
              model: model,
            );

            yield completeMessage;
            _messageSubject.add(completeMessage);
            break;
          }

          final content = data['message']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            final streamingMessage = StreamingMessage.chunk(
              id: messageId,
              conversationId: conversationId,
              chunk: content,
              sequence: sequence++,
              model: model,
            );

            yield streamingMessage;
            _messageSubject.add(streamingMessage);
          }
        } catch (e) {
          debugPrint('🦙 [LocalOllamaStreaming] Error parsing chunk: $e');
          // Continue processing other chunks
        }
      }

      _connection = _connection.copyWith(
        state: StreamingConnectionState.connected,
        lastActivity: DateTime.now(),
      );
      _publishStatusEvent();
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
      _publishStatusEvent();
      notifyListeners();

      debugPrint('🦙 [LocalOllamaStreaming] Stream error: $e');
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
          .get(
            Uri.parse('$_baseUrl/api/tags'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_config.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models =
            (data['models'] as List?)
                ?.map((model) => model['name'] as String)
                .toList() ??
            [];

        debugPrint('🦙 [LocalOllamaStreaming] Found ${models.length} models');
        return models;
      } else {
        throw StreamingException(
          'Failed to get models: HTTP ${response.statusCode}',
          code: 'HTTP_ERROR',
        );
      }
    } catch (e) {
      debugPrint('🦙 [LocalOllamaStreaming] Error getting models: $e');
      return [];
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_config.heartbeatInterval, (_) async {
      try {
        final response = await _httpClient
            .get(Uri.parse('$_baseUrl/api/version'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) {
          throw StreamingException(
            'Heartbeat failed: HTTP ${response.statusCode}',
          );
        }

        _connection = _connection.copyWith(lastActivity: DateTime.now());
      } catch (e) {
        debugPrint('🦙 [LocalOllamaStreaming] Heartbeat failed: $e');
        _connection = StreamingConnection.error(
          'Heartbeat failed: $e',
          endpoint: _baseUrl,
        );
        _publishStatusEvent();
        notifyListeners();
      }
    });
  }

  /// Check if we should retry the connection
  bool _shouldRetry() {
    if (_isCircuitBreakerOpen) return false;
    if (_lastConnectionError?.isRetryable == false) return false;
    if (_retryState.hasReachedMaxAttempts) return false;

    return true;
  }

  /// Open circuit breaker to stop aggressive retrying
  void _openCircuitBreaker() {
    _isCircuitBreakerOpen = true;
    debugPrint(
      '🦙 [LocalOllamaStreaming] Circuit breaker opened - stopping retries',
    );

    // Schedule circuit breaker reset after a longer delay
    Timer(const Duration(minutes: 5), () {
      _isCircuitBreakerOpen = false;
      _retryState = ConnectionRetryState.initial();
      debugPrint(
        '🦙 [LocalOllamaStreaming] Circuit breaker reset - retries enabled',
      );
    });
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    _retryState = _retryState.nextRetryAttempt(
      maxAttempts: _config.maxReconnectAttempts,
      baseDelay: _config.reconnectDelay,
      maxDelay: const Duration(minutes: 2),
    );

    debugPrint(
      '🦙 [LocalOllamaStreaming] Scheduling reconnect attempt ${_retryState.attemptCount} '
      'in ${_retryState.currentDelay.inSeconds}s',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_retryState.currentDelay, () async {
      if (_isCircuitBreakerOpen) return;

      try {
        await establishConnection();
      } catch (e) {
        debugPrint('🦙 [LocalOllamaStreaming] Reconnect failed: $e');
      }
    });
  }

  /// Reset connection state for manual retry
  void resetConnectionState() {
    _retryState = ConnectionRetryState.initial();
    _lastConnectionError = null;
    _isCircuitBreakerOpen = false;
    _reconnectTimer?.cancel();
    debugPrint(
      '🦙 [LocalOllamaStreaming] Connection state reset for manual retry',
    );
  }

  void _publishStatusEvent() {
    final event = ConnectionStatusEvent(
      state: _connection.state,
      endpoint: _connection.endpoint,
      error: _connection.error,
      timestamp: DateTime.now(),
      latency: _connection.latency,
    );
    StatusEventBus().publishStatus(event);
  }

  @override
  void dispose() {
    debugPrint('🦙 [LocalOllamaStreaming] Disposing service');

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageSubject.close();
    _httpClient.close();

    super.dispose();
  }
}
