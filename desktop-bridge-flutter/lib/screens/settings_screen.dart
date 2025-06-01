import 'package:flutter/material.dart';
import '../config/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSettingsCard(
              theme,
              'Ollama Configuration',
              [
                _buildSettingItem(
                  theme,
                  'Host',
                  AppConfig.defaultOllamaHost,
                  Icons.computer,
                ),
                _buildSettingItem(
                  theme,
                  'Port',
                  AppConfig.defaultOllamaPort.toString(),
                  Icons.settings_ethernet,
                ),
                _buildSettingItem(
                  theme,
                  'Timeout',
                  '${AppConfig.ollamaTimeout.inSeconds}s',
                  Icons.timer,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSettingsCard(
              theme,
              'Cloud Configuration',
              [
                _buildSettingItem(
                  theme,
                  'WebSocket URL',
                  AppConfig.cloudWebSocketUrl,
                  Icons.cloud,
                ),
                _buildSettingItem(
                  theme,
                  'Auth0 Domain',
                  AppConfig.auth0Domain,
                  Icons.security,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSettingsCard(
              theme,
              'Application',
              [
                _buildSettingItem(
                  theme,
                  'Version',
                  AppConfig.appVersion,
                  Icons.info,
                ),
                _buildSettingItem(
                  theme,
                  'Platform',
                  AppConfig.platformName,
                  Icons.computer,
                ),
                _buildSettingItem(
                  theme,
                  'Environment',
                  AppConfig.environmentName,
                  Icons.settings,
                ),
              ],
            ),
            
            const Spacer(),
            
            Center(
              child: Text(
                'Settings functionality coming soon',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme, String title, List<Widget> children) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(ThemeData theme, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
