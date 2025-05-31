import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
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
  String _ollamaHost = AppConfig.defaultOllamaHost;
  int _ollamaPort = AppConfig.defaultOllamaPort;
  bool _enableCloudSync = false;
  bool _enableRemoteAccess = false;
  bool _enableNotifications = true;

  // Ollama service for testing
  late OllamaService _ollamaService;
  String? _selectedModel;
  final TextEditingController _messageController = TextEditingController();
  String? _chatResponse;

  @override
  void initState() {
    super.initState();
    _ollamaService = OllamaService();
    _ollamaService.testConnection();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
                    maxWidth:
                        isDesktop ? AppConfig.maxContentWidth : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page title
                      Text(
                        'Settings',
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
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
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
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
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildAppearanceSettings(context)),
            SizedBox(width: AppTheme.spacingL),
            Expanded(child: _buildLLMSettings(context)),
            SizedBox(width: AppTheme.spacingL),
            Expanded(child: _buildCloudSettings(context)),
          ],
        ),
        SizedBox(height: AppTheme.spacingL),
        _buildOllamaTestingSection(context),
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
        _buildCloudSettings(context),
        SizedBox(height: AppTheme.spacingL),
        _buildOllamaTestingSection(context),
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

          if (_selectedLLMProvider == 'ollama') ...[
            SizedBox(height: AppTheme.spacingM),

            // Ollama host
            _buildSettingItem(
              context,
              'Host',
              'Ollama server host address',
              TextFormField(
                initialValue: _ollamaHost,
                decoration: const InputDecoration(
                  hintText: 'localhost',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _ollamaHost = value;
                  });
                },
              ),
            ),

            SizedBox(height: AppTheme.spacingM),

            // Ollama port
            _buildSettingItem(
              context,
              'Port',
              'Ollama server port',
              TextFormField(
                initialValue: _ollamaPort.toString(),
                decoration: const InputDecoration(
                  hintText: '11434',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _ollamaPort =
                        int.tryParse(value) ?? AppConfig.defaultOllamaPort;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCloudSettings(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'Cloud & Sync',
            Icons.cloud,
            AppTheme.accentColor,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Cloud sync toggle
          _buildSettingItem(
            context,
            'Cloud Sync',
            'Synchronize data across devices',
            Switch(
              value: _enableCloudSync,
              onChanged: (value) {
                setState(() {
                  _enableCloudSync = value;
                });
              },
            ),
          ),

          SizedBox(height: AppTheme.spacingM),

          // Remote access toggle
          _buildSettingItem(
            context,
            'Remote Access',
            'Allow remote access to your LLM',
            Switch(
              value: _enableRemoteAccess,
              onChanged: (value) {
                setState(() {
                  _enableRemoteAccess = value;
                });
              },
            ),
          ),
        ],
      ),
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
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textColorLight,
              ),
        ),
        SizedBox(height: AppTheme.spacingS),
        control,
      ],
    );
  }

  Widget _buildOllamaTestingSection(BuildContext context) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            'Ollama Testing',
            Icons.science,
            AppTheme.infoColor,
          ),
          SizedBox(height: AppTheme.spacingM),

          // Connection status
          ListenableBuilder(
            listenable: _ollamaService,
            builder: (context, child) {
              return Container(
                padding: EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: _ollamaService.isConnected
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  border: Border.all(
                    color: _ollamaService.isConnected
                        ? AppTheme.successColor.withValues(alpha: 0.3)
                        : AppTheme.dangerColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _ollamaService.isConnected
                          ? Icons.check_circle
                          : Icons.error,
                      color: _ollamaService.isConnected
                          ? AppTheme.successColor
                          : AppTheme.dangerColor,
                    ),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ollamaService.isConnected
                                ? 'Connected to Ollama (v${_ollamaService.version})'
                                : 'Not connected to Ollama',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _ollamaService.isConnected
                                      ? AppTheme.successColor
                                      : AppTheme.dangerColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          if (_ollamaService.error != null) ...[
                            SizedBox(height: AppTheme.spacingXS),
                            Text(
                              'Error: ${_ollamaService.error}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.dangerColor,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          _ollamaService.isLoading ? null : _testConnection,
                      child: _ollamaService.isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            )
                          : const Text('Test Connection'),
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: AppTheme.spacingM),

          // Models list and chat test
          ListenableBuilder(
            listenable: _ollamaService,
            builder: (context, child) {
              if (!_ollamaService.isConnected ||
                  _ollamaService.models.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        color: AppTheme.warningColor,
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          'No models available. Make sure Ollama is running and has models installed.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.warningColor,
                                  ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model selector
                  _buildSettingItem(
                    context,
                    'Available Models (${_ollamaService.models.length})',
                    'Select a model to test chat functionality',
                    DropdownButton<String>(
                      value: _selectedModel,
                      isExpanded: true,
                      hint: const Text('Select a model'),
                      items: _ollamaService.models.map((model) {
                        return DropdownMenuItem(
                          value: model.name,
                          child: Text(
                              '${model.displayName} (${model.sizeFormatted})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedModel = value;
                        });
                      },
                    ),
                  ),

                  // Chat test
                  if (_selectedModel != null) ...[
                    SizedBox(height: AppTheme.spacingM),
                    _buildSettingItem(
                      context,
                      'Test Chat',
                      'Send a test message to verify the model is working',
                      Column(
                        children: [
                          TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Enter a test message...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _ollamaService.isLoading
                                      ? null
                                      : _sendTestMessage,
                                  child: _ollamaService.isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Send Test Message'),
                                ),
                              ),
                            ],
                          ),
                          if (_chatResponse != null) ...[
                            SizedBox(height: AppTheme.spacingM),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(AppTheme.spacingM),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundMain,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.borderRadiusS),
                                border: Border.all(
                                  color: AppTheme.secondaryColor
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Response:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppTheme.textColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  SizedBox(height: AppTheme.spacingS),
                                  Text(
                                    _chatResponse!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textColor,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    await _ollamaService.testConnection();
  }

  Future<void> _sendTestMessage() async {
    if (_messageController.text.isEmpty || _selectedModel == null) return;

    final response = await _ollamaService.chat(
      model: _selectedModel!,
      message: _messageController.text,
    );

    setState(() {
      _chatResponse = response ?? 'No response received';
    });
  }
}
