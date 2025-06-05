import 'package:json_annotation/json_annotation.dart';

part 'tunnel_metrics.g.dart';

@JsonSerializable()
class TunnelMetrics {
  // Connection metrics
  int connectedCount;
  int totalConnections;
  DateTime startTime;

  // Request metrics
  int totalRequests;
  int successfulRequests;
  int failedRequests;

  // Latency metrics (milliseconds)
  final List<double> _latencyHistory = [];
  final Map<String, List<double>> _connectionLatency = {};

  // Throughput metrics
  int requestsPerSecond;
  double averageLatency;

  // Error tracking
  final Map<String, int> _errorCounts = {};
  DateTime? lastError;

  // Memory and resource usage
  double memoryUsageMB;
  double cpuUsagePercent;

  TunnelMetrics({
    this.connectedCount = 0,
    this.totalConnections = 0,
    DateTime? startTime,
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.requestsPerSecond = 0,
    this.averageLatency = 0.0,
    this.lastError,
    this.memoryUsageMB = 0.0,
    this.cpuUsagePercent = 0.0,
  }) : startTime = startTime ?? DateTime.now();

  /// Create metrics from JSON
  factory TunnelMetrics.fromJson(Map<String, dynamic> json) =>
      _$TunnelMetricsFromJson(json);

  /// Convert metrics to JSON
  Map<String, dynamic> toJson() => _$TunnelMetricsToJson(this);

  /// Record a request latency
  void recordLatency(String connectionType, double latencyMs) {
    _latencyHistory.add(latencyMs);

    // Keep only last 1000 entries
    if (_latencyHistory.length > 1000) {
      _latencyHistory.removeAt(0);
    }

    // Track per-connection latency
    _connectionLatency.putIfAbsent(connectionType, () => []);
    _connectionLatency[connectionType]!.add(latencyMs);

    if (_connectionLatency[connectionType]!.length > 100) {
      _connectionLatency[connectionType]!.removeAt(0);
    }

    // Update average
    _updateAverageLatency();
  }

  /// Record a successful request
  void recordSuccess() {
    totalRequests++;
    successfulRequests++;
    _updateRequestsPerSecond();
  }

  /// Record a failed request
  void recordFailure(String errorType) {
    totalRequests++;
    failedRequests++;
    lastError = DateTime.now();

    _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
    _updateRequestsPerSecond();
  }

  /// Update connection counts
  void updateConnectionCounts(int connected, int total) {
    connectedCount = connected;
    totalConnections = total;
  }

  /// Update resource usage
  void updateResourceUsage(double memoryMB, double cpuPercent) {
    memoryUsageMB = memoryMB;
    cpuUsagePercent = cpuPercent;
  }

  /// Get success rate as percentage
  double get successRate {
    if (totalRequests == 0) return 100.0;
    return (successfulRequests / totalRequests) * 100.0;
  }

  /// Get error rate as percentage
  double get errorRate {
    if (totalRequests == 0) return 0.0;
    return (failedRequests / totalRequests) * 100.0;
  }

  /// Get uptime in seconds
  int get uptimeSeconds {
    return DateTime.now().difference(startTime).inSeconds;
  }

  /// Get uptime percentage (simplified calculation)
  double calculateUptimePercentage(DateTime since) {
    final totalDuration = DateTime.now().difference(since);
    if (totalDuration.inSeconds == 0) return 100.0;

    // Simplified: assume uptime based on connection status
    // In a real implementation, track actual downtime events
    return connectedCount > 0 ? 99.5 : 0.0;
  }

  /// Get latency percentiles
  Map<String, double> getLatencyPercentiles() {
    if (_latencyHistory.isEmpty) {
      return {'p50': 0.0, 'p95': 0.0, 'p99': 0.0};
    }

    final sorted = List<double>.from(_latencyHistory)..sort();

    return {
      'p50': _getPercentile(sorted, 0.5),
      'p95': _getPercentile(sorted, 0.95),
      'p99': _getPercentile(sorted, 0.99),
    };
  }

  /// Get latency percentiles for specific connection
  Map<String, double> getConnectionLatencyPercentiles(String connectionType) {
    final latencies = _connectionLatency[connectionType];
    if (latencies == null || latencies.isEmpty) {
      return {'p50': 0.0, 'p95': 0.0, 'p99': 0.0};
    }

    final sorted = List<double>.from(latencies)..sort();

    return {
      'p50': _getPercentile(sorted, 0.5),
      'p95': _getPercentile(sorted, 0.95),
      'p99': _getPercentile(sorted, 0.99),
    };
  }

  /// Get error counts by type
  Map<String, int> get errorCounts => Map.unmodifiable(_errorCounts);

  /// Get most common error type
  String? get mostCommonError {
    if (_errorCounts.isEmpty) return null;

    return _errorCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get connection health score (0-100)
  double get healthScore {
    double score = 100.0;

    // Reduce score based on error rate
    score -= errorRate;

    // Reduce score based on high latency
    if (averageLatency > 1000) {
      score -= 20;
    } else if (averageLatency > 500) {
      score -= 10;
    }

    // Reduce score based on disconnected connections
    if (totalConnections > 0) {
      final connectionRatio = connectedCount / totalConnections;
      score *= connectionRatio;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Reset all metrics
  void reset() {
    connectedCount = 0;
    totalConnections = 0;
    startTime = DateTime.now();
    totalRequests = 0;
    successfulRequests = 0;
    failedRequests = 0;
    requestsPerSecond = 0;
    averageLatency = 0.0;
    lastError = null;
    memoryUsageMB = 0.0;
    cpuUsagePercent = 0.0;

    _latencyHistory.clear();
    _connectionLatency.clear();
    _errorCounts.clear();
  }

  /// Get comprehensive metrics summary
  Map<String, dynamic> getSummary() {
    return {
      'connections': {
        'connected': connectedCount,
        'total': totalConnections,
        'ratio': totalConnections > 0 ? connectedCount / totalConnections : 0.0,
      },
      'requests': {
        'total': totalRequests,
        'successful': successfulRequests,
        'failed': failedRequests,
        'success_rate': successRate,
        'error_rate': errorRate,
        'requests_per_second': requestsPerSecond,
      },
      'latency': {
        'average': averageLatency,
        'percentiles': getLatencyPercentiles(),
      },
      'errors': {
        'counts': errorCounts,
        'most_common': mostCommonError,
        'last_error': lastError?.toIso8601String(),
      },
      'resources': {'memory_mb': memoryUsageMB, 'cpu_percent': cpuUsagePercent},
      'health': {'score': healthScore, 'uptime_seconds': uptimeSeconds},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Update average latency
  void _updateAverageLatency() {
    if (_latencyHistory.isEmpty) {
      averageLatency = 0.0;
      return;
    }

    final sum = _latencyHistory.reduce((a, b) => a + b);
    averageLatency = sum / _latencyHistory.length;
  }

  /// Update requests per second
  void _updateRequestsPerSecond() {
    final uptimeSeconds = DateTime.now().difference(startTime).inSeconds;
    if (uptimeSeconds > 0) {
      requestsPerSecond = (totalRequests / uptimeSeconds).round();
    }
  }

  /// Calculate percentile from sorted list
  double _getPercentile(List<double> sorted, double percentile) {
    if (sorted.isEmpty) return 0.0;

    final index = (sorted.length * percentile).floor();
    final clampedIndex = index.clamp(0, sorted.length - 1);

    return sorted[clampedIndex];
  }
}
