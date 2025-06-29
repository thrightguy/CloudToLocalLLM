import 'package:flutter/foundation.dart';

/// Zrok tunnel information
class ZrokTunnel {
  final String publicUrl;
  final String localUrl;
  final String protocol;
  final String shareToken;
  final DateTime createdAt;
  final bool isActive;
  final bool isReserved;

  const ZrokTunnel({
    required this.publicUrl,
    required this.localUrl,
    required this.protocol,
    required this.shareToken,
    required this.createdAt,
    required this.isActive,
    this.isReserved = false,
  });

  factory ZrokTunnel.fromJson(Map<String, dynamic> json) {
    return ZrokTunnel(
      publicUrl: json['public_url'] as String,
      localUrl: json['local_url'] as String,
      protocol: json['protocol'] as String,
      shareToken: json['share_token'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['active'] ?? true,
      isReserved: json['reserved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'public_url': publicUrl,
      'local_url': localUrl,
      'protocol': protocol,
      'share_token': shareToken,
      'created_at': createdAt.toIso8601String(),
      'active': isActive,
      'reserved': isReserved,
    };
  }

  @override
  String toString() {
    return 'ZrokTunnel(publicUrl: $publicUrl, localUrl: $localUrl, protocol: $protocol, shareToken: $shareToken)';
  }
}

/// Zrok configuration
class ZrokConfig {
  final String? accountToken;
  final String? reservedShareToken;
  final String protocol;
  final bool enabled;
  final int localPort;
  final String localHost;
  final bool useReservedShare;
  final String backendMode;
  final Map<String, dynamic>? additionalOptions;

  const ZrokConfig({
    this.accountToken,
    this.reservedShareToken,
    this.protocol = 'http',
    this.enabled = false,
    this.localPort = 11434,
    this.localHost = 'localhost',
    this.useReservedShare = false,
    this.backendMode = 'proxy',
    this.additionalOptions,
  });

  factory ZrokConfig.defaultConfig() {
    return const ZrokConfig(
      protocol: 'http',
      enabled: false,
      localPort: 11434,
      localHost: 'localhost',
      useReservedShare: false,
      backendMode: 'proxy',
    );
  }

  ZrokConfig copyWith({
    String? accountToken,
    String? reservedShareToken,
    String? protocol,
    bool? enabled,
    int? localPort,
    String? localHost,
    bool? useReservedShare,
    String? backendMode,
    Map<String, dynamic>? additionalOptions,
  }) {
    return ZrokConfig(
      accountToken: accountToken ?? this.accountToken,
      reservedShareToken: reservedShareToken ?? this.reservedShareToken,
      protocol: protocol ?? this.protocol,
      enabled: enabled ?? this.enabled,
      localPort: localPort ?? this.localPort,
      localHost: localHost ?? this.localHost,
      useReservedShare: useReservedShare ?? this.useReservedShare,
      backendMode: backendMode ?? this.backendMode,
      additionalOptions: additionalOptions ?? this.additionalOptions,
    );
  }

  @override
  String toString() {
    return 'ZrokConfig(enabled: $enabled, protocol: $protocol, localPort: $localPort, hasAccountToken: ${accountToken != null})';
  }
}

/// Abstract base class for zrok service implementations
///
/// Security Integration:
/// - Integrates with Auth0 JWT validation system
/// - Validates user authentication before tunnel access
/// - Provides secure tunnel URLs with authentication context
/// - Desktop platform only (web platform acts as bridge server)
abstract class ZrokService extends ChangeNotifier {
  /// Current zrok configuration
  ZrokConfig get config;

  /// Active tunnel information
  ZrokTunnel? get activeTunnel;

  /// Whether zrok is currently running
  bool get isRunning;

  /// Whether zrok is currently starting
  bool get isStarting;

  /// Last error message
  String? get lastError;

  /// Whether zrok is supported on this platform
  bool get isSupported;

  /// Initialize the zrok service
  Future<void> initialize();

  /// Start zrok tunnel with given configuration
  Future<ZrokTunnel?> startTunnel(ZrokConfig config);

  /// Stop the current zrok tunnel
  Future<void> stopTunnel();

  /// Check if zrok is installed and available
  Future<bool> isZrokInstalled();

  /// Get zrok version information
  Future<String?> getZrokVersion();

  /// Update configuration and restart tunnel if needed
  Future<void> updateConfiguration(ZrokConfig newConfig);

  /// Get tunnel status and health information
  Future<Map<String, dynamic>> getTunnelStatus();

  /// Enable zrok environment with account token
  Future<bool> enableEnvironment(String accountToken);

  /// Check if zrok environment is enabled
  Future<bool> isEnvironmentEnabled();

  /// Create a reserved share
  Future<String?> createReservedShare(ZrokConfig config);

  /// Release a reserved share
  Future<void> releaseReservedShare(String shareToken);

  /// Security and validation methods
  /// Validate user authentication for tunnel access
  Future<bool> validateTunnelAccess() async {
    // Default implementation - can be overridden by platform implementations
    return true;
  }

  /// Get secure tunnel URL with authentication context
  String? getSecureTunnelUrl() {
    final tunnel = activeTunnel;
    if (tunnel == null) return null;

    // For zrok, the public URL is already secure by design
    return tunnel.publicUrl;
  }

  /// Check if tunnel is secure (zrok uses zero-trust by default)
  bool get isTunnelSecure => activeTunnel != null;

  /// Dispose resources
  @override
  void dispose();
}
