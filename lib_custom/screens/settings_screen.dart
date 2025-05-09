import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/section_header.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../widgets/version_info_footer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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

          // Windows-specific LLM management
          if (Platform.isWindows)
            _buildSection(
              title: 'LLM Management',
              children: [
                _buildWindowsLlmStatus(settingsProvider),
                _buildSwitchTile(
                  title: 'Auto-start LLM on Launch',
                  subtitle: 'Automatically start the LLM when the app launches',
                  value: settingsProvider.autoStartLlm,
                  onChanged: (value) {
                    settingsProvider.setAutoStartLlm(value);
                  },
                ),
                _buildSwitchTile(
                  title: 'Install as Windows Service',
                  subtitle: 'Run Ollama as a Windows service (recommended)',
                  value: settingsProvider.installAsService,
                  onChanged: (value) {
                    settingsProvider.setInstallAsService(value);
                  },
                ),
                OverflowBar(
                  spacing: 8,
                  alignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        if (!mounted) return;
                        final settingsProvider = Provider.of<SettingsProvider>(
                            context,
                            listen: false);
                        final messenger = ScaffoldMessenger.of(context);

                        final result = await settingsProvider.startLlm();
                        if (!mounted) return;
                        if (!result) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Failed to start LLM. Please check installation.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Start LLM'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (!mounted) return;
                        final settingsProvider = Provider.of<SettingsProvider>(
                            context,
                            listen: false);
                        final messenger = ScaffoldMessenger.of(context);

                        final result = await settingsProvider.stopLlm();
                        if (!mounted) return;
                        if (!result) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Failed to stop LLM.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Stop LLM'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (!mounted) return;
                        final settingsProvider = Provider.of<SettingsProvider>(
                            context,
                            listen: false);
                        final messenger = ScaffoldMessenger.of(context);

                        final result =
                            await settingsProvider.installLlmAsService();
                        if (!mounted) return;
                        if (!result) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Failed to install LLM as a service. Try running as administrator.'),
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Successfully installed LLM as a Windows service.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Install as Service'),
                    ),
                  ],
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
                        if (settingsProvider.isTunnelConnected &&
                            settingsProvider.tunnelUrl.isNotEmpty) ...[
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
                            if (!mounted) return;
                            final settingsProvider =
                                Provider.of<SettingsProvider>(context,
                                    listen: false);
                            final messenger = ScaffoldMessenger.of(context);

                            final result =
                                await settingsProvider.checkTunnelStatus();
                            if (!mounted) return;
                            if (!result) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Failed to connect to tunnel. Make sure you are logged in.'),
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
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
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
                subtitle: VersionInfoFooter(
                  showBuild: true,
                  isDiscrete: false,
                  padding: EdgeInsets.zero,
                ),
                onTap: () {
                  // Show about dialog
                  showAboutDialog(
                    context: context,
                    applicationName: 'CloudToLocalLLM',
                    applicationVersion:
                        'v${AppConfig.appVersion} (${AppConfig.buildNumber})',
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                _showResetSettingsDialog();
              }
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem<String>(
                  value: 'reset',
                  child: Text('Reset Settings'),
                ),
              ];
            },
            child: OverflowBar(
              children: [
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
          ),

          // Container management settings
          _buildContainerManagementSettings(),
        ],
      ),
    );
  }

  // Build a section with a title and children
  Widget _buildSection(
      {required String title, required List<Widget> children}) {
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
    return ListTile(
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
    );
  }

  // Build Windows LLM status card
  Widget _buildWindowsLlmStatus(SettingsProvider settingsProvider) {
    final isRunning = settingsProvider.llmProvider == 'ollama'
        ? settingsProvider.isOllamaRunning
        : settingsProvider.isLmStudioRunning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRunning ? Icons.check_circle : Icons.error,
                  color: isRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'LLM Status: ${isRunning ? 'Running' : 'Stopped'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isRunning ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Provider: ${settingsProvider.llmProvider}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (settingsProvider.llmProvider == 'ollama' &&
                settingsProvider.ollamaVersion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Version: ${settingsProvider.ollamaVersion}'),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await settingsProvider.checkLlmStatus();
              },
              child: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
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
        content: const Text(
            'Are you sure you want to reset all settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<SettingsProvider>(context, listen: false)
                  .resetSettings();
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

  Widget _buildContainerManagementSettings() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Container Management'),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Consumer<OnboardingProvider>(
                      builder: (context, provider, _) {
                        final containerStatus =
                            provider.containerStatus ?? 'unknown';
                        final isReady = provider.containerReady;

                        return Expanded(
                          child: Row(
                            children: [
                              Icon(
                                isReady ? Icons.check_circle : Icons.pending,
                                color: isReady ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Container status: $containerStatus',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh status',
                      onPressed: () {
                        final provider = Provider.of<OnboardingProvider>(
                          context,
                          listen: false,
                        );
                        provider.checkContainerStatus();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your secure container is where your cloud resources are managed.',
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset Container'),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reset Container?'),
                            content: const Text(
                              'This will delete your container and all data inside it. '
                              'You will need to generate a new API key. This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          if (!mounted) return;
                          final provider = Provider.of<OnboardingProvider>(
                            context,
                            listen: false,
                          );
                          final messenger = ScaffoldMessenger.of(context);

                          await provider.resetApiKey();

                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Container reset. Please generate a new API key.'),
                            ),
                          );
                        }
                      },
                    ),
                    Consumer<OnboardingProvider>(
                      builder: (context, provider, _) {
                        if (provider.apiKey == null) {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.key),
                            label: const Text('Generate API Key'),
                            onPressed: provider.isLoading
                                ? null
                                : () async {
                                    if (!mounted) return;
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    try {
                                      await provider.generateApiKey();
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'API key generated successfully.'),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                          );
                        } else {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy API Key'),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: provider.apiKey!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('API key copied to clipboard'),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
