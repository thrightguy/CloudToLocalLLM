// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_metrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunnelMetrics _$TunnelMetricsFromJson(Map<String, dynamic> json) =>
    TunnelMetrics(
      connectedCount: (json['connectedCount'] as num?)?.toInt() ?? 0,
      totalConnections: (json['totalConnections'] as num?)?.toInt() ?? 0,
      startTime: json['startTime'] == null
          ? null
          : DateTime.parse(json['startTime'] as String),
      totalRequests: (json['totalRequests'] as num?)?.toInt() ?? 0,
      successfulRequests: (json['successfulRequests'] as num?)?.toInt() ?? 0,
      failedRequests: (json['failedRequests'] as num?)?.toInt() ?? 0,
      requestsPerSecond: (json['requestsPerSecond'] as num?)?.toInt() ?? 0,
      averageLatency: (json['averageLatency'] as num?)?.toDouble() ?? 0.0,
      lastError: json['lastError'] == null
          ? null
          : DateTime.parse(json['lastError'] as String),
      memoryUsageMB: (json['memoryUsageMB'] as num?)?.toDouble() ?? 0.0,
      cpuUsagePercent: (json['cpuUsagePercent'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$TunnelMetricsToJson(TunnelMetrics instance) =>
    <String, dynamic>{
      'connectedCount': instance.connectedCount,
      'totalConnections': instance.totalConnections,
      'startTime': instance.startTime.toIso8601String(),
      'totalRequests': instance.totalRequests,
      'successfulRequests': instance.successfulRequests,
      'failedRequests': instance.failedRequests,
      'requestsPerSecond': instance.requestsPerSecond,
      'averageLatency': instance.averageLatency,
      'lastError': instance.lastError?.toIso8601String(),
      'memoryUsageMB': instance.memoryUsageMB,
      'cpuUsagePercent': instance.cpuUsagePercent,
    };
