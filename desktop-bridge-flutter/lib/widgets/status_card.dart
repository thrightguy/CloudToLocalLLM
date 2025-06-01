import 'package:flutter/material.dart';
import '../providers/app_state_provider.dart';
import '../services/tunnel_service.dart';

class StatusCard extends StatelessWidget {
  final AppState appState;

  const StatusCard({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bridge Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appState.statusText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getStatusColor(theme),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (appState.hasError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appState.primaryError ?? 'Unknown error',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Status details
            _buildStatusDetails(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    IconData iconData;
    Color iconColor;

    if (appState.hasError) {
      iconData = Icons.error;
      iconColor = theme.colorScheme.error;
    } else if (appState.isConnected) {
      iconData = Icons.cloud_done;
      iconColor = Colors.green;
    } else if (appState.tunnelStatus == TunnelStatus.connecting ||
               appState.tunnelStatus == TunnelStatus.reconnecting) {
      iconData = Icons.cloud_sync;
      iconColor = theme.colorScheme.primary;
    } else if (appState.isAuthenticated) {
      iconData = Icons.cloud_off;
      iconColor = Colors.orange;
    } else {
      iconData = Icons.cloud_off;
      iconColor = theme.colorScheme.onSurface.withOpacity(0.5);
    }

    Widget icon = Icon(
      iconData,
      color: iconColor,
      size: 32,
    );

    // Add animation for connecting states
    if (appState.tunnelStatus == TunnelStatus.connecting ||
        appState.tunnelStatus == TunnelStatus.reconnecting ||
        appState.authLoading) {
      icon = AnimatedRotation(
        turns: 1,
        duration: const Duration(seconds: 2),
        child: icon,
      );
    }

    return icon;
  }

  Color _getStatusColor(ThemeData theme) {
    if (appState.hasError) {
      return theme.colorScheme.error;
    } else if (appState.isConnected) {
      return Colors.green;
    } else if (appState.tunnelStatus == TunnelStatus.connecting ||
               appState.tunnelStatus == TunnelStatus.reconnecting) {
      return theme.colorScheme.primary;
    } else if (appState.isAuthenticated) {
      return Colors.orange;
    } else {
      return theme.colorScheme.onSurface.withOpacity(0.7);
    }
  }

  Widget _buildStatusDetails(ThemeData theme) {
    return Column(
      children: [
        _buildStatusRow(
          theme,
          'Authentication',
          appState.isAuthenticated ? 'Authenticated' : 'Not authenticated',
          appState.isAuthenticated ? Icons.check_circle : Icons.cancel,
          appState.isAuthenticated ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 8),
        _buildStatusRow(
          theme,
          'Cloud Connection',
          _getConnectionStatusText(),
          _getConnectionStatusIcon(),
          _getConnectionStatusColor(theme),
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getConnectionStatusText() {
    switch (appState.tunnelStatus) {
      case TunnelStatus.disconnected:
        return 'Disconnected';
      case TunnelStatus.connecting:
        return 'Connecting...';
      case TunnelStatus.connected:
        return 'Connected';
      case TunnelStatus.reconnecting:
        return 'Reconnecting...';
      case TunnelStatus.error:
        return 'Error';
    }
  }

  IconData _getConnectionStatusIcon() {
    switch (appState.tunnelStatus) {
      case TunnelStatus.disconnected:
        return Icons.cloud_off;
      case TunnelStatus.connecting:
      case TunnelStatus.reconnecting:
        return Icons.cloud_sync;
      case TunnelStatus.connected:
        return Icons.cloud_done;
      case TunnelStatus.error:
        return Icons.error;
    }
  }

  Color _getConnectionStatusColor(ThemeData theme) {
    switch (appState.tunnelStatus) {
      case TunnelStatus.disconnected:
        return Colors.grey;
      case TunnelStatus.connecting:
      case TunnelStatus.reconnecting:
        return theme.colorScheme.primary;
      case TunnelStatus.connected:
        return Colors.green;
      case TunnelStatus.error:
        return theme.colorScheme.error;
    }
  }
}
