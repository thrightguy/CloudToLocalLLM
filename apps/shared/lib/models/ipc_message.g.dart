// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ipc_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IPCMessage _$IPCMessageFromJson(Map<String, dynamic> json) => IPCMessage(
  type: json['type'] as String,
  id: json['id'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  payload: json['payload'] as Map<String, dynamic>,
  ackRequired: json['ackRequired'] as bool? ?? false,
  source: json['source'] as String?,
  target: json['target'] as String?,
);

Map<String, dynamic> _$IPCMessageToJson(IPCMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'payload': instance.payload,
      'ackRequired': instance.ackRequired,
      'source': instance.source,
      'target': instance.target,
    };
