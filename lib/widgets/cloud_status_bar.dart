import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/tunnel_service.dart';
import '../config/app_config.dart';

class CloudStatusBar extends StatelessWidget {
  const CloudStatusBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Access the services through provider
    final authService = Provider.of<AuthService>(context);
    final tunnelService = Provider.of<TunnelService>(context, listen: true);

    // Get the current theme
    final theme = Theme.of(context);

    return Container(
      height: 28,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Authentication status
          _buildStatusIndicator(
            context,
            label: 'Cloud',
            isActive: authService.isAuthenticated.value,
            activeIcon: Icons.cloud_done,
            inactiveIcon: Icons.cloud_off,
            activeTooltip: 'Connected to Cloud',
            inactiveTooltip: 'Not connected to Cloud',
          ),

          const SizedBox(width: 12),

          // Tunnel status
          _buildStatusIndicator(
            context,
            label: 'Tunnel',
            isActive: tunnelService.isConnected.value,
            activeIcon: Icons.travel_explore,
            inactiveIcon: Icons.link_off,
            activeTooltip: 'Tunnel active',
            inactiveTooltip: 'Tunnel not active',
          ),

          const Spacer(),

          // Cloud service name and version
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'CloudToLocalLLM v${AppConfig.appVersion} (${AppConfig.buildNumber})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context, {
    required String label,
    required bool isActive,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String activeTooltip,
    required String inactiveTooltip,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: isActive ? activeTooltip : inactiveTooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              size: 16,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
