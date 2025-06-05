import 'dart:async';
import 'package:flutter/foundation.dart';

import 'tunnel_service.dart';
import '../models/tunnel_metrics.dart';
import '../models/connection_status.dart';

class HealthMonitorService extends ChangeNotifier {
  TunnelService? _tunnelService;
  Timer? _healthCheckTimer;
  Timer? _metricsTimer;
  Timer? _resourceTimer;

  bool _isRunning = false;
  DateTime? _startTime;

  // Health status
  bool _isHealthy = true;
  String? _healthIssue;
  List<String> _alerts = [];

  // Performance tracking
  final TunnelMetrics _metrics = TunnelMetrics();

  // Alert thresholds
  double _maxLatencyMs = 5000;
  double _maxErrorRate = 10.0; // percentage
  int _maxConsecutiveFailures = 5;
  double _maxMemoryUsageMB = 100.0;
  double _maxCpuUsagePercent = 80.0;

  // Failure tracking
  final Map<String, int> _consecutiveFailures = {};

  // Getters
  bool get isRunning => _isRunning;
  bool get isHealthy => _isHealthy;
  String? get healthIssue => _healthIssue;
  List<String> get alerts => List.unmodifiable(_alerts);
  TunnelMetrics get metrics => _metrics;
  DateTime? get startTime => _startTime;

  // Alert threshold getters
  double get maxLatencyMs => _maxLatencyMs;
  double get maxErrorRate => _maxErrorRate;
  int get maxConsecutiveFailures => _maxConsecutiveFailures;
  double get maxMemoryUsageMB => _maxMemoryUsageMB;
  double get maxCpuUsagePercent => _maxCpuUsagePercent;

  /// Start health monitoring
  Future<void> start(TunnelService tunnelService) async {
    if (_isRunning) {
      debugPrint('Health monitor already running');
      return;
    }

    _tunnelService = tunnelService;
    _isRunning = true;
    _startTime = DateTime.now();
    _metrics.startTime = _startTime!;

    debugPrint('Starting health monitor service...');

    // Start periodic health checks
    _startHealthChecks();

    // Start metrics collection
    _startMetricsCollection();

    // Start resource monitoring
    _startResourceMonitoring();

    debugPrint('Health monitor service started successfully');
    notifyListeners();
  }

  /// Stop health monitoring
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    debugPrint('Stopping health monitor service...');

    _healthCheckTimer?.cancel();
    _metricsTimer?.cancel();
    _resourceTimer?.cancel();

    _isRunning = false;
    _tunnelService = null;

