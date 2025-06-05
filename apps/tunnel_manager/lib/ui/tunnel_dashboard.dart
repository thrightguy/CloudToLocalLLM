import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tunnel_service.dart';
import '../services/api_server_service.dart';
import '../services/health_monitor_service.dart';
import '../models/connection_status.dart';

class TunnelDashboard extends StatelessWidget {
  const TunnelDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with controls
          _buildHeader(context),
          const SizedBox(height: 16),

          // Status cards
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatusOverview(context),
                  const SizedBox(height: 16),
                  _buildConnectionCards(context),
                  const SizedBox(height: 16),
                  _buildMetricsSection(context),
                  const SizedBox(height: 16),
                  _buildAlertsSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          'Tunnel Dashboard',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Spacer(),
        Consumer<TunnelService>(
          builder: (context, tunnelService, child) {
            return Row(
              children: [
                ElevatedButton.icon(
                  onPressed: tunnelService.isConnecting
                      ? null
                      : () {
                          tunnelService.reconnect();
                        },
                  icon: tunnelService.isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    tunnelService.isConnecting ? 'Connecting...' : 'Reconnect',
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<HealthMonitorService>(
                  builder: (context, healthService, child) {
                    return ElevatedButton.icon(
                      onPressed: () {
                        healthService.forceHealthCheck();
                      },
                      icon: const Icon(Icons.health_and_safety),
                      label: const Text('Health Check'),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusOverview(BuildContext context) {
    return Consumer3<TunnelService, ApiServerService, HealthMonitorService>(
      builder: (context, tunnelService, apiService, healthService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem(
                        context,
                        'Tunnel Service',
                        tunnelService.isConnected,
                        tunnelService.error,
                      ),
                    ),
                    Expanded(
                      child: _buildStatusItem(
                        context,
                        'API Server',
                        apiService.isRunning,
                        apiService.isRunning ? null : 'Not running',
                      ),
                    ),
                    Expanded(
                      child: _buildStatusItem(
                        context,
                        'Health Monitor',
                        healthService.isHealthy,
                        healthService.healthIssue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String title,
    bool isHealthy,
    String? error,
  ) {
    return Column(
      children: [
        Icon(
          isHealthy ? Icons.check_circle : Icons.error,
          color: isHealthy ? Colors.green : Colors.red,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          isHealthy ? 'Healthy' : (error ?? 'Error'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isHealthy ? Colors.green : Colors.red,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildConnectionCards(BuildContext context) {
    return Consumer<TunnelService>(
      builder: (context, tunnelService, child) {
        final connections = tunnelService.connectionStatus;

        if (connections.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No connections configured',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connections', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...connections.entries.map(
              (entry) => _buildConnectionCard(context, entry.value),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionCard(BuildContext context, ConnectionStatus status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(status.statusIcon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  status.type.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(status.quality.displayName),
                  backgroundColor: _getQualityColor(status.quality),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status.endpoint,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (status.version != null) ...[
                  Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 4),
                  Text('v${status.version}'),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.speed, size: 16),
                const SizedBox(width: 4),
                Text('${status.latency.toStringAsFixed(0)}ms'),
                const SizedBox(width: 16),
                Icon(Icons.model_training, size: 16),
                const SizedBox(width: 4),
                Text('${status.models.length} models'),
              ],
            ),
            if (status.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getQualityColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green.withValues(alpha: 0.2);
      case ConnectionQuality.good:
        return Colors.blue.withValues(alpha: 0.2);
      case ConnectionQuality.poor:
        return Colors.orange.withValues(alpha: 0.2);
      case ConnectionQuality.critical:
        return Colors.red.withValues(alpha: 0.2);
    }
  }

  Widget _buildMetricsSection(BuildContext context) {
    return Consumer<HealthMonitorService>(
      builder: (context, healthService, child) {
        final metrics = healthService.metrics;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        'Requests',
                        '${metrics.totalRequests}',
                        'Total processed',
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        'Success Rate',
                        '${metrics.successRate.toStringAsFixed(1)}%',
                        'Request success',
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        'Avg Latency',
                        '${metrics.averageLatency.toStringAsFixed(0)}ms',
                        'Response time',
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        'Health Score',
                        metrics.healthScore.toStringAsFixed(0),
                        'Overall health',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    String title,
    String value,
    String subtitle,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    return Consumer<HealthMonitorService>(
      builder: (context, healthService, child) {
        final alerts = healthService.alerts;

        if (alerts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Alerts (${alerts.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        healthService.clearAlerts();
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...alerts.map(
                  (alert) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alert,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
