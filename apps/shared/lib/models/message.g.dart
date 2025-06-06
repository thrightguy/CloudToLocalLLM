// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String,
  role: $enumDecode(_$MessageRoleEnumMap, json['role']),
  content: json['content'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  isStreaming: json['isStreaming'] as bool? ?? false,
  hasError: json['hasError'] as bool? ?? false,
  error: json['error'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'role': _$MessageRoleEnumMap[instance.role]!,
  'content': instance.content,
  'timestamp': instance.timestamp.toIso8601String(),
  'isStreaming': instance.isStreaming,
  'hasError': instance.hasError,
  'error': instance.error,
  'metadata': instance.metadata,
};

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.assistant: 'assistant',
  MessageRole.system: 'system',
};
