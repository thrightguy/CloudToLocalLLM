import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../providers/app_state_provider.dart';
import '../services/tunnel_service.dart';
import '../widgets/status_card.dart';
import '../widgets/connection_controls.dart';
import '../widgets/auth_controls.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.cloud_sync,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              AppConfig.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.minimize),
            onPressed: () => _minimizeToTray(),
            tooltip: 'Minimize to tray',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _closeToTray(),
            tooltip: 'Close to tray',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            StatusCard(appState: appState),
            
            const SizedBox(height: 16),
            
            // Connection Controls
            ConnectionControls(appState: appState),
            
            const SizedBox(height: 16),
            
            // Authentication Controls
            AuthControls(appState: appState),
            
            const Spacer(),
            
            // Footer
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            'Version ${AppConfig.appVersion}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _openHomepage(),
            child: Text(
              AppConfig.homepageUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).pushNamed('/settings');
  }

  void _minimizeToTray() async {
    await windowManager.hide();
  }

  void _closeToTray() async {
    await windowManager.hide();
  }

  void _openHomepage() {
    // TODO: Implement URL launcher
  }
}
