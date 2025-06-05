// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TunnelConfig _$TunnelConfigFromJson(Map<String, dynamic> json) => TunnelConfig(
  enableLocalOllama: json['enableLocalOllama'] as bool? ?? true,
  ollamaHost: json['ollamaHost'] as String? ?? 'localhost',
  ollamaPort: (json['ollamaPort'] as num?)?.toInt() ?? 11434,
  connectionTimeout: (json['connectionTimeout'] as num?)?.toInt() ?? 30,
  enableCloudProxy: json['enableCloudProxy'] as bool? ?? true,
  cloudProxyUrl:
      json['cloudProxyUrl'] as String? ?? 'https://app.cloudtolocalllm.online',
  cloudProxyAudience:
      json['cloudProxyAudience'] as String? ??
      'https://api.cloudtolocalllm.online',
  apiServerPort: (json['apiServerPort'] as num?)?.toInt() ?? 8765,
  enableApiServer: json['enableApiServer'] as bool? ?? true,
  allowedOrigins:
      (json['allowedOrigins'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const ['http://localhost:*', 'https://app.cloudtolocalllm.online'],
  healthCheckInterval: (json['healthCheckInterval'] as num?)?.toInt() ?? 30,
  maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 5,
  retryDelay: (json['retryDelay'] as num?)?.toInt() ?? 2,
  connectionPoolSize: (json['connectionPoolSize'] as num?)?.toInt() ?? 10,
  requestTimeout: (json['requestTimeout'] as num?)?.toInt() ?? 60,
  enableMetrics: json['enableMetrics'] as bool? ?? true,
  minimizeToTray: json['minimizeToTray'] as bool? ?? true,
  startMinimized: json['startMinimized'] as bool? ?? false,
  showNotifications: json['showNotifications'] as bool? ?? true,
  logLevel: json['logLevel'] as String? ?? 'INFO',
  autoStartTunnel: json['autoStartTunnel'] as bool? ?? true,
  autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
);

Map<String, dynamic> _$TunnelConfigToJson(TunnelConfig instance) =>
    <String, dynamic>{
      'enableLocalOllama': instance.enableLocalOllama,
      'ollamaHost': instance.ollamaHost,
      'ollamaPort': instance.ollamaPort,
      'connectionTimeout': instance.connectionTimeout,
      'enableCloudProxy': instance.enableCloudProxy,
      'cloudProxyUrl': instance.cloudProxyUrl,
      'cloudProxyAudience': instance.cloudProxyAudience,
      'apiServerPort': instance.apiServerPort,
      'enableApiServer': instance.enableApiServer,
      'allowedOrigins': instance.allowedOrigins,
      'healthCheckInterval': instance.healthCheckInterval,
      'maxRetries': instance.maxRetries,
      'retryDelay': instance.retryDelay,
      'connectionPoolSize': instance.connectionPoolSize,
      'requestTimeout': instance.requestTimeout,
      'enableMetrics': instance.enableMetrics,
      'minimizeToTray': instance.minimizeToTray,
      'startMinimized': instance.startMinimized,
      'showNotifications': instance.showNotifications,
      'logLevel': instance.logLevel,
      'autoStartTunnel': instance.autoStartTunnel,
      'autoStartOnBoot': instance.autoStartOnBoot,
    };
