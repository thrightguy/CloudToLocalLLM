import 'package:json_annotation/json_annotation.dart';

part 'connection_status.g.dart';

@JsonSerializable()
class ConnectionStatus {
  final String type; // 'ollama', 'cloud'
  final bool isConnected;
  final String endpoint;
  final String? version;
  final List<String> models;
  final String? error;
  final DateTime lastCheck;
  final double latency; // milliseconds
  final int requestCount;
  final int errorCount;
  final DateTime? lastError;

  const ConnectionStatus({
    required this.type,
    required this.isConnected,
    required this.endpoint,
    this.version,
    this.models = const [],
    this.error,
    required this.lastCheck,
    this.latency = 0.0,
    this.requestCount = 0,
    this.errorCount = 0,
    this.lastError,
  });

  /// Create connection status from JSON
  factory ConnectionStatus.fromJson(Map<String, dynamic> json) =>
      _$ConnectionStatusFromJson(json);

  /// Convert connection status to JSON
  Map<String, dynamic> toJson() => _$ConnectionStatusToJson(this);

  /// Create a copy with modified values
  ConnectionStatus copyWith({
    String? type,
    bool? isConnected,
    String? endpoint,
    String? version,
    List<String>? models,
    String? error,
    DateTime? lastCheck,
    double? latency,
    int? requestCount,
    int? errorCount,
    DateTime? lastError,
  }) {
    return ConnectionStatus(
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      endpoint: endpoint ?? this.endpoint,
      version: version ?? this.version,
      models: models ?? this.models,
      error: error ?? this.error,
      lastCheck: lastCheck ?? this.lastCheck,
      latency: latency ?? this.latency,
      requestCount: requestCount ?? this.requestCount,
      errorCount: errorCount ?? this.errorCount,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Get connection quality based on latency and error rate
  ConnectionQuality get quality {
    if (!isConnected) return ConnectionQuality.critical;

    final errorRate = requestCount > 0 ? errorCount / requestCount : 0.0;

    if (errorRate > 0.1) return ConnectionQuality.critical; // >10% error rate
    if (latency > 5000) return ConnectionQuality.poor; // >5s latency
    if (latency > 1000 || errorRate > 0.05) {
      return ConnectionQuality.good; // >1s latency or >5% error rate
    }

    return ConnectionQuality.excellent;
  }

  /// Get status icon based on connection state
  String get statusIcon {
    if (!isConnected) return '❌';

    switch (quality) {
      case ConnectionQuality.excellent:
        return '✅';
      case ConnectionQuality.good:
        return '🟡';
      case ConnectionQuality.poor:
        return '🟠';
      case ConnectionQuality.critical:
        return '🔴';
    }
  }

  /// Get human-readable status description
  String get statusDescription {
    if (!isConnected) {
      return error ?? 'Disconnected';
    }

    final modelCount = models.length;
    final latencyMs = latency.round();

    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Connected ($latencyMs ms, $modelCount models)';
      case ConnectionQuality.good:
        return 'Connected - Good ($latencyMs ms, $modelCount models)';
      case ConnectionQuality.poor:
        return 'Connected - Poor ($latencyMs ms, $modelCount models)';
      case ConnectionQuality.critical:
        return 'Connected - Critical ($latencyMs ms, $modelCount models)';
    }
  }

  /// Get uptime percentage for this connection
  double getUptimePercentage(DateTime since) {
    final totalDuration = DateTime.now().difference(since);
    if (totalDuration.inSeconds == 0) return 100.0;

    // This is a simplified calculation
    // In a real implementation, you'd track connection/disconnection events
    return isConnected ? 100.0 : 0.0;
  }

  /// Check if connection needs attention
  bool get needsAttention {
    if (!isConnected) return true;
    if (quality == ConnectionQuality.critical) return true;
    if (quality == ConnectionQuality.poor) return true;

    // Check if last check was too long ago
    final timeSinceLastCheck = DateTime.now().difference(lastCheck);
    if (timeSinceLastCheck.inMinutes > 5) return true;

    return false;
  }

  /// Get connection age
  Duration get connectionAge {
    return DateTime.now().difference(lastCheck);
  }

  /// Create a disconnected status
  static ConnectionStatus disconnected(
    String type,
    String endpoint, {
    String? error,
  }) {
    return ConnectionStatus(
      type: type,
      isConnected: false,
      endpoint: endpoint,
      error: error,
      lastCheck: DateTime.now(),
    );
  }

  /// Create a connected status
  static ConnectionStatus connected(
    String type,
    String endpoint, {
    String? version,
    List<String> models = const [],
    double latency = 0.0,
  }) {
    return ConnectionStatus(
      type: type,
      isConnected: true,
      endpoint: endpoint,
      version: version,
      models: models,
      lastCheck: DateTime.now(),
      latency: latency,
    );
  }
}

/// Connection quality levels
enum ConnectionQuality { excellent, good, poor, critical }

/// Extension for connection quality
extension ConnectionQualityExtension on ConnectionQuality {
  String get displayName {
    switch (this) {
      case ConnectionQuality.excellent:
        return 'Excellent';
      case ConnectionQuality.good:
        return 'Good';
      case ConnectionQuality.poor:
        return 'Poor';
      case ConnectionQuality.critical:
        return 'Critical';
    }
  }

  String get description {
    switch (this) {
      case ConnectionQuality.excellent:
        return 'Low latency, no errors';
      case ConnectionQuality.good:
        return 'Acceptable latency, minimal errors';
      case ConnectionQuality.poor:
        return 'High latency or some errors';
      case ConnectionQuality.critical:
        return 'Very high latency or many errors';
    }
  }
}
