import 'dart:convert';
import 'dart:math';

/// Message types for encrypted tunnel protocol
enum TunnelMessageType {
  httpRequest,
  httpResponse,
  keyExchange,
  sessionEstablished,
  error,
  ping,
  pong,
}

/// Base class for all tunnel messages
abstract class TunnelMessage {
  final TunnelMessageType type;
  final String id;
  final DateTime timestamp;

  TunnelMessage({required this.type, required this.id, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson();

  static TunnelMessage fromJson(Map<String, dynamic> json) {
    final type = TunnelMessageType.values.firstWhere(
      (t) => t.name == json['type'],
    );

    switch (type) {
      case TunnelMessageType.httpRequest:
        return HttpRequestMessage.fromJson(json);
      case TunnelMessageType.httpResponse:
        return HttpResponseMessage.fromJson(json);
      case TunnelMessageType.keyExchange:
        return KeyExchangeMessage.fromJson(json);
      case TunnelMessageType.sessionEstablished:
        return SessionEstablishedMessage.fromJson(json);
      case TunnelMessageType.error:
        return ErrorMessage.fromJson(json);
      case TunnelMessageType.ping:
        return PingMessage.fromJson(json);
      case TunnelMessageType.pong:
        return PongMessage.fromJson(json);
    }
  }
}

/// HTTP request message for tunnel
class HttpRequestMessage extends TunnelMessage {
  final String method;
  final String path;
  final Map<String, String> headers;
  final String? body;
  final String? correlationId;

  HttpRequestMessage({
    required super.id,
    required this.method,
    required this.path,
    required this.headers,
    this.body,
    this.correlationId,
    super.timestamp,
  }) : super(type: TunnelMessageType.httpRequest);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'path': path,
      'headers': headers,
      'body': body,
      'correlationId': correlationId,
    };
  }

  factory HttpRequestMessage.fromJson(Map<String, dynamic> json) {
    return HttpRequestMessage(
      id: json['id'],
      method: json['method'],
      path: json['path'],
      headers: Map<String, String>.from(json['headers'] ?? {}),
      body: json['body'],
      correlationId: json['correlationId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// HTTP response message for tunnel
class HttpResponseMessage extends TunnelMessage {
  final int statusCode;
  final Map<String, String> headers;
  final String? body;
  final String? correlationId;

  HttpResponseMessage({
    required super.id,
    required this.statusCode,
    required this.headers,
    this.body,
    this.correlationId,
    super.timestamp,
  }) : super(type: TunnelMessageType.httpResponse);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
      'correlationId': correlationId,
    };
  }

  factory HttpResponseMessage.fromJson(Map<String, dynamic> json) {
    return HttpResponseMessage(
      id: json['id'],
      statusCode: json['statusCode'],
      headers: Map<String, String>.from(json['headers'] ?? {}),
      body: json['body'],
      correlationId: json['correlationId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Key exchange message for establishing encrypted session
class KeyExchangeMessage extends TunnelMessage {
  final String publicKey;
  final String userId;

  KeyExchangeMessage({
    required super.id,
    required this.publicKey,
    required this.userId,
    super.timestamp,
  }) : super(type: TunnelMessageType.keyExchange);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'publicKey': publicKey,
      'userId': userId,
    };
  }

  factory KeyExchangeMessage.fromJson(Map<String, dynamic> json) {
    return KeyExchangeMessage(
      id: json['id'],
      publicKey: json['publicKey'],
      userId: json['userId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Session established confirmation message
class SessionEstablishedMessage extends TunnelMessage {
  final String sessionId;
  final String publicKey;

  SessionEstablishedMessage({
    required super.id,
    required this.sessionId,
    required this.publicKey,
    super.timestamp,
  }) : super(type: TunnelMessageType.sessionEstablished);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'publicKey': publicKey,
    };
  }

  factory SessionEstablishedMessage.fromJson(Map<String, dynamic> json) {
    return SessionEstablishedMessage(
      id: json['id'],
      sessionId: json['sessionId'],
      publicKey: json['publicKey'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Error message
class ErrorMessage extends TunnelMessage {
  final String error;
  final String? details;
  final String? correlationId;

  ErrorMessage({
    required super.id,
    required this.error,
    this.details,
    this.correlationId,
    super.timestamp,
  }) : super(type: TunnelMessageType.error);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'details': details,
      'correlationId': correlationId,
    };
  }

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(
      id: json['id'],
      error: json['error'],
      details: json['details'],
      correlationId: json['correlationId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Ping message for connection health
class PingMessage extends TunnelMessage {
  PingMessage({required super.id, super.timestamp})
    : super(type: TunnelMessageType.ping);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PingMessage.fromJson(Map<String, dynamic> json) {
    return PingMessage(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Pong message for connection health
class PongMessage extends TunnelMessage {
  final String pingId;

  PongMessage({required super.id, required this.pingId, super.timestamp})
    : super(type: TunnelMessageType.pong);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'pingId': pingId,
    };
  }

  factory PongMessage.fromJson(Map<String, dynamic> json) {
    return PongMessage(
      id: json['id'],
      pingId: json['pingId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Utility class for generating message IDs
class MessageIdGenerator {
  static final Random _random = Random.secure();

  static String generate() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    return base64Encode(bytes).replaceAll('/', '_').replaceAll('+', '-');
  }
}

/// Encrypted tunnel message wrapper
class EncryptedTunnelMessage {
  final String encryptedData;
  final String sessionId;
  final DateTime timestamp;

  EncryptedTunnelMessage({
    required this.encryptedData,
    required this.sessionId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'encryptedData': encryptedData,
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory EncryptedTunnelMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedTunnelMessage(
      encryptedData: json['encryptedData'],
      sessionId: json['sessionId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
