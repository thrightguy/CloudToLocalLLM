import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'login_screen.dart';
import 'provider_installation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme settings
          _buildSection(
            title: 'Appearance',
            children: [
              _buildThemeSelector(settingsProvider),
            ],
          ),

          // LLM settings
          _buildSection(
            title: 'LLM Settings',
            children: [
              _buildLlmProviderSelector(settingsProvider),
              _buildSwitchTile(
                title: 'Enable Model Download',
                subtitle: 'Allow downloading models from the cloud',
                value: settingsProvider.enableModelDownload,
                onChanged: (value) {
                  settingsProvider.setEnableModelDownload(value);
                },
              ),
              _buildSwitchTile(
                title: 'Enable Offline Mode',
                subtitle: 'Use local models only, no cloud connectivity',
                value: settingsProvider.enableOfflineMode,
                onChanged: (value) {
                  settingsProvider.setEnableOfflineMode(value);
                },
              ),
            ],
          ),

          // Cloud settings
          _buildSection(
            title: 'Cloud Settings',
            children: [
              _buildSwitchTile(
                title: 'Enable Cloud Sync',
                subtitle: 'Sync conversations and settings with the cloud',
                value: settingsProvider.enableCloudSync,
                onChanged: (value) {
                  settingsProvider.setEnableCloudSync(value);
                },
              ),
              _buildSwitchTile(
                title: 'Enable Remote Access',
                subtitle: 'Allow accessing your local LLM from the cloud',
                value: settingsProvider.enableTunnel,
                onChanged: (value) {
                  settingsProvider.setEnableTunnel(value);
                },
              ),
              if (settingsProvider.enableTunnel) ...[
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              settingsProvider.isTunnelConnected
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: settingsProvider.isTunnelConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tunnel Status: ${settingsProvider.isTunnelConnected ? 'Connected' : 'Disconnected'}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: settingsProvider.isTunnelConnected
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (settingsProvider.isTunnelConnected && settingsProvider.tunnelUrl.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Your LLM is accessible at:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(settingsProvider.tunnelUrl),
                          const SizedBox(height: 8),
                          const Text(
                            'Note: You need to be logged in to access your LLM remotely.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final result = await settingsProvider.checkTunnelStatus();
                            if (!result && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to connect to tunnel. Make sure you are logged in.'),
                                ),
                              );
                            }
                          },
                          child: const Text('Check Status'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Account settings
          _buildSection(
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Account'),
                subtitle: Text(
                  authProvider.isAuthenticated
                      ? 'Logged in as: ${authProvider.currentUser?.name ?? authProvider.currentUser?.email ?? "User"}'
                      : 'Not logged in',
                ),
                trailing: TextButton(
                  onPressed: () {
                    if (authProvider.isAuthenticated) {
                      _showLogoutDialog();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    }
                  },
                  child: Text(
                    authProvider.isAuthenticated ? 'Logout' : 'Login',
                  ),
                ),
              ),
            ],
          ),

          // About section
          _buildSection(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('CloudToLocalLLM'),
                subtitle: const Text('Version 1.0.0'),
                onTap: () {
                  // Show about dialog
                  showAboutDialog(
                    context: context,
                    applicationName: 'CloudToLocalLLM',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(
                      Icons.cloud_sync,
                      size: 50,
                      color: Colors.blue,
                    ),
                    applicationLegalese: '© 2025 CloudToLocalLLM',
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'CloudToLocalLLM is an application that bridges the gap between cloud-based applications and local large language models (LLMs).',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          // Reset settings button
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showResetSettingsDialog,
            icon: const Icon(Icons.restore),
            label: const Text('Reset Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Build a section with a title and children
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Build a switch tile
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  // Build theme selector
  Widget _buildThemeSelector(SettingsProvider settingsProvider) {
    return ListTile(
      title: const Text('Theme'),
      subtitle: const Text('Choose the app theme'),
      trailing: DropdownButton<ThemeMode>(
        value: settingsProvider.themeMode,
        onChanged: (ThemeMode? newValue) {
          if (newValue != null) {
            settingsProvider.setThemeMode(newValue);
          }
        },
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('System'),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('Light'),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('Dark'),
          ),
        ],
      ),
    );
  }

  // Build LLM provider selector
  Widget _buildLlmProviderSelector(SettingsProvider settingsProvider) {
    return Column(
      children: [
        ListTile(
          title: const Text('LLM Provider'),
          subtitle: const Text('Choose the default LLM provider'),
          trailing: DropdownButton<String>(
            value: settingsProvider.llmProvider,
            onChanged: (String? newValue) {
              if (newValue != null) {
                settingsProvider.setLlmProvider(newValue);
              }
            },
            items: const [
              DropdownMenuItem(
                value: 'ollama',
                child: Text('Ollama'),
              ),
              DropdownMenuItem(
                value: 'lmstudio',
                child: Text('LM Studio'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderInstallationScreen(provider: 'ollama'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Setup Ollama'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderInstallationScreen(provider: 'lmstudio'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Setup LM Studio'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Show logout confirmation dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Show reset settings confirmation dialog
  void _showResetSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<SettingsProvider>(context, listen: false).resetSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
