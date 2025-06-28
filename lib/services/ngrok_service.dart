import 'package:flutter/foundation.dart';

/// Ngrok tunnel information
class NgrokTunnel {
  final String publicUrl;
  final String localUrl;
  final String protocol;
  final String? subdomain;
  final DateTime createdAt;
  final bool isActive;

  const NgrokTunnel({
    required this.publicUrl,
    required this.localUrl,
    required this.protocol,
    this.subdomain,
    required this.createdAt,
    required this.isActive,
  });

  factory NgrokTunnel.fromJson(Map<String, dynamic> json) {
    return NgrokTunnel(
      publicUrl: json['public_url'] as String,
      localUrl: json['config']['addr'] as String,
      protocol: json['proto'] as String,
      subdomain: json['config']['subdomain'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'public_url': publicUrl,
      'local_url': localUrl,
      'protocol': protocol,
      'subdomain': subdomain,
      'created_at': createdAt.toIso8601String(),
      'active': isActive,
    };
  }

  @override
  String toString() {
    return 'NgrokTunnel(publicUrl: $publicUrl, localUrl: $localUrl, protocol: $protocol)';
  }
}

/// Ngrok configuration
class NgrokConfig {
  final String? authToken;
  final String? subdomain;
  final String protocol;
  final bool enabled;
  final int localPort;
  final String localHost;
  final Map<String, dynamic>? additionalOptions;

  const NgrokConfig({
    this.authToken,
    this.subdomain,
    this.protocol = 'http',
    this.enabled = false,
    this.localPort = 11434,
    this.localHost = 'localhost',
    this.additionalOptions,
  });

  factory NgrokConfig.defaultConfig() {
    return const NgrokConfig(
      protocol: 'http',
      enabled: false,
      localPort: 11434,
      localHost: 'localhost',
    );
  }

  NgrokConfig copyWith({
    String? authToken,
    String? subdomain,
    String? protocol,
    bool? enabled,
    int? localPort,
    String? localHost,
    Map<String, dynamic>? additionalOptions,
  }) {
    return NgrokConfig(
      authToken: authToken ?? this.authToken,
      subdomain: subdomain ?? this.subdomain,
      protocol: protocol ?? this.protocol,
      enabled: enabled ?? this.enabled,
      localPort: localPort ?? this.localPort,
      localHost: localHost ?? this.localHost,
      additionalOptions: additionalOptions ?? this.additionalOptions,
    );
  }

  @override
  String toString() {
    return 'NgrokConfig(enabled: $enabled, protocol: $protocol, localPort: $localPort, hasAuthToken: ${authToken != null})';
  }
}

/// Abstract base class for ngrok service implementations
///
/// Security Integration:
/// - Integrates with Auth0 JWT validation system
/// - Validates user authentication before tunnel access
/// - Provides secure tunnel URLs with authentication context
/// - Desktop platform only (web platform acts as bridge server)
abstract class NgrokService extends ChangeNotifier {
  /// Current ngrok configuration
  NgrokConfig get config;

  /// Active tunnel information
  NgrokTunnel? get activeTunnel;

  /// Whether ngrok is currently running
  bool get isRunning;

  /// Whether ngrok is currently starting
  bool get isStarting;

  /// Last error message
  String? get lastError;

  /// Whether ngrok is supported on this platform
  bool get isSupported;

  /// Initialize the ngrok service
  Future<void> initialize();

  /// Start ngrok tunnel with given configuration
  Future<NgrokTunnel?> startTunnel(NgrokConfig config);

  /// Stop the current ngrok tunnel
  Future<void> stopTunnel();

  /// Check if ngrok is installed and available
  Future<bool> isNgrokInstalled();

  /// Get ngrok version information
  Future<String?> getNgrokVersion();

  /// Update configuration and restart tunnel if needed
  Future<void> updateConfiguration(NgrokConfig newConfig);

  /// Get tunnel status and health information
  Future<Map<String, dynamic>> getTunnelStatus();

  /// Dispose resources
  @override
  void dispose();
}
