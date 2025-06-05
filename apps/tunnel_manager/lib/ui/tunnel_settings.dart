import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/config_service.dart';

class TunnelSettings extends StatefulWidget {
  const TunnelSettings({super.key});

  @override
  State<TunnelSettings> createState() => _TunnelSettingsState();
}

class _TunnelSettingsState extends State<TunnelSettings> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late TextEditingController _ollamaHostController;
  late TextEditingController _ollamaPortController;
  late TextEditingController _cloudProxyUrlController;
  late TextEditingController _apiServerPortController;
  late TextEditingController _healthCheckIntervalController;

  // Form values
  bool _enableLocalOllama = true;
  bool _enableCloudProxy = true;
  bool _enableApiServer = true;
  bool _minimizeToTray = true;
  bool _showNotifications = true;
  bool _autoStartTunnel = true;
  String _logLevel = 'INFO';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    _ollamaHostController = TextEditingController();
    _ollamaPortController = TextEditingController();
    _cloudProxyUrlController = TextEditingController();
    _apiServerPortController = TextEditingController();
    _healthCheckIntervalController = TextEditingController();
  }

  void _disposeControllers() {
    _ollamaHostController.dispose();
    _ollamaPortController.dispose();
    _cloudProxyUrlController.dispose();
    _apiServerPortController.dispose();
    _healthCheckIntervalController.dispose();
  }

  void _loadCurrentConfig() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final config = configService.config;

    _ollamaHostController.text = config.ollamaHost;
    _ollamaPortController.text = config.ollamaPort.toString();
    _cloudProxyUrlController.text = config.cloudProxyUrl;
    _apiServerPortController.text = config.apiServerPort.toString();
    _healthCheckIntervalController.text = config.healthCheckInterval.toString();

    setState(() {
      _enableLocalOllama = config.enableLocalOllama;
      _enableCloudProxy = config.enableCloudProxy;
      _enableApiServer = config.enableApiServer;
      _minimizeToTray = config.minimizeToTray;
      _showNotifications = config.showNotifications;
      _autoStartTunnel = config.autoStartTunnel;
      _logLevel = config.logLevel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Tunnel Settings',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                _buildActionButtons(),
              ],
            ),
            const SizedBox(height: 16),

            // Settings content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildOllamaSettings(),
                    const SizedBox(height: 16),
                    _buildCloudProxySettings(),
                    const SizedBox(height: 16),
                    _buildApiServerSettings(),
                    const SizedBox(height: 16),
                    _buildMonitoringSettings(),
                    const SizedBox(height: 16),
                    _buildUISettings(),
                    const SizedBox(height: 16),
                    _buildAdvancedSettings(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _resetToDefaults,
          icon: const Icon(Icons.restore),
          label: const Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildOllamaSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.computer),
                const SizedBox(width: 8),
                Text(
                  'Local Ollama Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Local Ollama'),
              subtitle: const Text('Connect to local Ollama instance'),
              value: _enableLocalOllama,
              onChanged: (value) {
                setState(() {
                  _enableLocalOllama = value;
                });
              },
            ),
            if (_enableLocalOllama) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ollamaHostController,
                      decoration: const InputDecoration(
                        labelText: 'Ollama Host',
                        hintText: 'localhost',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Host is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _ollamaPortController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '11434',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Port is required';
                        }
                        final port = int.tryParse(value);
                        if (port == null || port < 1 || port > 65535) {
                          return 'Invalid port';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCloudProxySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud),
                const SizedBox(width: 8),
                Text(
                  'Cloud Proxy Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Cloud Proxy'),
              subtitle: const Text('Connect to CloudToLocalLLM cloud services'),
              value: _enableCloudProxy,
              onChanged: (value) {
                setState(() {
                  _enableCloudProxy = value;
                });
              },
            ),
            if (_enableCloudProxy) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _cloudProxyUrlController,
                decoration: const InputDecoration(
                  labelText: 'Cloud Proxy URL',
                  hintText: 'https://app.cloudtolocalllm.online',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'URL is required';
                  }
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'URL must start with http:// or https://';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApiServerSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.api),
                const SizedBox(width: 8),
                Text(
                  'API Server Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable API Server'),
              subtitle: const Text(
                'Provide REST API for external applications',
              ),
              value: _enableApiServer,
              onChanged: (value) {
                setState(() {
                  _enableApiServer = value;
                });
              },
            ),
            if (_enableApiServer) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiServerPortController,
                decoration: const InputDecoration(
                  labelText: 'API Server Port',
                  hintText: '8765',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Port is required';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Invalid port';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart),
                const SizedBox(width: 8),
                Text(
                  'Monitoring Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _healthCheckIntervalController,
              decoration: const InputDecoration(
                labelText: 'Health Check Interval (seconds)',
                hintText: '30',
                border: OutlineInputBorder(),
                suffixText: 'seconds',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Interval is required';
                }
                final interval = int.tryParse(value);
                if (interval == null || interval < 5) {
                  return 'Minimum 5 seconds';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _logLevel,
              decoration: const InputDecoration(
                labelText: 'Log Level',
                border: OutlineInputBorder(),
              ),
              items: ['DEBUG', 'INFO', 'WARN', 'ERROR']
                  .map(
                    (level) =>
                        DropdownMenuItem(value: level, child: Text(level)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _logLevel = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUISettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings),
                const SizedBox(width: 8),
                Text(
                  'UI & Behavior Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Minimize to Tray'),
              subtitle: const Text('Hide to system tray when minimized'),
              value: _minimizeToTray,
              onChanged: (value) {
                setState(() {
                  _minimizeToTray = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Show Notifications'),
              subtitle: const Text('Display desktop notifications for alerts'),
              value: _showNotifications,
              onChanged: (value) {
                setState(() {
                  _showNotifications = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Auto-start Tunnel'),
              subtitle: const Text(
                'Automatically start tunnel on application launch',
              ),
              value: _autoStartTunnel,
              onChanged: (value) {
                setState(() {
                  _autoStartTunnel = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.engineering),
                const SizedBox(width: 8),
                Text(
                  'Advanced Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportConfig,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Config'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importConfig,
                    icon: const Icon(Icons.upload),
                    label: const Text('Import Config'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _createBackup,
              icon: const Icon(Icons.backup),
              label: const Text('Create Backup'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final configService = Provider.of<ConfigService>(context, listen: false);

      await configService.updateConfigValues(
        enableLocalOllama: _enableLocalOllama,
        ollamaHost: _ollamaHostController.text,
        ollamaPort: int.parse(_ollamaPortController.text),
        enableCloudProxy: _enableCloudProxy,
        cloudProxyUrl: _cloudProxyUrlController.text,
        enableApiServer: _enableApiServer,
        apiServerPort: int.parse(_apiServerPortController.text),
        healthCheckInterval: int.parse(_healthCheckIntervalController.text),
        minimizeToTray: _minimizeToTray,
        showNotifications: _showNotifications,
        logLevel: _logLevel,
        autoStartTunnel: _autoStartTunnel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetToDefaults() async {
    final configService = Provider.of<ConfigService>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await configService.resetToDefaults();
        _loadCurrentConfig();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings reset to defaults'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _exportConfig() async {
    // In a real implementation, this would open a file picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality not implemented yet')),
    );
  }

  void _importConfig() async {
    // In a real implementation, this would open a file picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality not implemented yet')),
    );
  }

  void _createBackup() async {
    final configService = Provider.of<ConfigService>(context, listen: false);

    try {
      final backupPath = await configService.createBackup();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created: $backupPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
