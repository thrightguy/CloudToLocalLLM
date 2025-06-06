import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'ipc_message.g.dart';

/// Inter-Process Communication message format for CloudToLocalLLM
/// 
/// Provides a standardized message format for communication between
/// the three applications: chat, tunnel, and tray.
@JsonSerializable()
class IPCMessage {
  /// Message type identifier
  final String type;
  
  /// Unique message identifier for tracking and acknowledgment
  final String id;
  
  /// Timestamp when the message was created
  final DateTime timestamp;
  
  /// Message payload containing the actual data
  final Map<String, dynamic> payload;
  
  /// Whether this message requires acknowledgment
  final bool ackRequired;
  
  /// Source application that sent the message
  final String? source;
  
  /// Target application that should receive the message
  final String? target;

  const IPCMessage({
    required this.type,
    required this.id,
    required this.timestamp,
    required this.payload,
    this.ackRequired = false,
    this.source,
    this.target,
  });

  /// Create an IPC message from JSON
  factory IPCMessage.fromJson(Map<String, dynamic> json) =>
      _$IPCMessageFromJson(json);

  /// Convert IPC message to JSON
  Map<String, dynamic> toJson() => _$IPCMessageToJson(this);

  /// Create an IPC message from JSON string
  factory IPCMessage.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return IPCMessage.fromJson(json);
  }

  /// Convert IPC message to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create a response message to this message
  IPCMessage createResponse({
    required String responseType,
    required Map<String, dynamic> responsePayload,
    bool ackRequired = false,
  }) {
    return IPCMessage(
      type: responseType,
      id: '${id}_response_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      payload: responsePayload,
      ackRequired: ackRequired,
      source: target,
      target: source,
    );
  }

  /// Create an acknowledgment message for this message
  IPCMessage createAck({
    bool success = true,
    String? error,
  }) {
    return IPCMessage(
      type: 'ack',
      id: '${id}_ack',
      timestamp: DateTime.now(),
      payload: {
        'original_id': id,
        'success': success,
        if (error != null) 'error': error,
      },
      ackRequired: false,
      source: target,
      target: source,
    );
  }

  @override
  String toString() {
    return 'IPCMessage(type: $type, id: $id, source: $source, target: $target)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IPCMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined message types for CloudToLocalLLM IPC
class IPCMessageTypes {
  // Chat ↔ Tunnel communication
  static const String streamRequest = 'stream_request';
  static const String streamResponse = 'stream_response';
  static const String streamComplete = 'stream_complete';
  static const String streamError = 'stream_error';
  
  // Tray ↔ Chat communication
  static const String showWindow = 'show_window';
  static const String hideWindow = 'hide_window';
  static const String toggleWindow = 'toggle_window';
  static const String quitApplication = 'quit_application';
  static const String openSettings = 'open_settings';
  
  // Tray ↔ Tunnel communication
  static const String healthCheck = 'health_check';
  static const String restartService = 'restart_service';
  static const String serviceStatus = 'service_status';
  
  // General communication
  static const String ack = 'ack';
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String error = 'error';
  static const String shutdown = 'shutdown';
}

/// Application identifiers for IPC routing
class IPCApplications {
  static const String chat = 'chat';
  static const String tunnel = 'tunnel';
  static const String tray = 'tray';
}

/// IPC port assignments for each service
class IPCPorts {
  static const int chatTunnelPort = 8181;  // Chat ↔ Tunnel
  static const int trayChatPort = 8183;    // Tray ↔ Chat
  static const int trayTunnelPort = 8184;  // Tray ↔ Tunnel
  static const int trayHealthPort = 8185;  // Tray health check
  static const int webProxyPort = 8182;    // Web client proxy
}

/// Helper class for creating common IPC messages
class IPCMessageFactory {
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Create a stream request message
  static IPCMessage createStreamRequest({
    required String model,
    required String message,
    List<Map<String, String>>? history,
    String? source,
  }) {
    return IPCMessage(
      type: IPCMessageTypes.streamRequest,
      id: _generateId(),
      timestamp: DateTime.now(),
      payload: {
        'model': model,
        'message': message,
        if (history != null) 'history': history,
      },
      ackRequired: true,
      source: source ?? IPCApplications.chat,
      target: IPCApplications.tunnel,
    );
  }

  /// Create a window control message
  static IPCMessage createWindowControl({
    required String action,
    String? source,
  }) {
    return IPCMessage(
      type: action,
      id: _generateId(),
      timestamp: DateTime.now(),
      payload: {},
      ackRequired: false,
      source: source ?? IPCApplications.tray,
      target: IPCApplications.chat,
    );
  }

  /// Create a health check message
  static IPCMessage createHealthCheck({
    required String service,
    String? source,
  }) {
    return IPCMessage(
      type: IPCMessageTypes.healthCheck,
      id: _generateId(),
      timestamp: DateTime.now(),
      payload: {'service': service},
      ackRequired: true,
      source: source ?? IPCApplications.tray,
      target: service,
    );
  }

  /// Create a ping message
  static IPCMessage createPing({String? source, String? target}) {
    return IPCMessage(
      type: IPCMessageTypes.ping,
      id: _generateId(),
      timestamp: DateTime.now(),
      payload: {},
      ackRequired: true,
      source: source,
      target: target,
    );
  }
}
