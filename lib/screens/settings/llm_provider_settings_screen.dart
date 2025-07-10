import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../services/ollama_service.dart';
import '../../services/streaming_proxy_service.dart';
import '../../services/auth_service.dart';
import '../../components/modern_card.dart';

/// LLM Provider Settings Screen - Dedicated settings for Ollama testing and configuration
class LLMProviderSettingsScreen extends StatefulWidget {
  const LLMProviderSettingsScreen({super.key});

  @override
  State<LLMProviderSettingsScreen> createState() =>
      _LLMProviderSettingsScreenState();
}

class _LLMProviderSettingsScreenState extends State<LLMProviderSettingsScreen> {
  late OllamaService _ollamaService;
  late StreamingProxyService _streamingProxyService;

  // Desktop connection settings
  String _ollamaHost = AppConfig.defaultOllamaHost;
  int _ollamaPort = AppConfig.defaultOllamaPort;

  // Test chat functionality
  String? _selectedModel;
  final TextEditingController _messageController = TextEditingController();
  String? _chatResponse;

  @override
  void initState() {
    super.initState();
    _ollamaService = OllamaService();
    _streamingProxyService = StreamingProxyService(
      authService: context.read<AuthService>(),
    );

    // Initial connection test
    _testConnection();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (kIsWeb) {
      // Web platform: ensure proxy is running first
      await _streamingProxyService.ensureProxyRunning();
    }
    await _ollamaService.testConnection();
  }

  Future<void> _sendTestMessage() async {
    if (_messageController.text.isEmpty || _selectedModel == null) return;

    final response = await _ollamaService.chat(
      model: _selectedModel!,
      message: _messageController.text,
    );

    setState(() {
      _chatResponse = response;
    });
  }

  Future<void> _openOllamaWebUI() async {
    final url = Uri.parse('http://localhost:11434');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Ollama Web UI. Ensure Ollama is running.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM Provider Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform-specific connection settings
            if (kIsWeb)
              _buildWebConnectionSettings()
            else
              _buildDesktopConnectionSettings(),

            const SizedBox(height: 24),

            // Connection test section
            _buildConnectionTestSection(),

            const SizedBox(height: 24),

            // Model management section
            _buildModelManagementSection(),

            const SizedBox(height: 24),

            // Chat test section
            if (_selectedModel != null) _buildChatTestSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebConnectionSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(
                'Web Platform Connection',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Streaming proxy status
          Consumer<StreamingProxyService>(
            builder: (context, proxyService, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        proxyService.isProxyRunning
                            ? Icons.check_circle
                            : Icons.error,
                        color: proxyService.isProxyRunning
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        proxyService.isProxyRunning
                            ? 'Connected via CloudToLocalLLM streaming proxy'
                            : 'Proxy tunnel connection failed - check authentication',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (proxyService.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${proxyService.error}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.red),
                    ),
                  ],
                  if (proxyService.isProxyRunning &&
                      proxyService.proxyId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Proxy ID: ${proxyService.proxyId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    Text(
                      'Uptime: ${proxyService.formattedUptime}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Authentication status
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return Row(
                children: [
                  Icon(
                    authService.isAuthenticated.value
                        ? Icons.verified_user
                        : Icons.warning,
                    color: authService.isAuthenticated.value
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    authService.isAuthenticated.value
                        ? 'Authenticated'
                        : 'Authentication required',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopConnectionSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(
                'Desktop Platform Connection',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Host address field
          TextFormField(
            initialValue: _ollamaHost,
            decoration: const InputDecoration(
              labelText: 'Host Address',
              hintText: 'localhost',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _ollamaHost = value.isNotEmpty
                    ? value
                    : AppConfig.defaultOllamaHost;
              });
            },
          ),

          const SizedBox(height: 16),

          // Port field
          TextFormField(
            initialValue: _ollamaPort.toString(),
            decoration: const InputDecoration(
              labelText: 'Port',
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

          const SizedBox(height: 16),

          // Open Ollama Web UI button
          ElevatedButton.icon(
            onPressed: _openOllamaWebUI,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open Ollama Web UI'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTestSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.network_check, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(
                'Connection Test',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Connection status
          Consumer<OllamaService>(
            builder: (context, ollamaService, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        ollamaService.isConnected
                            ? Icons.check_circle
                            : Icons.error,
                        color: ollamaService.isConnected
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ollamaService.isConnected
                            ? (kIsWeb
                                  ? 'Connected via CloudToLocalLLM streaming proxy'
                                  : 'Connected to Ollama at localhost:$_ollamaPort')
                            : (kIsWeb
                                  ? 'Proxy tunnel connection failed - check authentication'
                                  : 'Direct connection failed - ensure Ollama is running locally'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (ollamaService.version != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Version: ${ollamaService.version}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                  if (ollamaService.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${ollamaService.error}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.red),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Test connection button
          Consumer<OllamaService>(
            builder: (context, ollamaService, child) {
              return ElevatedButton.icon(
                onPressed: ollamaService.isLoading ? null : _testConnection,
                icon: ollamaService.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  ollamaService.isLoading ? 'Testing...' : 'Test Connection',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModelManagementSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(
                'Model Management',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Available models
          Consumer<OllamaService>(
            builder: (context, ollamaService, child) {
              if (ollamaService.models.isEmpty) {
                return Column(
                  children: [
                    const Text(
                      'No models available. Connect to Ollama to load models.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: ollamaService.isLoading
                          ? null
                          : () => ollamaService.getModels(),
                      icon: ollamaService.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        ollamaService.isLoading
                            ? 'Loading...'
                            : 'Refresh Models',
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Models (${ollamaService.models.length})',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Model selection dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedModel,
                    decoration: const InputDecoration(
                      labelText: 'Select Model for Testing',
                      border: OutlineInputBorder(),
                    ),
                    items: ollamaService.models.map((model) {
                      return DropdownMenuItem<String>(
                        value: model.name,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(model.name),
                            if (model.size != null)
                              Text(
                                'Size: ${model.size}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedModel = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Refresh models button
                  ElevatedButton.icon(
                    onPressed: ollamaService.isLoading
                        ? null
                        : () => ollamaService.getModels(),
                    icon: ollamaService.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      ollamaService.isLoading ? 'Loading...' : 'Refresh Models',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatTestSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(
                'Test Chat with $_selectedModel',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Message input
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: 'Enter a message to test the model...',
              border: OutlineInputBorder(),
              labelText: 'Test Message',
            ),
            maxLines: 3,
            onSubmitted: (_) => _sendTestMessage(),
          ),

          const SizedBox(height: 16),

          // Send button
          Consumer<OllamaService>(
            builder: (context, ollamaService, child) {
              return ElevatedButton.icon(
                onPressed:
                    (ollamaService.isLoading || _messageController.text.isEmpty)
                    ? null
                    : _sendTestMessage,
                icon: ollamaService.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  ollamaService.isLoading ? 'Sending...' : 'Send Test Message',
                ),
              );
            },
          ),

          // Response display
          if (_chatResponse != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Response:',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _chatResponse!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
