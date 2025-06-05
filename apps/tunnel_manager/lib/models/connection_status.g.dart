// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionStatus _$ConnectionStatusFromJson(Map<String, dynamic> json) =>
    ConnectionStatus(
      type: json['type'] as String,
      isConnected: json['isConnected'] as bool,
      endpoint: json['endpoint'] as String,
      version: json['version'] as String?,
      models:
          (json['models'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      error: json['error'] as String?,
      lastCheck: DateTime.parse(json['lastCheck'] as String),
      latency: (json['latency'] as num?)?.toDouble() ?? 0.0,
      requestCount: (json['requestCount'] as num?)?.toInt() ?? 0,
      errorCount: (json['errorCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] == null
          ? null
          : DateTime.parse(json['lastError'] as String),
    );

Map<String, dynamic> _$ConnectionStatusToJson(ConnectionStatus instance) =>
    <String, dynamic>{
      'type': instance.type,
      'isConnected': instance.isConnected,
      'endpoint': instance.endpoint,
      'version': instance.version,
      'models': instance.models,
      'error': instance.error,
      'lastCheck': instance.lastCheck.toIso8601String(),
      'latency': instance.latency,
      'requestCount': instance.requestCount,
      'errorCount': instance.errorCount,
      'lastError': instance.lastError?.toIso8601String(),
    };
