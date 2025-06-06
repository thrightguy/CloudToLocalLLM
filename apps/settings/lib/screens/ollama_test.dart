import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ollama_service.dart';
import '../services/settings_service.dart';
import '../config/theme.dart';

/// Ollama testing screen
///
/// Provides functionality to:
/// - Test Ollama server connectivity
/// - List and test available models
/// - Monitor connection health
/// - Pull new models
class OllamaTest extends StatefulWidget {
  const OllamaTest({super.key});

  @override
  State<OllamaTest> createState() => _OllamaTestState();
}

class _OllamaTestState extends State<OllamaTest> {
  final _testPromptController = TextEditingController(
    text: 'Hello! Please respond with a brief greeting.',
  );
  String? _selectedModel;
  String? _testResult;
  bool _isTestingModel = false;

  @override
  void dispose() {
    _testPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ollama Testing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshConnection,
            tooltip: 'Refresh Connection',
          ),
        ],
      ),
      body: Consumer2<OllamaService, SettingsService>(
        builder: (context, ollama, settings, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection status
                _buildConnectionStatus(ollama, settings),
                const SizedBox(height: 24),

                // Connection test
                _buildConnectionTest(ollama),
                const SizedBox(height: 24),

                // Model list
                if (ollama.isConnected) ...[
                  _buildModelList(ollama),
                  const SizedBox(height: 24),

                  // Model testing
                  _buildModelTest(ollama),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(
    OllamaService ollama,
    SettingsService settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  ollama.isConnected ? Icons.check_circle : Icons.error,
                  color: ollama.isConnected
                      ? SettingsTheme.successColor
                      : SettingsTheme.errorColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server: ${ollama.baseUrl}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Status: ${ollama.status}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (ollama.lastError != null)
                        Text(
                          'Error: ${ollama.lastError}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: SettingsTheme.errorColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTest(OllamaService ollama) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Test',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testConnection,
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('Test Connection'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ollama.isConnected
                        ? _startHealthMonitoring
                        : null,
                    icon: const Icon(Icons.monitor_heart),
                    label: const Text('Monitor Health'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelList(OllamaService ollama) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Models',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _showPullModelDialog,
                  icon: const Icon(Icons.download),
                  label: const Text('Pull Model'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (ollama.availableModels.isEmpty)
              const Text('No models available. Pull a model to get started.')
            else
              ...ollama.availableModels.map(
                (model) => ListTile(
                  title: Text(model),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) =>
                        _handleModelAction(action, model, ollama),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'test',
                        child: Text('Test Model'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Model'),
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _selectedModel = model;
                    });
                  },
                  selected: _selectedModel == model,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelTest(OllamaService ollama) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model Testing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: const InputDecoration(
                labelText: 'Select Model',
                border: OutlineInputBorder(),
              ),
              items: ollama.availableModels.map((model) {
                return DropdownMenuItem(value: model, child: Text(model));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedModel = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _testPromptController,
              decoration: const InputDecoration(
                labelText: 'Test Prompt',
                border: OutlineInputBorder(),
                helperText: 'Enter a prompt to test the model',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedModel != null && !_isTestingModel
                    ? _testSelectedModel
                    : null,
                icon: _isTestingModel
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isTestingModel ? 'Testing...' : 'Test Model'),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SettingsTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Result:',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _testResult!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _refreshConnection() async {
    final ollama = Provider.of<OllamaService>(context, listen: false);
    final settings = Provider.of<SettingsService>(context, listen: false);

    await ollama.setBaseUrl(settings.ollamaUrl);
    await _testConnection();
  }

  Future<void> _testConnection() async {
    final ollama = Provider.of<OllamaService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final success = await ollama.testConnection();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(success ? 'Connection successful!' : 'Connection failed'),
        backgroundColor: success
            ? SettingsTheme.successColor
            : SettingsTheme.errorColor,
      ),
    );
  }

  void _startHealthMonitoring() {
    final ollama = Provider.of<OllamaService>(context, listen: false);
    ollama.startHealthMonitoring();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Health monitoring started'),
        backgroundColor: SettingsTheme.infoColor,
      ),
    );
  }

  Future<void> _testSelectedModel() async {
    if (_selectedModel == null) return;

    setState(() {
      _isTestingModel = true;
      _testResult = null;
    });

    final ollama = Provider.of<OllamaService>(context, listen: false);
    final result = await ollama.testModel(
      _selectedModel!,
      prompt: _testPromptController.text.trim(),
    );

    setState(() {
      _isTestingModel = false;
      _testResult = result ?? 'Test failed - no response received';
    });
  }

  void _handleModelAction(String action, String model, OllamaService ollama) {
    switch (action) {
      case 'test':
        setState(() {
          _selectedModel = model;
        });
        _testSelectedModel();
        break;
      case 'delete':
        _showDeleteModelDialog(model, ollama);
        break;
    }
  }

  void _showPullModelDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pull Model'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Model Name',
            hintText: 'e.g., llama2, codellama',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _pullModel(controller.text.trim());
            },
            child: const Text('Pull'),
          ),
        ],
      ),
    );
  }

  void _showDeleteModelDialog(String model, OllamaService ollama) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete the model "$model"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ollama.deleteModel(model);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SettingsTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _pullModel(String modelName) async {
    if (modelName.isEmpty) return;

    final ollama = Provider.of<OllamaService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final success = await ollama.pullModel(modelName);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Model pulled successfully!' : 'Failed to pull model',
        ),
        backgroundColor: success
            ? SettingsTheme.successColor
            : SettingsTheme.errorColor,
      ),
    );
  }
}
