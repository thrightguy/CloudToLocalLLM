import 'package:json_annotation/json_annotation.dart';

part 'tunnel_message.g.dart';

enum TunnelMessageType {
  @JsonValue('auth')
  auth,
  @JsonValue('request')
  request,
  @JsonValue('response')
  response,
  @JsonValue('ping')
  ping,
  @JsonValue('pong')
  pong,
  @JsonValue('error')
  error,
}

@JsonSerializable()
class TunnelMessage {
  final TunnelMessageType type;
  final String id;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const TunnelMessage({
    required this.type,
    required this.id,
    this.data,
    required this.timestamp,
  });

  factory TunnelMessage.fromJson(Map<String, dynamic> json) =>
      _$TunnelMessageFromJson(json);

  Map<String, dynamic> toJson() => _$TunnelMessageToJson(this);

  TunnelMessage copyWith({
    TunnelMessageType? type,
    String? id,
    Map<String, dynamic>? data,
    DateTime? timestamp,
  }) {
    return TunnelMessage(
      type: type ?? this.type,
      id: id ?? this.id,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'TunnelMessage(type: $type, id: $id, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TunnelMessage &&
        other.type == type &&
        other.id == id &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return type.hashCode ^ id.hashCode ^ timestamp.hashCode;
  }
}
