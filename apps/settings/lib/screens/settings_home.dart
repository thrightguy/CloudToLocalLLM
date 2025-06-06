import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../services/settings_service.dart';
import '../services/ollama_service.dart';
import '../services/ipc_client.dart';
import '../config/theme.dart';

/// Main settings home screen
///
/// Provides navigation to different settings categories and displays
/// current system status
class SettingsHome extends StatefulWidget {
  const SettingsHome({super.key});

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudToLocalLLM Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/about'),
            tooltip: 'About',
          ),
        ],
      ),
      body: Consumer3<SettingsService, OllamaService, IPCClient>(
        builder: (context, settings, ollama, ipc, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status overview
                _buildStatusSection(settings, ollama, ipc),
                const SizedBox(height: 24),

                // Settings categories
                _buildSettingsCategories(context),
                const SizedBox(height: 24),

                // Quick actions
                _buildQuickActions(context, ollama, ipc),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(
    SettingsService settings,
    OllamaService ollama,
    IPCClient ipc,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStatusItem('Settings Service', settings.status),
            const SizedBox(height: 8),
            _buildStatusItem('Ollama Service', ollama.status),
            const SizedBox(height: 8),
            _buildStatusItem('Tray Connection', ipc.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String status) {
    final statusColor = SettingsTheme.getStatusColor(status);
    final statusIcon = SettingsTheme.getStatusIcon(status);

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          status,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: statusColor),
        ),
      ],
    );
  }

  Widget _buildSettingsCategories(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings Categories',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        _buildCategoryCard(
          context,
          icon: Icons.wifi,
          title: 'Connection Settings',
          subtitle: 'Configure Ollama and cloud connections',
          onTap: () => context.push('/connection'),
        ),
        const SizedBox(height: 12),
        _buildCategoryCard(
          context,
          icon: Icons.science,
          title: 'Ollama Testing',
          subtitle: 'Test local Ollama models and connectivity',
          onTap: () => context.push('/ollama-test'),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: SettingsTheme.primaryColor, size: 32),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    OllamaService ollama,
    IPCClient ipc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              context,
              icon: Icons.refresh,
              label: 'Test Ollama',
              onPressed: ollama.isConnected ? () => _testOllama(ollama) : null,
            ),
            _buildActionButton(
              context,
              icon: Icons.link,
              label: 'Connect Tray',
              onPressed: !ipc.isConnected ? () => _connectTray(ipc) : null,
            ),
            _buildActionButton(
              context,
              icon: Icons.settings_backup_restore,
              label: 'Reset Settings',
              onPressed: () => _showResetDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _testOllama(OllamaService ollama) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await ollama.testConnection();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Ollama connection successful!'
                : 'Ollama connection failed',
          ),
          backgroundColor: success
              ? SettingsTheme.successColor
              : SettingsTheme.errorColor,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error testing Ollama: $e'),
          backgroundColor: SettingsTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _connectTray(IPCClient ipc) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await ipc.connectToTray();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Connected to tray service!'
                : 'Failed to connect to tray service',
          ),
          backgroundColor: success
              ? SettingsTheme.successColor
              : SettingsTheme.errorColor,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error connecting to tray: $e'),
          backgroundColor: SettingsTheme.errorColor,
        ),
      );
    }
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resetSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SettingsTheme.errorColor,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSettings() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );

    try {
      await settingsService.resetToDefaults();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Settings reset to defaults'),
          backgroundColor: SettingsTheme.successColor,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error resetting settings: $e'),
          backgroundColor: SettingsTheme.errorColor,
        ),
      );
    }
  }
}