    debugPrint('Health monitor service stopped');
    notifyListeners();
  }

  /// Start periodic health checks
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHealthCheck(),
    );
  }

  /// Start metrics collection
  void _startMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _collectMetrics(),
    );
  }

  /// Start resource monitoring
  void _startResourceMonitoring() {
    _resourceTimer?.cancel();
    _resourceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _monitorResources(),
    );
  }

  /// Perform comprehensive health check
  Future<void> _performHealthCheck() async {
    if (_tunnelService == null) return;

    try {
      final connectionStatus = _tunnelService!.connectionStatus;
      final alerts = <String>[];
      bool healthy = true;

      // Check connection health
      for (final entry in connectionStatus.entries) {
        final type = entry.key;
        final status = entry.value;

        if (!status.isConnected) {
          alerts.add(
            'Connection $type is disconnected: ${status.error ?? "Unknown error"}',
          );
          healthy = false;
          _incrementFailureCount(type);
        } else {
          _resetFailureCount(type);

          // Check latency
          if (status.latency > _maxLatencyMs) {
            alerts.add(
              'High latency on $type: ${status.latency.toStringAsFixed(0)}ms',
            );
            healthy = false;
          }

          // Check error rate
          if (status.requestCount > 0) {
            final errorRate = (status.errorCount / status.requestCount) * 100;
            if (errorRate > _maxErrorRate) {
              alerts.add(
                'High error rate on $type: ${errorRate.toStringAsFixed(1)}%',
              );
              healthy = false;
            }
          }

          // Check connection quality
          if (status.quality == ConnectionQuality.critical) {
            alerts.add('Critical connection quality on $type');
            healthy = false;
          } else if (status.quality == ConnectionQuality.poor) {
            alerts.add('Poor connection quality on $type');
          }
        }

        // Check consecutive failures
        final failures = _consecutiveFailures[type] ?? 0;
        if (failures >= _maxConsecutiveFailures) {
          alerts.add('Too many consecutive failures on $type: $failures');
          healthy = false;
        }
      }

      // Check overall tunnel service health
      if (_tunnelService!.error != null) {
        alerts.add('Tunnel service error: ${_tunnelService!.error}');
        healthy = false;
      }

      // Update health status
      _isHealthy = healthy;
      _healthIssue = healthy ? null : alerts.first;
      _alerts = alerts;

      // Update metrics
      final connectedCount = connectionStatus.values
          .where((s) => s.isConnected)
          .length;
      _metrics.updateConnectionCounts(connectedCount, connectionStatus.length);

      debugPrint(
        'Health check completed: ${healthy ? "Healthy" : "Issues detected"}',
      );
      if (!healthy) {
        debugPrint('Health issues: ${alerts.join(", ")}');
      }
    } catch (e) {
      debugPrint('Health check failed: $e');
      _isHealthy = false;
      _healthIssue = 'Health check failed: $e';
    }

    notifyListeners();
  }

  /// Collect performance metrics
  void _collectMetrics() {
    if (_tunnelService == null) return;

    try {
      final connectionStatus = _tunnelService!.connectionStatus;

      // Update connection metrics
      final connectedCount = connectionStatus.values
          .where((s) => s.isConnected)
          .length;
      _metrics.updateConnectionCounts(connectedCount, connectionStatus.length);

      // Record latencies
      for (final entry in connectionStatus.entries) {
        final type = entry.key;
        final status = entry.value;

        if (status.isConnected && status.latency > 0) {
          _metrics.recordLatency(type, status.latency);
        }
      }

      debugPrint(
        'Metrics collected: $connectedCount/${connectionStatus.length} connections',
      );
    } catch (e) {
      debugPrint('Metrics collection failed: $e');
    }
  }

  /// Monitor system resources
  Future<void> _monitorResources() async {
    try {
      // Get current process info (simplified implementation)

      // Memory usage (simplified - in a real implementation, use platform-specific APIs)
      final memoryUsageMB = await _getMemoryUsage();
      final cpuUsagePercent = await _getCpuUsage();

      _metrics.updateResourceUsage(memoryUsageMB, cpuUsagePercent);

      // Check resource thresholds
      final alerts = <String>[];

      if (memoryUsageMB > _maxMemoryUsageMB) {
        alerts.add('High memory usage: ${memoryUsageMB.toStringAsFixed(1)}MB');
      }

      if (cpuUsagePercent > _maxCpuUsagePercent) {
        alerts.add('High CPU usage: ${cpuUsagePercent.toStringAsFixed(1)}%');
      }

      // Add resource alerts to main alerts list
      _alerts.addAll(alerts);

      if (alerts.isNotEmpty) {
        debugPrint('Resource alerts: ${alerts.join(", ")}');
      }
    } catch (e) {
      debugPrint('Resource monitoring failed: $e');
    }
  }

  /// Get memory usage in MB (simplified implementation)
  Future<double> _getMemoryUsage() async {
    try {
      // This is a simplified implementation
      // In a real app, you'd use platform-specific APIs
      return 25.0; // Placeholder value
    } catch (e) {
      debugPrint('Failed to get memory usage: $e');
      return 0.0;
    }
  }

  /// Get CPU usage percentage (simplified implementation)
  Future<double> _getCpuUsage() async {
    try {
      // This is a simplified implementation
      // In a real app, you'd use platform-specific APIs
      return 5.0; // Placeholder value
    } catch (e) {
      debugPrint('Failed to get CPU usage: $e');
      return 0.0;
    }
  }

  /// Increment failure count for a connection
  void _incrementFailureCount(String connectionType) {
    _consecutiveFailures[connectionType] =
        (_consecutiveFailures[connectionType] ?? 0) + 1;
  }

  /// Reset failure count for a connection
  void _resetFailureCount(String connectionType) {
    _consecutiveFailures.remove(connectionType);
  }

  /// Update alert thresholds
  void updateThresholds({
    double? maxLatencyMs,
    double? maxErrorRate,
    int? maxConsecutiveFailures,
    double? maxMemoryUsageMB,
    double? maxCpuUsagePercent,
  }) {
    if (maxLatencyMs != null) _maxLatencyMs = maxLatencyMs;
    if (maxErrorRate != null) _maxErrorRate = maxErrorRate;
    if (maxConsecutiveFailures != null) {
      _maxConsecutiveFailures = maxConsecutiveFailures;
    }
    if (maxMemoryUsageMB != null) _maxMemoryUsageMB = maxMemoryUsageMB;
    if (maxCpuUsagePercent != null) _maxCpuUsagePercent = maxCpuUsagePercent;

    debugPrint('Health monitor thresholds updated');
    notifyListeners();
  }

  /// Clear all alerts
  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  /// Get health summary
  Map<String, dynamic> getHealthSummary() {
    return {
      'is_running': _isRunning,
      'is_healthy': _isHealthy,
      'health_issue': _healthIssue,
      'alerts_count': _alerts.length,
      'alerts': _alerts,
      'start_time': _startTime?.toIso8601String(),
      'uptime_seconds': _startTime != null
          ? DateTime.now().difference(_startTime!).inSeconds
          : 0,
      'metrics_summary': _metrics.getSummary(),
      'thresholds': {
        'max_latency_ms': _maxLatencyMs,
        'max_error_rate': _maxErrorRate,
        'max_consecutive_failures': _maxConsecutiveFailures,
        'max_memory_usage_mb': _maxMemoryUsageMB,
        'max_cpu_usage_percent': _maxCpuUsagePercent,
      },
      'consecutive_failures': _consecutiveFailures,
    };
  }

  /// Force a health check
  Future<void> forceHealthCheck() async {
    debugPrint('Forcing health check...');
    await _performHealthCheck();
  }

  /// Reset all metrics
  void resetMetrics() {
    _metrics.reset();
    _consecutiveFailures.clear();
    _alerts.clear();
    _isHealthy = true;
    _healthIssue = null;

    debugPrint('Health monitor metrics reset');
    notifyListeners();
  }
}
