import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import '../config/theme.dart';

/// Connection settings screen
///
/// Allows users to configure:
/// - Ollama server URL and connection preferences
/// - Cloud proxy settings
/// - Connection timeout and retry settings
class ConnectionSettings extends StatefulWidget {
  const ConnectionSettings({Key? key}) : super(key: key);

  @override
  _ConnectionSettingsState createState() => _ConnectionSettingsState();
}

class _ConnectionSettingsState extends State<ConnectionSettings> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ollamaUrlController;
  late TextEditingController _cloudProxyUrlController;
  late TextEditingController _connectionTimeoutController;
  late TextEditingController _retryAttemptsController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsService>(context, listen: false);
    
    _ollamaUrlController = TextEditingController(text: settings.ollamaUrl);
    _cloudProxyUrlController = TextEditingController(text: settings.cloudProxyUrl);
    _connectionTimeoutController = TextEditingController(text: settings.connectionTimeout.toString());
    _retryAttemptsController = TextEditingController(text: settings.retryAttempts.toString());
  }

  @override
  void dispose() {
    _ollamaUrlController.dispose();
    _cloudProxyUrlController.dispose();
    _connectionTimeoutController.dispose();
    _retryAttemptsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Settings'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection mode
                  _buildConnectionModeSection(settings),
                  const SizedBox(height: 24),
                  
                  // Ollama settings
                  _buildOllamaSection(settings),
                  const SizedBox(height: 24),
                  
                  // Cloud proxy settings
                  _buildCloudProxySection(settings),
                  const SizedBox(height: 24),
                  
                  // Advanced settings
                  _buildAdvancedSection(settings),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionModeSection(SettingsService settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Mode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('Auto'),
              subtitle: const Text('Automatically choose best connection'),
              value: 'auto',
              groupValue: settings.connectionMode,
              onChanged: (value) => settings.set('connectionMode', value),
            ),
            RadioListTile<String>(
              title: const Text('Local Only'),
              subtitle: const Text('Use local Ollama only'),
              value: 'local',
              groupValue: settings.connectionMode,
              onChanged: (value) => settings.set('connectionMode', value),
            ),
            RadioListTile<String>(
              title: const Text('Cloud Only'),
              subtitle: const Text('Use cloud proxy only'),
              value: 'cloud',
              groupValue: settings.connectionMode,
              onChanged: (value) => settings.set('connectionMode', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOllamaSection(SettingsService settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local Ollama Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ollamaUrlController,
              decoration: const InputDecoration(
                labelText: 'Ollama Server URL',
                hintText: 'http://localhost:11434',
                helperText: 'URL of your local Ollama server',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter Ollama URL';
                }
                if (!Uri.tryParse(value)?.hasScheme == true) {
                  return 'Please enter a valid URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-connect to Ollama'),
              subtitle: const Text('Automatically connect when app starts'),
              value: settings.autoConnectOllama,
              onChanged: (value) => settings.set('autoConnectOllama', value),
            ),
            SwitchListTile(
              title: const Text('Prefer local connection'),
              subtitle: const Text('Use local Ollama when available'),
              value: settings.preferLocalConnection,
              onChanged: (value) => settings.set('preferLocalConnection', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudProxySection(SettingsService settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cloud Proxy Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cloudProxyUrlController,
              decoration: const InputDecoration(
                labelText: 'Cloud Proxy URL',
                hintText: 'https://api.cloudtolocalllm.online',
                helperText: 'URL of the cloud proxy service',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter cloud proxy URL';
                }
                if (!Uri.tryParse(value)?.hasScheme == true) {
                  return 'Please enter a valid URL';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(SettingsService settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _connectionTimeoutController,
              decoration: const InputDecoration(
                labelText: 'Connection Timeout (ms)',
                hintText: '10000',
                helperText: 'Timeout for connection attempts',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter timeout value';
                }
                final timeout = int.tryParse(value);
                if (timeout == null || timeout < 1000) {
                  return 'Timeout must be at least 1000ms';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _retryAttemptsController,
              decoration: const InputDecoration(
                labelText: 'Retry Attempts',
                hintText: '3',
                helperText: 'Number of retry attempts on failure',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter retry attempts';
                }
                final attempts = int.tryParse(value);
                if (attempts == null || attempts < 0 || attempts > 10) {
                  return 'Retry attempts must be between 0 and 10';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final settings = Provider.of<SettingsService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await settings.set('ollamaUrl', _ollamaUrlController.text.trim());
      await settings.set('cloudProxyUrl', _cloudProxyUrlController.text.trim());
      await settings.set('connectionTimeout', int.parse(_connectionTimeoutController.text));
      await settings.set('retryAttempts', int.parse(_retryAttemptsController.text));

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Connection settings saved'),
          backgroundColor: SettingsTheme.successColor,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: SettingsTheme.errorColor,
        ),
      );
    }
  }
}
