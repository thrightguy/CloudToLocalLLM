import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/tunnel_manager_service.dart';
import '../services/auth_service.dart';

/// Settings Screen for CloudToLocalLLM v3.3.1+
///
/// Primary settings interface that consolidates tunnel management configuration
/// and other application settings. Replaces the previous generic settings screen
/// and integrates tunnel manager functionality from the separate tunnel manager app.
class TunnelSettingsScreen extends StatefulWidget {
  const TunnelSettingsScreen({super.key});

  @override
  State<TunnelSettingsScreen> createState() => _TunnelSettingsScreenState();
}

class _TunnelSettingsScreenState extends State<TunnelSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Configuration controllers (cloud proxy only)
  late TextEditingController _cloudProxyUrlController;
  late TextEditingController _connectionTimeoutController;
  late TextEditingController _healthCheckIntervalController;

  // Local configuration state (cloud proxy only)
  bool _enableCloudProxy = true;
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final tunnelManager = context.read<TunnelManagerService>();
    final config = tunnelManager.config;

    // Initialize cloud proxy controllers only
    _cloudProxyUrlController = TextEditingController(
      text: config.cloudProxyUrl,
    );
    _connectionTimeoutController = TextEditingController(
      text: config.connectionTimeout.toString(),
    );
    _healthCheckIntervalController = TextEditingController(
      text: config.healthCheckInterval.toString(),
    );

    _enableCloudProxy = config.enableCloudProxy;

    // Add listeners to detect changes
    _cloudProxyUrlController.addListener(_onConfigChanged);
    _connectionTimeoutController.addListener(_onConfigChanged);
    _healthCheckIntervalController.addListener(_onConfigChanged);
  }

  void _onConfigChanged() {
    if (!_isModified) {
      setState(() {
        _isModified = true;
      });
    }
  }

  @override
  void dispose() {
    _cloudProxyUrlController.dispose();
    _connectionTimeoutController.dispose();
    _healthCheckIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isModified)
            TextButton(
              onPressed: _saveConfiguration,
              child: const Text('Save'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testConnections,
            tooltip: 'Test Connections',
          ),
        ],
      ),
      body: Consumer<TunnelManagerService>(
        builder: (context, tunnelManager, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionStatusCard(tunnelManager),
                  const SizedBox(height: 24),
                  _buildCloudProxyConfigSection(),
                  const SizedBox(height: 24),
                  _buildNgrokConfigSection(),
                  const SizedBox(height: 24),
                  _buildAdvancedSettingsSection(),
                  const SizedBox(height: 24),
                  _buildAdditionalSettingsSection(),
                  const SizedBox(height: 24),
                  _buildActionButtons(tunnelManager),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusCard(TunnelManagerService tunnelManager) {
    final connectionStatus = tunnelManager.connectionStatus;
    final ollamaStatus = connectionStatus['ollama'];
    final cloudStatus = connectionStatus['cloud'];
    final ngrokStatus = connectionStatus['ngrok'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.network_check,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildConnectionStatusItem(
              'Local Ollama',
              ollamaStatus,
              Icons.computer,
            ),
            const SizedBox(height: 12),
            _buildConnectionStatusItem('Cloud Proxy', cloudStatus, Icons.cloud),
            const SizedBox(height: 12),
            _buildConnectionStatusItem(
              'Ngrok Tunnel',
              ngrokStatus,
              Icons.vpn_lock,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  tunnelManager.isConnected ? Icons.check_circle : Icons.error,
                  color: tunnelManager.isConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  tunnelManager.isConnected
                      ? 'Tunnel Active'
                      : 'No Active Connections',
                  style: TextStyle(
                    color: tunnelManager.isConnected
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusItem(
    String name,
    ConnectionStatus? status,
    IconData icon,
  ) {
    final isConnected = status?.isConnected ?? false;
    final statusColor = isConnected ? Colors.green : Colors.red;
    final statusText = isConnected ? 'Connected' : 'Disconnected';

    return Row(
      children: [
        Icon(icon, size: 20, color: statusColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
              if (status?.endpoint != null)
                Text(
                  status!.endpoint,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        if (status?.latency != null && status!.latency > 0)
          Text(
            '${status.latency.toInt()}ms',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 11,
            ),
          ),
      ],
    );
  }

  // Local Ollama configuration is now managed independently
  // through LocalOllamaConnectionService, not through this tunnel settings screen

  Widget _buildCloudProxyConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Cloud Proxy Configuration',
                  style: Theme.of(context).textTheme.titleMedium,
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
                  _isModified = true;
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
                    return 'Please enter a cloud proxy URL';
                  }
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasAbsolutePath) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  final isAuth = authService.isAuthenticated.value;
                  return ListTile(
                    leading: Icon(
                      isAuth ? Icons.check_circle : Icons.error,
                      color: isAuth ? Colors.green : Colors.red,
                    ),
                    title: Text(isAuth ? 'Authenticated' : 'Not Authenticated'),
                    subtitle: isAuth && authService.currentUser != null
                        ? Text('Logged in as ${authService.currentUser!.email}')
                        : const Text(
                            'Click to authenticate with cloud services',
                          ),
                    trailing: isAuth
                        ? TextButton(
                            onPressed: () => authService.logout(),
                            child: const Text('Logout'),
                          )
                        : ElevatedButton(
                            onPressed: () => authService.login(),
                            child: const Text('Login'),
                          ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNgrokConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.vpn_lock,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ngrok Tunnel Configuration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configure ngrok tunnel as a fallback option for cloud proxy connections. '
              'Desktop platform only.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Advanced Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _connectionTimeoutController,
              decoration: const InputDecoration(
                labelText: 'Connection Timeout (seconds)',
                hintText: '10',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a timeout value';
                }
                final timeout = int.tryParse(value);
                if (timeout == null || timeout < 1 || timeout > 300) {
                  return 'Please enter a valid timeout (1-300 seconds)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _healthCheckIntervalController,
              decoration: const InputDecoration(
                labelText: 'Health Check Interval (seconds)',
                hintText: '30',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a health check interval';
                }
                final interval = int.tryParse(value);
                if (interval == null || interval < 5 || interval > 3600) {
                  return 'Please enter a valid interval (5-3600 seconds)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Additional Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // LLM Provider Settings button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/settings/llm-provider');
                },
                icon: const Icon(Icons.memory),
                label: const Text('LLM Provider & Model Settings'),
                style: ElevatedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure connection settings, test models, and manage Ollama integration',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Status Settings button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/settings/connection-status');
                },
                icon: const Icon(Icons.network_check),
                label: const Text('Connection Status & Monitoring'),
                style: ElevatedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'View detailed connection status and monitoring information',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(TunnelManagerService tunnelManager) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _testConnections,
            icon: const Icon(Icons.network_check),
            label: const Text('Test Connections'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _reconnectTunnels(tunnelManager),
            icon: const Icon(Icons.refresh),
            label: const Text('Reconnect'),
          ),
        ),
      ],
    );
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Create new configuration
      final newConfig = TunnelConfig(
        enableCloudProxy: _enableCloudProxy,
        cloudProxyUrl: _cloudProxyUrlController.text.trim(),
        connectionTimeout: int.parse(_connectionTimeoutController.text.trim()),
        healthCheckInterval: int.parse(
          _healthCheckIntervalController.text.trim(),
        ),
      );

      // Apply configuration to tunnel manager
      final tunnelManager = context.read<TunnelManagerService>();
      await tunnelManager.updateConfiguration(newConfig);

      setState(() {
        _isModified = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tunnel configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testConnections() async {
    final tunnelManager = context.read<TunnelManagerService>();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing connections...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await tunnelManager.reconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection test completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reconnectTunnels(TunnelManagerService tunnelManager) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reconnecting tunnels...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await tunnelManager.reconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tunnels reconnected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reconnect tunnels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
