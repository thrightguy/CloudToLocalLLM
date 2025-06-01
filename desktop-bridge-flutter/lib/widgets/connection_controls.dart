import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state_provider.dart';
import '../services/tunnel_service.dart';

class ConnectionControls extends ConsumerWidget {
  final AppState appState;

  const ConnectionControls({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tunnelService = ref.read(tunnelServiceProvider);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildConnectButton(context, tunnelService),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDisconnectButton(context, tunnelService),
                ),
              ],
            ),
            
            if (appState.tunnelStatus == TunnelStatus.reconnecting) ...[
              const SizedBox(height: 12),
              _buildReconnectingIndicator(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context, TunnelService tunnelService) {
    final theme = Theme.of(context);
    final isEnabled = appState.isAuthenticated && 
                     !appState.isConnected && 
                     appState.tunnelStatus != TunnelStatus.connecting &&
                     appState.tunnelStatus != TunnelStatus.reconnecting;

    return ElevatedButton.icon(
      onPressed: isEnabled ? () => _handleConnect(tunnelService) : null,
      icon: Icon(
        appState.tunnelStatus == TunnelStatus.connecting 
            ? Icons.hourglass_empty 
            : Icons.cloud_upload,
        size: 18,
      ),
      label: Text(
        appState.tunnelStatus == TunnelStatus.connecting 
            ? 'Connecting...' 
            : 'Connect',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildDisconnectButton(BuildContext context, TunnelService tunnelService) {
    final theme = Theme.of(context);
    final isEnabled = appState.isConnected || 
                     appState.tunnelStatus == TunnelStatus.connecting ||
                     appState.tunnelStatus == TunnelStatus.reconnecting;

    return OutlinedButton.icon(
      onPressed: isEnabled ? () => _handleDisconnect(tunnelService) : null,
      icon: const Icon(Icons.cloud_off, size: 18),
      label: const Text('Disconnect'),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.error,
        side: BorderSide(color: theme.colorScheme.error),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildReconnectingIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Attempting to reconnect to cloud relay...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleConnect(TunnelService tunnelService) async {
    try {
      await tunnelService.connect();
    } catch (e) {
      // Error handling is done in the service
    }
  }

  void _handleDisconnect(TunnelService tunnelService) async {
    try {
      await tunnelService.disconnect();
    } catch (e) {
      // Error handling is done in the service
    }
  }
}
