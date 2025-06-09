import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/streaming_message.dart';

/// Abstract streaming service interface for real-time communication
///
/// Defines the contract for streaming services that handle real-time
/// communication with Ollama instances (local or cloud).
abstract class StreamingService extends ChangeNotifier {
  /// Current connection status
  StreamingConnection get connection;

  /// Stream of incoming messages
  Stream<StreamingMessage> get messageStream;

  /// Establish connection to the streaming endpoint
  Future<void> establishConnection();

  /// Close the streaming connection
  Future<void> closeConnection();

  /// Send a streaming chat request
  ///
  /// Returns a stream of [StreamingMessage] chunks that represent
  /// the progressive response from the LLM.
  Stream<StreamingMessage> streamResponse({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  });

  /// Test connection without establishing a persistent stream
  Future<bool> testConnection();

  /// Get available models from the endpoint
  Future<List<String>> getAvailableModels();

  /// Dispose of resources
  @override
  void dispose();
}

/// Status event for connection changes
@immutable
class ConnectionStatusEvent {
  final StreamingConnectionState state;
  final String? endpoint;
  final String? error;
  final DateTime timestamp;
  final Duration? latency;

  const ConnectionStatusEvent({
    required this.state,
    this.endpoint,
    this.error,
    required this.timestamp,
    this.latency,
  });

  factory ConnectionStatusEvent.connected(
    String endpoint, {
    Duration? latency,
  }) {
    return ConnectionStatusEvent(
      state: StreamingConnectionState.connected,
      endpoint: endpoint,
      timestamp: DateTime.now(),
      latency: latency,
    );
  }

  factory ConnectionStatusEvent.disconnected({String? error}) {
    return ConnectionStatusEvent(
      state: StreamingConnectionState.disconnected,
      error: error,
      timestamp: DateTime.now(),
    );
  }

  factory ConnectionStatusEvent.error(String error, {String? endpoint}) {
    return ConnectionStatusEvent(
      state: StreamingConnectionState.error,
      endpoint: endpoint,
      error: error,
      timestamp: DateTime.now(),
    );
  }

  factory ConnectionStatusEvent.streaming(String endpoint) {
    return ConnectionStatusEvent(
      state: StreamingConnectionState.streaming,
      endpoint: endpoint,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ConnectionStatusEvent(state: $state, endpoint: $endpoint, '
        'error: $error, timestamp: $timestamp)';
  }
}

/// Event bus for status events across the application
class StatusEventBus {
  static final StatusEventBus _instance = StatusEventBus._internal();
  factory StatusEventBus() => _instance;
  StatusEventBus._internal();

  final StreamController<ConnectionStatusEvent> _statusController =
      StreamController<ConnectionStatusEvent>.broadcast();

  /// Stream of connection status events
  Stream<ConnectionStatusEvent> get statusStream => _statusController.stream;

  /// Publish a status event
  void publishStatus(ConnectionStatusEvent event) {
    if (!_statusController.isClosed) {
      _statusController.add(event);
      if (kDebugMode) {
        debugPrint('📡 [StatusEventBus] Published: $event');
      }
    }
  }

  /// Dispose of the event bus
  void dispose() {
    _statusController.close();
  }
}

/// Streaming configuration
@immutable
class StreamingConfig {
  final Duration connectionTimeout;
  final Duration streamTimeout;
  final int maxReconnectAttempts;
  final Duration reconnectDelay;
  final int maxChunkSize;
  final bool enableHeartbeat;
  final Duration heartbeatInterval;

  const StreamingConfig({
    this.connectionTimeout = const Duration(seconds: 30),
    this.streamTimeout = const Duration(minutes: 5),
    this.maxReconnectAttempts = 3,
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxChunkSize = 8192,
    this.enableHeartbeat = true,
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  /// Default configuration for local Ollama
  factory StreamingConfig.local() {
    return const StreamingConfig(
      connectionTimeout: Duration(seconds: 10),
      streamTimeout: Duration(minutes: 10),
      maxReconnectAttempts: 5,
      reconnectDelay: Duration(seconds: 1),
    );
  }

  /// Default configuration for cloud proxy
  factory StreamingConfig.cloud() {
    return const StreamingConfig(
      connectionTimeout: Duration(seconds: 30),
      streamTimeout: Duration(minutes: 5),
      maxReconnectAttempts: 3,
      reconnectDelay: Duration(seconds: 3),
      enableHeartbeat: true,
    );
  }

  StreamingConfig copyWith({
    Duration? connectionTimeout,
    Duration? streamTimeout,
    int? maxReconnectAttempts,
    Duration? reconnectDelay,
    int? maxChunkSize,
    bool? enableHeartbeat,
    Duration? heartbeatInterval,
  }) {
    return StreamingConfig(
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      streamTimeout: streamTimeout ?? this.streamTimeout,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxChunkSize: maxChunkSize ?? this.maxChunkSize,
      enableHeartbeat: enableHeartbeat ?? this.enableHeartbeat,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
    );
  }
}

/// Exception thrown by streaming services
class StreamingException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const StreamingException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    return 'StreamingException: $message${code != null ? ' (code: $code)' : ''}';
  }
}

/// Connection timeout exception
class ConnectionTimeoutException extends StreamingException {
  const ConnectionTimeoutException(String endpoint)
    : super('Connection timeout to $endpoint', code: 'CONNECTION_TIMEOUT');
}

/// Stream timeout exception
class StreamTimeoutException extends StreamingException {
  const StreamTimeoutException()
    : super('Stream response timeout', code: 'STREAM_TIMEOUT');
}

/// Authentication exception
class StreamingAuthException extends StreamingException {
  const StreamingAuthException(super.message) : super(code: 'AUTH_ERROR');
}
