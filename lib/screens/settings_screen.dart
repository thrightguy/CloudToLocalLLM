import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/version_service.dart';
import '../services/tunnel_manager_service.dart';
import '../services/ollama_service.dart';
import '../components/modern_card.dart';

/// Modern settings screen with comprehensive configuration options
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  String _selectedTheme = 'dark';
  String _selectedLLMProvider = 'ollama';
  bool _enableNotifications = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > AppConfig.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with gradient background
              Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.headerGradient,
                ),
                child: _buildHeader(context),
              ),

              // Main content with solid background
              Padding(
                padding: EdgeInsets.all(AppTheme.spacingL),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop
                        ? AppConfig.maxContentWidth
                        : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page title
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: AppTheme.textColor,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: AppTheme.spacingL),

                      // Settings sections
                      if (isDesktop)
                        _buildDesktopLayout(context)
                      else
                        _buildMobileLayout(context),

                      SizedBox(height: AppTheme.spacingL),

                      // Version information section
                      _buildVersionSection(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
            ),
          ),

          SizedBox(width: AppTheme.spacingM),

          // Title
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // User menu (same as home screen)
          Consumer<AuthService>(
            builder: (context, authService, child) {
              final user = authService.currentUser;
              return Container(
                padding: EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        user?.initials ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      user?.displayName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildAppearanceSettings(context)),
        SizedBox(width: AppTheme.spacingL),
        Expanded(child: _buildLLMSettings(context)),
        SizedBox(width: AppTheme.spacingL),
        Expanded(child: _buildSystemTraySettings(context)),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildAppearanceSettings(context),
        SizedBox(height: AppTheme.spacingL),
        _buildLLMSettings(context),
        SizedBox(height: AppTheme.spacingL),
        if (!kIsWeb) _buildSystemTraySettings(context),
        if (!kIsWeb) SizedBox(height: AppTheme.spacingL),
        _buildTunnelConnectionSettings(context),
        SizedBox(height: AppTheme.spacingL),
        _buildModelManagementSettings(context),
        SizedBox(height: AppTheme.spacingL),
        _buildPremiumFeaturesSettings(context),
      ],
    );
  }

  Widget _buildAppearanceSettings(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'Appearance',
            Icons.palette,
            AppTheme.primaryColor,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Theme selection
          _buildSettingItem(
            context,
            'Theme',
            'Choose your preferred theme',
            DropdownButton<String>(
              value: _selectedTheme,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
                DropdownMenuItem(value: 'system', child: Text('System')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value ?? 'dark';
                });
              },
            ),
          ),

          SizedBox(height: AppTheme.spacingM),

          // Notifications toggle
          _buildSettingItem(
            context,
            'Notifications',
            'Enable app notifications',
            Switch(
              value: _enableNotifications,
              onChanged: (value) {
                setState(() {
                  _enableNotifications = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLLMSettings(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'LLM Provider',
            Icons.computer,
            AppTheme.secondaryColor,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Provider selection
          _buildSettingItem(
            context,
            'Provider',
            'Choose your LLM provider',
            DropdownButton<String>(
              value: _selectedLLMProvider,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
                DropdownMenuItem(value: 'lmstudio', child: Text('LM Studio')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLLMProvider = value ?? 'ollama';
                });
              },
            ),
          ),

          SizedBox(height: AppTheme.spacingM),

          // Navigate to LLM Provider Settings button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/settings/llm-provider'),
              icon: const Icon(Icons.settings),
              label: const Text('Configure & Test Connection'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(AppTheme.spacingM),
              ),
            ),
          ),

          SizedBox(height: AppTheme.spacingS),

          // Quick info about what's in the detailed settings
          Text(
            'Configure connection settings, test connectivity, and manage models',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTraySettings(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'System Tray',
            Icons.desktop_windows,
            AppTheme.accentColor,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Tray daemon status indicator
          _buildTrayStatusIndicator(context),

          SizedBox(height: AppTheme.spacingM),

          // Launch settings app button
          _buildSettingButton(
            context,
            'Advanced Settings',
            'Configure tray daemon and connections',
            Icons.settings_applications,
            () => _launchTraySettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildTunnelConnectionSettings(BuildContext context) {
    return Consumer<TunnelManagerService>(
      builder: (context, tunnelManager, child) {
        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                'Tunnel Connection',
                Icons.swap_horiz,
                AppTheme.accentColor,
              ),
              SizedBox(height: AppTheme.spacingM),

              // Connection status overview
              _buildConnectionStatusCard(context, tunnelManager),

              SizedBox(height: AppTheme.spacingM),

              // Local Ollama configuration
              _buildOllamaConfigCard(context, tunnelManager),

              SizedBox(height: AppTheme.spacingM),

              // Cloud proxy configuration
              _buildCloudProxyConfigCard(context, tunnelManager),

              SizedBox(height: AppTheme.spacingM),

              // Connection test button
              _buildConnectionTestButton(context, tunnelManager),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: AppTheme.spacingM),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    String description,
    Widget control,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppTheme.spacingXS),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
        ),
        SizedBox(height: AppTheme.spacingS),
        control,
      ],
    );
  }

  Widget _buildTrayStatusIndicator(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: Colors.green, size: 12),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tray Daemon Status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Connected and running',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
      child: Container(
        padding: EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColorLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textColorLight,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeatureItem(
    BuildContext context,
    String title,
    String description,
    String tooltip,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).disabledColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '💎 Premium',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingXS),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).disabledColor,
          ),
        ),
      ],
    );
  }

  void _launchTraySettings() async {
    try {
      // Launch the separate settings application
      final result = await Process.run('cloudtolocalllm-settings', []);
      if (result.exitCode != 0) {
        // Fallback: try to launch from the system path
        await Process.run('python3', ['-m', 'cloudtolocalllm_settings']);
      }
    } catch (e) {
      // Show error dialog if settings app can't be launched
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Settings App Not Available'),
            content: Text(
              'The advanced settings application could not be launched. '
              'Please ensure the system tray daemon is properly installed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Tunnel Connection Helper Methods
  Widget _buildConnectionStatusCard(
    BuildContext context,
    TunnelManagerService tunnelManager,
  ) {
    final isConnected = tunnelManager.isConnected;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.error,
                color: isConnected ? Colors.green : Colors.red,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacingS),
              Text(
                isConnected ? 'Tunnel Connected' : 'Tunnel Disconnected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            isConnected
                ? 'Local Ollama is accessible via cloud proxy tunnel'
                : 'Connection to local Ollama or cloud proxy failed',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOllamaConfigCard(
    BuildContext context,
    TunnelManagerService tunnelManager,
  ) {
    final config = tunnelManager.config;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer, color: AppTheme.secondaryColor, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'Local Ollama Configuration',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),

          _buildSettingItem(
            context,
            'Enable Local Ollama',
            'Connect to local Ollama instance',
            Switch(
              value: config.enableLocalOllama,
              onChanged: (value) {
                // TODO: Update configuration
              },
            ),
          ),

          if (config.enableLocalOllama) ...[
            SizedBox(height: AppTheme.spacingM),
            _buildSettingItem(
              context,
              'Host',
              'Ollama server host address',
              TextFormField(
                initialValue: config.ollamaHost,
                decoration: InputDecoration(
                  hintText: 'localhost',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  // TODO: Update configuration
                },
              ),
            ),

            SizedBox(height: AppTheme.spacingM),
            _buildSettingItem(
              context,
              'Port',
              'Ollama server port',
              TextFormField(
                initialValue: config.ollamaPort.toString(),
                decoration: InputDecoration(
                  hintText: '11434',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  // TODO: Update configuration
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCloudProxyConfigCard(
    BuildContext context,
    TunnelManagerService tunnelManager,
  ) {
    final config = tunnelManager.config;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: Colors.blue, size: 20),
              SizedBox(width: AppTheme.spacingS),
              Text(
                'Cloud Proxy Configuration',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),

          _buildSettingItem(
            context,
            'Enable Cloud Proxy',
            'Connect to CloudToLocalLLM cloud services',
            Switch(
              value: config.enableCloudProxy,
              onChanged: (value) {
                // TODO: Update configuration
              },
            ),
          ),

          if (config.enableCloudProxy) ...[
            SizedBox(height: AppTheme.spacingM),
            _buildSettingItem(
              context,
              'Cloud Proxy URL',
              'Cloud proxy service endpoint',
              TextFormField(
                initialValue: config.cloudProxyUrl,
                decoration: InputDecoration(
                  hintText: 'https://app.cloudtolocalllm.online',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  // TODO: Update configuration
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionTestButton(
    BuildContext context,
    TunnelManagerService tunnelManager,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          // TODO: Implement connection test
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Testing connection...')));
        },
        icon: Icon(Icons.wifi_tethering),
        label: Text('Test Connection'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.all(AppTheme.spacingM),
        ),
      ),
    );
  }

  Widget _buildModelManagementSettings(BuildContext context) {
    return Consumer<OllamaService>(
      builder: (context, ollamaService, child) {
        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                'Model Management',
                Icons.storage,
                AppTheme.primaryColor,
              ),
              SizedBox(height: AppTheme.spacingM),

              // Model download manager info
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: AppTheme.spacingS),
                        Text(
                          'Model Download Manager',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacingS),
                    Text(
                      kIsWeb
                          ? 'Model management available through cloud proxy connection'
                          : 'Download and manage Ollama models directly from the local instance',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppTheme.spacingM),

              // Available models count
              _buildSettingItem(
                context,
                'Available Models',
                'Currently installed Ollama models',
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${ollamaService.models.length} models',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spacingM),

              // Navigate to model management button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to model management screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Model management screen coming soon'),
                      ),
                    );
                  },
                  icon: Icon(Icons.manage_search),
                  label: Text('Manage Models'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(AppTheme.spacingM),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumFeaturesSettings(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'Premium Features',
            Icons.diamond,
            Colors.purple,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Premium features info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.purple, size: 20),
                    SizedBox(width: AppTheme.spacingS),
                    Text(
                      'Premium Features Available',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingS),
                Text(
                  'Advanced cloud sync, mobile app access, and enhanced features for power users',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: AppTheme.spacingM),

          // Premium features list
          _buildPremiumFeatureItem(
            context,
            'Advanced Cloud Sync',
            'Sync settings and preferences across devices',
            'Premium feature - coming soon',
          ),

          SizedBox(height: AppTheme.spacingM),

          _buildPremiumFeatureItem(
            context,
            'Mobile App Access',
            'Access your LLM from mobile devices',
            'Premium feature - coming soon',
          ),

          SizedBox(height: AppTheme.spacingM),

          _buildPremiumFeatureItem(
            context,
            'Remote Access',
            'Allow secure remote access to your LLM',
            'Premium feature - coming soon',
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSection(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'Application Information',
            Icons.info_outline,
            AppTheme.accentColor,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Version display with FutureBuilder
          FutureBuilder<String>(
            future: VersionService.instance.getDisplayVersion(),
            builder: (context, snapshot) {
              return _buildSettingItem(
                context,
                'Version',
                'Current application version and build information',
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tag, color: AppTheme.accentColor, size: 20),
                      SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          snapshot.hasData ? snapshot.data! : 'Loading...',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppTheme.textColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                        ),
                      ),
                      if (snapshot.hasData)
                        IconButton(
                          onPressed: () => _showVersionDetails(context),
                          icon: Icon(
                            Icons.info_outline,
                            color: AppTheme.accentColor,
                            size: 20,
                          ),
                          tooltip: 'Show detailed version information',
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          SizedBox(height: AppTheme.spacingM),

          // Build information
          FutureBuilder<DateTime?>(
            future: VersionService.instance.getBuildDate(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return SizedBox.shrink();
              }

              final buildDate = snapshot.data!;
              final formattedDate =
                  '${buildDate.day}/${buildDate.month}/${buildDate.year} ${buildDate.hour.toString().padLeft(2, '0')}:${buildDate.minute.toString().padLeft(2, '0')}';

              return _buildSettingItem(
                context,
                'Build Date',
                'When this version was compiled',
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.accentColor,
                        size: 20,
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showVersionDetails(BuildContext context) async {
    final versionInfo = await VersionService.instance.getVersionInfo();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.accentColor),
            SizedBox(width: AppTheme.spacingS),
            Text('Version Information'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: versionInfo.entries.map((entry) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        '${entry.key}:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColorLight,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        entry.value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
