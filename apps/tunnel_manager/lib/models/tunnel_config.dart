import 'package:json_annotation/json_annotation.dart';

part 'tunnel_config.g.dart';

@JsonSerializable()
class TunnelConfig {
  // Local Ollama configuration
  final bool enableLocalOllama;
  final String ollamaHost;
  final int ollamaPort;
  final int connectionTimeout;

  // Cloud proxy configuration
  final bool enableCloudProxy;
  final String cloudProxyUrl;
  final String cloudProxyAudience;

  // API server configuration
  final int apiServerPort;
  final bool enableApiServer;
  final List<String> allowedOrigins;

  // Health monitoring configuration
  final int healthCheckInterval; // seconds
  final int maxRetries;
  final int retryDelay; // seconds

  // Performance configuration
  final int connectionPoolSize;
  final int requestTimeout; // seconds
  final bool enableMetrics;

  // UI configuration
  final bool minimizeToTray;
  final bool startMinimized;
  final bool showNotifications;
  final String logLevel; // DEBUG, INFO, WARN, ERROR

  // Auto-start configuration
  final bool autoStartTunnel;
  final bool autoStartOnBoot;

  const TunnelConfig({
    // Local Ollama defaults
    this.enableLocalOllama = true,
    this.ollamaHost = 'localhost',
    this.ollamaPort = 11434,
    this.connectionTimeout = 30,

    // Cloud proxy defaults
    this.enableCloudProxy = true,
    this.cloudProxyUrl = 'https://app.cloudtolocalllm.online',
    this.cloudProxyAudience = 'https://api.cloudtolocalllm.online',

    // API server defaults
    this.apiServerPort = 8765,
    this.enableApiServer = true,
    this.allowedOrigins = const [
      'http://localhost:*',
      'https://app.cloudtolocalllm.online',
    ],

    // Health monitoring defaults
    this.healthCheckInterval = 30,
    this.maxRetries = 5,
    this.retryDelay = 2,

    // Performance defaults
    this.connectionPoolSize = 10,
    this.requestTimeout = 60,
    this.enableMetrics = true,

    // UI defaults
    this.minimizeToTray = true,
    this.startMinimized = false,
    this.showNotifications = true,
    this.logLevel = 'INFO',

    // Auto-start defaults
    this.autoStartTunnel = true,
    this.autoStartOnBoot = false,
  });

  /// Create configuration from JSON
  factory TunnelConfig.fromJson(Map<String, dynamic> json) =>
      _$TunnelConfigFromJson(json);

  /// Convert configuration to JSON
  Map<String, dynamic> toJson() => _$TunnelConfigToJson(this);

  /// Create a copy with modified values
  TunnelConfig copyWith({
    bool? enableLocalOllama,
    String? ollamaHost,
    int? ollamaPort,
    int? connectionTimeout,
    bool? enableCloudProxy,
    String? cloudProxyUrl,
    String? cloudProxyAudience,
    int? apiServerPort,
    bool? enableApiServer,
    List<String>? allowedOrigins,
    int? healthCheckInterval,
    int? maxRetries,
    int? retryDelay,
    int? connectionPoolSize,
    int? requestTimeout,
    bool? enableMetrics,
    bool? minimizeToTray,
    bool? startMinimized,
    bool? showNotifications,
    String? logLevel,
    bool? autoStartTunnel,
    bool? autoStartOnBoot,
  }) {
    return TunnelConfig(
      enableLocalOllama: enableLocalOllama ?? this.enableLocalOllama,
      ollamaHost: ollamaHost ?? this.ollamaHost,
      ollamaPort: ollamaPort ?? this.ollamaPort,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      enableCloudProxy: enableCloudProxy ?? this.enableCloudProxy,
      cloudProxyUrl: cloudProxyUrl ?? this.cloudProxyUrl,
      cloudProxyAudience: cloudProxyAudience ?? this.cloudProxyAudience,
      apiServerPort: apiServerPort ?? this.apiServerPort,
      enableApiServer: enableApiServer ?? this.enableApiServer,
      allowedOrigins: allowedOrigins ?? this.allowedOrigins,
      healthCheckInterval: healthCheckInterval ?? this.healthCheckInterval,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      connectionPoolSize: connectionPoolSize ?? this.connectionPoolSize,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      enableMetrics: enableMetrics ?? this.enableMetrics,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      startMinimized: startMinimized ?? this.startMinimized,
      showNotifications: showNotifications ?? this.showNotifications,
      logLevel: logLevel ?? this.logLevel,
      autoStartTunnel: autoStartTunnel ?? this.autoStartTunnel,
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
    );
  }

  /// Validate configuration
  List<String> validate() {
    final errors = <String>[];

    // Validate Ollama configuration
    if (enableLocalOllama) {
      if (ollamaHost.isEmpty) {
        errors.add('Ollama host cannot be empty');
      }
      if (ollamaPort <= 0 || ollamaPort > 65535) {
        errors.add('Ollama port must be between 1 and 65535');
      }
    }

    // Validate cloud proxy configuration
    if (enableCloudProxy) {
      if (cloudProxyUrl.isEmpty) {
        errors.add('Cloud proxy URL cannot be empty');
      }
      if (!cloudProxyUrl.startsWith('http://') &&
          !cloudProxyUrl.startsWith('https://')) {
        errors.add('Cloud proxy URL must start with http:// or https://');
      }
    }

    // Validate API server configuration
    if (enableApiServer) {
      if (apiServerPort <= 0 || apiServerPort > 65535) {
        errors.add('API server port must be between 1 and 65535');
      }
    }

    // Validate health check configuration
    if (healthCheckInterval < 5) {
      errors.add('Health check interval must be at least 5 seconds');
    }
    if (maxRetries < 1) {
      errors.add('Max retries must be at least 1');
    }
    if (retryDelay < 1) {
      errors.add('Retry delay must be at least 1 second');
    }

    // Validate performance configuration
    if (connectionPoolSize < 1) {
      errors.add('Connection pool size must be at least 1');
    }
    if (requestTimeout < 5) {
      errors.add('Request timeout must be at least 5 seconds');
    }

    // Validate log level
    const validLogLevels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
    if (!validLogLevels.contains(logLevel)) {
      errors.add('Log level must be one of: ${validLogLevels.join(', ')}');
    }

    return errors;
  }

  /// Get default configuration
  static TunnelConfig get defaultConfig => const TunnelConfig();

  /// Get development configuration
  static TunnelConfig get developmentConfig => const TunnelConfig(
    logLevel: 'DEBUG',
    healthCheckInterval: 10,
    showNotifications: false,
    startMinimized: false,
  );

  /// Get production configuration
  static TunnelConfig get productionConfig => const TunnelConfig(
    logLevel: 'INFO',
    healthCheckInterval: 60,
    showNotifications: true,
    startMinimized: true,
    autoStartOnBoot: true,
  );
}
