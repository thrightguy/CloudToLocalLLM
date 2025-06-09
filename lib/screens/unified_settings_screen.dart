import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';
import '../config/app_config.dart';
import '../components/settings_sidebar.dart';
import '../components/app_header.dart';
import '../components/modern_card.dart';
import '../services/version_service.dart';
import '../services/auth_service.dart';
import '../services/tunnel_manager_service.dart';

/// Unified Settings Screen for CloudToLocalLLM v3.3.1+
///
/// Redesigned settings interface that matches the chat interface layout
/// with a sidebar for settings sections and a main content area.
/// This provides a consistent user experience across the application.
class UnifiedSettingsScreen extends StatefulWidget {
  const UnifiedSettingsScreen({super.key});

  @override
  State<UnifiedSettingsScreen> createState() => _UnifiedSettingsScreenState();
}

class _UnifiedSettingsScreenState extends State<UnifiedSettingsScreen> {
  String _selectedSectionId = 'general';
  bool _isSidebarCollapsed = false;

  // Settings state
  String _selectedTheme = 'dark';
  bool _enableNotifications = true;
  bool _enableSystemTray = true;
  bool _startMinimized = false;

  // Connection monitoring state (for web platform)
  bool _isTestingConnection = false;
  bool _showAdvancedSettings = false;
  String? _connectionError;
  DateTime? _lastConnectionTest;
  double? _connectionLatency;
  List<String> _availableModels = [];
  bool _isLoadingModels = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Load current settings from preferences/storage
    // This would typically load from a configuration service
    setState(() {
      _selectedTheme = 'dark';
      _enableNotifications = true;
      _enableSystemTray = true;
      _startMinimized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppConfig.mobileBreakpoint;

    // Auto-collapse sidebar on mobile
    if (isMobile && !_isSidebarCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isSidebarCollapsed = true;
        });
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient background (matching chat interface)
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
              ),
              child: AppHeader(
                title: 'Settings',
                showBackButton: true,
                onBackPressed: () => context.go('/'),
                actions: [
                  // Sidebar toggle for mobile
                  if (isMobile)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isSidebarCollapsed = !_isSidebarCollapsed;
                        });
                      },
                      icon: Icon(
                        _isSidebarCollapsed ? Icons.menu : Icons.menu_open,
                        color: Colors.white,
                      ),
                      tooltip: _isSidebarCollapsed ? 'Show Menu' : 'Hide Menu',
                    ),
                ],
              ),
            ),

            // Main settings interface (matching chat layout)
            Expanded(
              child: Row(
                children: [
                  // Settings sidebar (like conversation list)
                  if (!isMobile || !_isSidebarCollapsed)
                    SettingsSidebar(
                      sections: SettingsSidebar.defaultSections,
                      selectedSectionId: _selectedSectionId,
                      onSectionSelected: (sectionId) {
                        setState(() {
                          _selectedSectionId = sectionId;
                        });
                        // Auto-collapse sidebar on mobile after selection
                        if (isMobile) {
                          setState(() {
                            _isSidebarCollapsed = true;
                          });
                        }
                      },
                      isCollapsed: false,
                    ),

                  // Main settings content area (like chat area)
                  Expanded(child: _buildSettingsContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Container(
      color: AppTheme.backgroundMain,
      child: Column(
        children: [
          // Ensure content starts at the top and fills available space
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: AppTheme.spacingL,
                right: AppTheme.spacingL,
                top: AppTheme.spacingM, // Small top padding for breathing room
                bottom: AppTheme.spacingL,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppConfig.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(),
                    SizedBox(height: AppTheme.spacingL),
                    _buildSectionContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    final section = SettingsSidebar.defaultSections.firstWhere(
      (s) => s.id == _selectedSectionId,
    );

    return Row(
      children: [
        Icon(section.icon, color: AppTheme.primaryColor, size: 32),
        SizedBox(width: AppTheme.spacingM),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            if (section.subtitle != null)
              Text(
                section.subtitle!,
                style: TextStyle(fontSize: 16, color: AppTheme.textColorLight),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSectionId) {
      case 'general':
        return _buildGeneralSettings();
      case 'appearance':
        return _buildAppearanceSettings();
      case 'llm-provider':
        return _buildLLMProviderSettings();
      case 'system-tray':
        return _buildSystemTraySettings();
      case 'cloud-sync':
        return _buildCloudSyncSettings();
      case 'about':
        return _buildAboutSettings();
      default:
        return _buildGeneralSettings();
    }
  }

  Widget _buildGeneralSettings() {
    return Column(
      children: [
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme setting (consolidated from Appearance)
              _buildSettingItem(
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
              const Divider(),
              _buildSettingItem(
                'Enable Notifications',
                'Show system notifications for important events',
                Switch(
                  value: _enableNotifications,
                  onChanged: (value) {
                    setState(() {
                      _enableNotifications = value;
                    });
                  },
                ),
              ),
              // Start minimized setting - Desktop only
              if (!kIsWeb) ...[
                const Divider(),
                _buildSettingItem(
                  'Start Minimized',
                  'Start application minimized to system tray',
                  Switch(
                    value: _startMinimized,
                    onChanged: (value) {
                      setState(() {
                        _startMinimized = value;
                      });
                    },
                  ),
                ),
              ],
              // System tray setting (consolidated from System Tray) - Desktop only
              if (!kIsWeb) ...[
                const Divider(),
                _buildSettingItem(
                  'Enable System Tray',
                  'Show CloudToLocalLLM icon in system tray',
                  Switch(
                    value: _enableSystemTray,
                    onChanged: (value) {
                      setState(() {
                        _enableSystemTray = value;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return Column(
      children: [
        ModernCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                Icon(Icons.palette, size: 64, color: AppTheme.textColorLight),
                SizedBox(height: AppTheme.spacingM),
                Text(
                  'Theme settings have been moved to the General section for easier access.',
                  style: TextStyle(color: AppTheme.textColorLight),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spacingM),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSectionId = 'general';
                    });
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Go to General Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(AppTheme.spacingM),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLLMProviderSettings() {
    if (kIsWeb) {
      return _buildWebLLMProviderSettings();
    } else {
      return _buildDesktopLLMProviderSettings();
    }
  }

  Widget _buildWebLLMProviderSettings() {
    return Column(
      children: [
        // Connection Status Card
        _buildWebConnectionStatusCard(),
        SizedBox(height: AppTheme.spacingM),

        // Tunnel Configuration Card
        _buildWebTunnelConfigCard(),
        SizedBox(height: AppTheme.spacingM),

        // Advanced Settings Card (expandable)
        _buildWebAdvancedSettingsCard(),
      ],
    );
  }

  Widget _buildDesktopLLMProviderSettings() {
    return Consumer<TunnelManagerService>(
      builder: (context, tunnelManager, child) {
        return Column(
          children: [
            // Connection Status Overview Card
            _buildDesktopConnectionStatusCard(tunnelManager),
            SizedBox(height: AppTheme.spacingM),

            // Local Ollama Configuration Card
            _buildDesktopOllamaConfigCard(tunnelManager),
            SizedBox(height: AppTheme.spacingM),

            // Cloud Proxy Configuration Card
            _buildDesktopCloudProxyConfigCard(tunnelManager),
            SizedBox(height: AppTheme.spacingM),

            // Advanced Tunnel Settings Card
            _buildDesktopAdvancedTunnelCard(tunnelManager),
          ],
        );
      },
    );
  }

  Widget _buildSystemTraySettings() {
    return Column(
      children: [
        ModernCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                Icon(
                  Icons.desktop_windows,
                  size: 64,
                  color: AppTheme.textColorLight,
                ),
                SizedBox(height: AppTheme.spacingM),
                Text(
                  'Basic system tray settings have been moved to the General section. Advanced tray configuration options will be available here in future updates.',
                  style: TextStyle(color: AppTheme.textColorLight),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spacingM),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSectionId = 'general';
                    });
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Go to General Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(AppTheme.spacingM),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloudSyncSettings() {
    return Column(
      children: [
        ModernCard(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                Icon(Icons.cloud, size: 64, color: AppTheme.textColorLight),
                SizedBox(height: AppTheme.spacingM),
                Text(
                  kIsWeb
                      ? 'Premium Features: Cloud storage, sync across devices, mobile access. Local streaming handled automatically.'
                      : 'Core Feature: Secure tunnel streaming provides web access to local LLM. Premium: cloud storage, sync, mobile access.',
                  style: TextStyle(color: AppTheme.textColorLight),
                  textAlign: TextAlign.center,
                ),
                if (!kIsWeb) ...[
                  SizedBox(height: AppTheme.spacingM),
                  Text(
                    'Your local Ollama instance can be securely accessed from web browsers and remote clients through our encrypted tunnel service.',
                    style: TextStyle(
                      color: AppTheme.textColorLight,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSettings() {
    return Column(
      children: [
        ModernCard(
          child: FutureBuilder<String>(
            future: VersionService.instance.getFullVersion(),
            builder: (context, snapshot) {
              final version = snapshot.data ?? 'Loading...';
              return Column(
                children: [
                  Icon(Icons.info, size: 64, color: AppTheme.primaryColor),
                  SizedBox(height: AppTheme.spacingM),
                  Text(
                    'CloudToLocalLLM',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Version $version',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textColorLight,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingM),
                  Text(
                    'Manage and run powerful Large Language Models locally, orchestrated via a cloud interface.',
                    style: TextStyle(color: AppTheme.textColorLight),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWebConnectionStatusCard() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;

        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusSectionHeader(
                'Cloud Tunnel Status',
                Icons.cloud_sync,
                isAuthenticated ? Colors.green : Colors.red,
              ),
              SizedBox(height: AppTheme.spacingM),

              // Connection Status
              _buildStatusRow(
                'Connection',
                isAuthenticated ? 'Connected' : 'Disconnected',
                isAuthenticated ? Colors.green : Colors.red,
              ),

              // Tunnel Endpoint
              if (isAuthenticated) ...[
                _buildStatusRow(
                  'Tunnel Endpoint',
                  'https://app.cloudtolocalllm.online/api/tunnel/${authService.currentUser?.id ?? 'user'}',
                  AppTheme.textColorLight,
                ),

                // Last Connection Test
                if (_lastConnectionTest != null)
                  _buildStatusRow(
                    'Last Test',
                    _formatDateTime(_lastConnectionTest!),
                    AppTheme.textColorLight,
                  ),

                // Connection Latency
                if (_connectionLatency != null)
                  _buildStatusRow(
                    'Latency',
                    '${_connectionLatency!.toStringAsFixed(0)}ms',
                    _connectionLatency! < 100
                        ? Colors.green
                        : _connectionLatency! < 300
                        ? Colors.orange
                        : Colors.red,
                  ),
              ],

              // Error Display
              if (_connectionError != null) ...[
                SizedBox(height: AppTheme.spacingS),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          _connectionError!,
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebTunnelConfigCard() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;

        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusSectionHeader(
                'Tunnel Configuration',
                Icons.settings_ethernet,
                Colors.blue,
              ),
              SizedBox(height: AppTheme.spacingM),

              // Test Connection Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isAuthenticated && !_isTestingConnection
                      ? _testTunnelConnection
                      : null,
                  icon: _isTestingConnection
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _isTestingConnection ? 'Testing...' : 'Test Connection',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(AppTheme.spacingM),
                  ),
                ),
              ),

              SizedBox(height: AppTheme.spacingM),

              // Refresh Models Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isAuthenticated && !_isLoadingModels
                      ? _refreshAvailableModels
                      : null,
                  icon: _isLoadingModels
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isLoadingModels ? 'Loading...' : 'Refresh Models',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(AppTheme.spacingM),
                  ),
                ),
              ),

              // Available Models Display
              if (_availableModels.isNotEmpty) ...[
                SizedBox(height: AppTheme.spacingM),
                Text(
                  'Available Models (${_availableModels.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor,
                  ),
                ),
                SizedBox(height: AppTheme.spacingS),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _availableModels
                        .map(
                          (model) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.memory,
                                  size: 12,
                                  color: AppTheme.textColorLight,
                                ),
                                SizedBox(width: AppTheme.spacingXS),
                                Text(
                                  model,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textColorLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebAdvancedSettingsCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showAdvancedSettings = !_showAdvancedSettings;
              });
            },
            child: Row(
              children: [
                Icon(Icons.tune, color: AppTheme.primaryColor, size: 24),
                SizedBox(width: AppTheme.spacingS),
                Text(
                  'Advanced Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showAdvancedSettings ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textColorLight,
                ),
              ],
            ),
          ),

          if (_showAdvancedSettings) ...[
            SizedBox(height: AppTheme.spacingM),
            const Divider(),
            SizedBox(height: AppTheme.spacingM),

            // Custom Endpoint Configuration
            _buildSettingItem(
              'Custom Tunnel Endpoint',
              'Override default tunnel endpoint (advanced users only)',
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'https://app.cloudtolocalllm.online',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const Divider(),

            // Connection Timeout
            _buildSettingItem(
              'Connection Timeout',
              'Timeout for tunnel connection attempts (seconds)',
              DropdownButton<int>(
                value: 30,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 seconds')),
                  DropdownMenuItem(value: 30, child: Text('30 seconds')),
                  DropdownMenuItem(value: 60, child: Text('60 seconds')),
                  DropdownMenuItem(value: 120, child: Text('2 minutes')),
                ],
                onChanged: (value) {
                  // Handle timeout change
                },
              ),
            ),

            const Divider(),

            // Retry Attempts
            _buildSettingItem(
              'Retry Attempts',
              'Number of retry attempts for failed connections',
              DropdownButton<int>(
                value: 3,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 attempt')),
                  DropdownMenuItem(value: 3, child: Text('3 attempts')),
                  DropdownMenuItem(value: 5, child: Text('5 attempts')),
                  DropdownMenuItem(value: 10, child: Text('10 attempts')),
                ],
                onChanged: (value) {
                  // Handle retry change
                },
              ),
            ),

            const Divider(),

            // Debug Logging
            _buildSettingItem(
              'Debug Logging',
              'Enable detailed logging for tunnel connections',
              Switch(
                value: false,
                onChanged: (value) {
                  // Handle debug logging toggle
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper methods for web platform connection monitoring
  Future<void> _testTunnelConnection() async {
    if (_isTestingConnection) return;

    setState(() {
      _isTestingConnection = true;
      _connectionError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final accessToken = authService.getAccessToken();

      if (accessToken == null) {
        throw Exception('No authentication token available');
      }

      final stopwatch = Stopwatch()..start();

      // Test connection to cloud tunnel API
      final response = await http
          .get(
            Uri.parse('${AppConfig.appUrl}/api/health'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();

      if (response.statusCode == 200) {
        setState(() {
          _connectionLatency = stopwatch.elapsedMilliseconds.toDouble();
          _lastConnectionTest = DateTime.now();
          _connectionError = null;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _connectionError = 'Connection test failed: ${e.toString()}';
        _connectionLatency = null;
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _refreshAvailableModels() async {
    if (_isLoadingModels) return;

    setState(() {
      _isLoadingModels = true;
      _connectionError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final accessToken = authService.getAccessToken();

      if (accessToken == null) {
        throw Exception('No authentication token available');
      }

      // Get available models through tunnel API
      final response = await http
          .get(
            Uri.parse('${AppConfig.appUrl}/ollama/api/tags'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models =
            (data['models'] as List?)
                ?.map((model) => model['name'] as String)
                .toList() ??
            [];

        setState(() {
          _availableModels = models;
          _connectionError = null;
        });
      } else if (response.statusCode == 503) {
        setState(() {
          _availableModels = [];
          _connectionError =
              'No local Ollama bridge connected. Please ensure CloudToLocalLLM desktop app is running.';
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _availableModels = [];
        _connectionError = 'Failed to load models: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildStatusSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(width: AppTheme.spacingS),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppTheme.textColorLight),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle, Widget control) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textColorLight,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppTheme.spacingM),
          control,
        ],
      ),
    );
  }

  // Desktop tunnel management methods

  Widget _buildDesktopConnectionStatusCard(TunnelManagerService tunnelManager) {
    final connectionStatus = tunnelManager.connectionStatus;
    final ollamaStatus = connectionStatus['ollama'];
    final cloudStatus = connectionStatus['cloud'];
    final isConnecting = tunnelManager.isConnecting;
    final error = tunnelManager.error;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSectionHeader(
            'Connection Status',
            Icons.network_check,
            _getOverallStatusColor(ollamaStatus, cloudStatus),
          ),
          SizedBox(height: AppTheme.spacingM),

          // Overall Status
          _buildStatusRow(
            'Overall Status',
            _getOverallStatusText(ollamaStatus, cloudStatus, isConnecting),
            _getOverallStatusColor(ollamaStatus, cloudStatus),
          ),

          // Local Ollama Status
          if (ollamaStatus != null) ...[
            _buildStatusRow(
              'Local Ollama',
              ollamaStatus.isConnected ? 'Connected' : 'Disconnected',
              ollamaStatus.isConnected ? Colors.green : Colors.red,
            ),
            if (ollamaStatus.isConnected)
              _buildStatusRow(
                'Ollama Endpoint',
                ollamaStatus.endpoint,
                AppTheme.textColorLight,
              ),
          ],

          // Cloud Proxy Status
          if (cloudStatus != null) ...[
            _buildStatusRow(
              'Cloud Proxy',
              cloudStatus.isConnected ? 'Connected' : 'Disconnected',
              cloudStatus.isConnected ? Colors.green : Colors.red,
            ),
            if (cloudStatus.isConnected)
              _buildStatusRow(
                'Cloud Endpoint',
                cloudStatus.endpoint,
                AppTheme.textColorLight,
              ),
          ],

          // Error Display
          if (error != null) ...[
            SizedBox(height: AppTheme.spacingS),
            Container(
              padding: EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 16),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Refresh Button
          SizedBox(height: AppTheme.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isConnecting
                  ? null
                  : () => _refreshConnections(tunnelManager),
              icon: isConnecting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(isConnecting ? 'Connecting...' : 'Refresh Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(AppTheme.spacingM),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopOllamaConfigCard(TunnelManagerService tunnelManager) {
    final config = tunnelManager.config;
    final ollamaStatus = tunnelManager.connectionStatus['ollama'];

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSectionHeader(
            'Local Ollama Configuration',
            Icons.memory,
            config.enableLocalOllama ? Colors.blue : Colors.grey,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Enable Local Ollama Toggle
          _buildSettingItem(
            'Enable Local Ollama',
            'Connect to local Ollama instance',
            Switch(
              value: config.enableLocalOllama,
              onChanged: (value) =>
                  _updateOllamaConfig(tunnelManager, enabled: value),
            ),
          ),

          if (config.enableLocalOllama) ...[
            const Divider(),

            // Ollama Host Configuration
            _buildSettingItem(
              'Ollama Host',
              'Local Ollama server address',
              TextFormField(
                initialValue: config.ollamaHost,
                decoration: const InputDecoration(
                  hintText: 'localhost',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) =>
                    _updateOllamaConfig(tunnelManager, host: value),
              ),
            ),

            const Divider(),

            // Ollama Port Configuration
            _buildSettingItem(
              'Ollama Port',
              'Local Ollama server port',
              TextFormField(
                initialValue: config.ollamaPort.toString(),
                decoration: const InputDecoration(
                  hintText: '11434',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final port = int.tryParse(value);
                  if (port != null) {
                    _updateOllamaConfig(tunnelManager, port: port);
                  }
                },
              ),
            ),

            const Divider(),

            // Test Ollama Connection
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ollamaStatus?.isConnected == true
                    ? null
                    : () => _testOllamaConnection(tunnelManager),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  ollamaStatus?.isConnected == true
                      ? 'Connected'
                      : 'Test Connection',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ollamaStatus?.isConnected == true
                      ? Colors.green
                      : AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.all(AppTheme.spacingM),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopCloudProxyConfigCard(TunnelManagerService tunnelManager) {
    final config = tunnelManager.config;
    final cloudStatus = tunnelManager.connectionStatus['cloud'];

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSectionHeader(
            'Cloud Proxy Configuration',
            Icons.cloud,
            config.enableCloudProxy ? Colors.blue : Colors.grey,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Enable Cloud Proxy Toggle
          _buildSettingItem(
            'Enable Cloud Proxy',
            'Connect to cloud proxy service',
            Switch(
              value: config.enableCloudProxy,
              onChanged: (value) =>
                  _updateCloudConfig(tunnelManager, enabled: value),
            ),
          ),

          if (config.enableCloudProxy) ...[
            const Divider(),

            // Cloud Proxy URL Configuration
            _buildSettingItem(
              'Cloud Proxy URL',
              'Cloud proxy service endpoint',
              TextFormField(
                initialValue: config.cloudProxyUrl,
                decoration: const InputDecoration(
                  hintText: 'https://app.cloudtolocalllm.online',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) =>
                    _updateCloudConfig(tunnelManager, url: value),
              ),
            ),

            const Divider(),

            // Test Cloud Connection
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cloudStatus?.isConnected == true
                    ? null
                    : () => _testCloudConnection(tunnelManager),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  cloudStatus?.isConnected == true
                      ? 'Connected'
                      : 'Test Connection',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cloudStatus?.isConnected == true
                      ? Colors.green
                      : AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.all(AppTheme.spacingM),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopAdvancedTunnelCard(TunnelManagerService tunnelManager) {
    final config = tunnelManager.config;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSectionHeader(
            'Advanced Tunnel Settings',
            Icons.tune,
            Colors.orange,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Connection Timeout
          _buildSettingItem(
            'Connection Timeout',
            'Timeout for connection attempts (seconds)',
            DropdownButton<int>(
              value: config.connectionTimeout,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 seconds')),
                DropdownMenuItem(value: 10, child: Text('10 seconds')),
                DropdownMenuItem(value: 30, child: Text('30 seconds')),
                DropdownMenuItem(value: 60, child: Text('60 seconds')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateAdvancedConfig(
                    tunnelManager,
                    connectionTimeout: value,
                  );
                }
              },
            ),
          ),

          const Divider(),

          // Health Check Interval
          _buildSettingItem(
            'Health Check Interval',
            'Interval between health checks (seconds)',
            DropdownButton<int>(
              value: config.healthCheckInterval,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 seconds')),
                DropdownMenuItem(value: 30, child: Text('30 seconds')),
                DropdownMenuItem(value: 60, child: Text('1 minute')),
                DropdownMenuItem(value: 120, child: Text('2 minutes')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateAdvancedConfig(
                    tunnelManager,
                    healthCheckInterval: value,
                  );
                }
              },
            ),
          ),

          const Divider(),

          // Reset to Defaults Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _resetToDefaults(tunnelManager),
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Defaults'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(AppTheme.spacingM),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for tunnel management

  Color _getOverallStatusColor(
    ConnectionStatus? ollamaStatus,
    ConnectionStatus? cloudStatus,
  ) {
    if (ollamaStatus?.isConnected == true && cloudStatus?.isConnected == true) {
      return Colors.green;
    } else if (ollamaStatus?.isConnected == true ||
        cloudStatus?.isConnected == true) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getOverallStatusText(
    ConnectionStatus? ollamaStatus,
    ConnectionStatus? cloudStatus,
    bool isConnecting,
  ) {
    if (isConnecting) {
      return 'Connecting...';
    } else if (ollamaStatus?.isConnected == true &&
        cloudStatus?.isConnected == true) {
      return 'All Connected';
    } else if (ollamaStatus?.isConnected == true ||
        cloudStatus?.isConnected == true) {
      return 'Partially Connected';
    } else {
      return 'Disconnected';
    }
  }

  Future<void> _refreshConnections(TunnelManagerService tunnelManager) async {
    try {
      await tunnelManager.initialize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection status refreshed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh connections: $e')),
        );
      }
    }
  }

  Future<void> _updateOllamaConfig(
    TunnelManagerService tunnelManager, {
    bool? enabled,
    String? host,
    int? port,
  }) async {
    try {
      final currentConfig = tunnelManager.config;
      final newConfig = TunnelConfig(
        enableLocalOllama: enabled ?? currentConfig.enableLocalOllama,
        enableCloudProxy: currentConfig.enableCloudProxy,
        ollamaHost: host ?? currentConfig.ollamaHost,
        ollamaPort: port ?? currentConfig.ollamaPort,
        cloudProxyUrl: currentConfig.cloudProxyUrl,
        connectionTimeout: currentConfig.connectionTimeout,
        healthCheckInterval: currentConfig.healthCheckInterval,
      );

      await tunnelManager.updateConfiguration(newConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ollama configuration updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update Ollama config: $e')),
        );
      }
    }
  }

  Future<void> _updateCloudConfig(
    TunnelManagerService tunnelManager, {
    bool? enabled,
    String? url,
  }) async {
    try {
      final currentConfig = tunnelManager.config;
      final newConfig = TunnelConfig(
        enableLocalOllama: currentConfig.enableLocalOllama,
        enableCloudProxy: enabled ?? currentConfig.enableCloudProxy,
        ollamaHost: currentConfig.ollamaHost,
        ollamaPort: currentConfig.ollamaPort,
        cloudProxyUrl: url ?? currentConfig.cloudProxyUrl,
        connectionTimeout: currentConfig.connectionTimeout,
        healthCheckInterval: currentConfig.healthCheckInterval,
      );

      await tunnelManager.updateConfiguration(newConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud proxy configuration updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update cloud config: $e')),
        );
      }
    }
  }

  Future<void> _updateAdvancedConfig(
    TunnelManagerService tunnelManager, {
    int? connectionTimeout,
    int? healthCheckInterval,
  }) async {
    try {
      final currentConfig = tunnelManager.config;
      final newConfig = TunnelConfig(
        enableLocalOllama: currentConfig.enableLocalOllama,
        enableCloudProxy: currentConfig.enableCloudProxy,
        ollamaHost: currentConfig.ollamaHost,
        ollamaPort: currentConfig.ollamaPort,
        cloudProxyUrl: currentConfig.cloudProxyUrl,
        connectionTimeout: connectionTimeout ?? currentConfig.connectionTimeout,
        healthCheckInterval:
            healthCheckInterval ?? currentConfig.healthCheckInterval,
      );

      await tunnelManager.updateConfiguration(newConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Advanced settings updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update advanced settings: $e')),
        );
      }
    }
  }

  Future<void> _testOllamaConnection(TunnelManagerService tunnelManager) async {
    try {
      // Force a health check for Ollama
      await tunnelManager.initialize();

      if (mounted) {
        final ollamaStatus = tunnelManager.connectionStatus['ollama'];
        if (ollamaStatus?.isConnected == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ollama connection successful!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ollama connection failed: ${ollamaStatus?.error ?? 'Unknown error'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to test Ollama connection: $e')),
        );
      }
    }
  }

  Future<void> _testCloudConnection(TunnelManagerService tunnelManager) async {
    try {
      // Force a health check for cloud proxy
      await tunnelManager.initialize();

      if (mounted) {
        final cloudStatus = tunnelManager.connectionStatus['cloud'];
        if (cloudStatus?.isConnected == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cloud proxy connection successful!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cloud proxy connection failed: ${cloudStatus?.error ?? 'Unknown error'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to test cloud connection: $e')),
        );
      }
    }
  }

  Future<void> _resetToDefaults(TunnelManagerService tunnelManager) async {
    try {
      final defaultConfig = TunnelConfig.defaultConfig();
      await tunnelManager.updateConfiguration(defaultConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings reset to defaults')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reset settings: $e')));
      }
    }
  }
}
