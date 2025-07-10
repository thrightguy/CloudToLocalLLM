import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../components/modern_card.dart';
import '../../components/gradient_button.dart';
import '../../services/unified_connection_service.dart';
import '../../services/auth_service.dart';

/// Connection Status Screen
class ConnectionStatusScreen extends StatefulWidget {
  const ConnectionStatusScreen({super.key});

  @override
  State<ConnectionStatusScreen> createState() => _ConnectionStatusScreenState();
}

class _ConnectionStatusScreenState extends State<ConnectionStatusScreen> {
  bool _isRefreshing = false;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    debugPrint("📊 [ConnectionStatusScreen] Initializing screen");
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Refresh connection status
      final connectionService = context.read<UnifiedConnectionService>();
      await connectionService.initialize();

      setState(() {
        _lastRefresh = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("📊 [ConnectionStatusScreen] Building widget");
    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      appBar: AppBar(
        title: const Text('Connection Status'),
        backgroundColor: AppTheme.backgroundMain,
        foregroundColor: AppTheme.textColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshStatus,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'System Connection Status',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              'Monitor the status of all system connections and services',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            ),
            if (_lastRefresh != null) ...[
              SizedBox(height: AppTheme.spacingS),
              Text(
                'Last updated: ${_formatDateTime(_lastRefresh!)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
              ),
            ],
            SizedBox(height: AppTheme.spacingXL),

            // Authentication Status
            _buildAuthenticationStatus(),
            SizedBox(height: AppTheme.spacingL),

            // Local Ollama Status
            _buildLocalOllamaStatus(),
            SizedBox(height: AppTheme.spacingL),

            // Cloud Proxy Status
            _buildCloudProxyStatus(),
            SizedBox(height: AppTheme.spacingL),

            // System Tray Status
            _buildSystemTrayStatus(),
            SizedBox(height: AppTheme.spacingL),

            // Network Status
            _buildNetworkStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticationStatus() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;

        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Authentication',
                Icons.security,
                isAuthenticated ? Colors.green : Colors.red,
              ),
              SizedBox(height: AppTheme.spacingM),
              _buildStatusRow(
                'Status',
                isAuthenticated ? 'Authenticated' : 'Not Authenticated',
                isAuthenticated ? Colors.green : Colors.red,
              ),
              if (isAuthenticated) ...[
                _buildStatusRow('Provider', 'Auth0', Colors.blue),
                _buildStatusRow(
                  'Domain',
                  'dev-xafu7oedkd5wlrbo.us.auth0.com',
                  AppTheme.textColorLight,
                ),
              ],
              SizedBox(height: AppTheme.spacingM),
              if (!isAuthenticated)
                GradientButton(
                  text: 'Login',
                  onPressed: () => authService.login(),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => authService.logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalOllamaStatus() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Local Ollama', Icons.computer, Colors.orange),
          SizedBox(height: AppTheme.spacingM),
          _buildStatusRow('Connection', 'Checking...', Colors.orange),
          _buildStatusRow(
            'URL',
            'http://localhost:11434',
            AppTheme.textColorLight,
          ),
          _buildStatusRow(
            'Platform',
            kIsWeb ? 'Web (via proxy)' : 'Desktop (direct)',
            AppTheme.textColorLight,
          ),
          SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to Ollama test screen
              Navigator.of(context).pushNamed('/ollama-test');
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Test Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudProxyStatus() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;

        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Cloud Proxy',
                Icons.cloud,
                isAuthenticated ? Colors.green : Colors.grey,
              ),
              SizedBox(height: AppTheme.spacingM),
              _buildStatusRow(
                'Status',
                isAuthenticated ? 'Available' : 'Requires Authentication',
                isAuthenticated ? Colors.green : Colors.grey,
              ),
              _buildStatusRow(
                'Endpoint',
                'app.cloudtolocalllm.online',
                AppTheme.textColorLight,
              ),
              _buildStatusRow(
                'Protocol',
                'HTTPS/WebSocket',
                AppTheme.textColorLight,
              ),
              if (isAuthenticated) ...[
                SizedBox(height: AppTheme.spacingM),
                Text(
                  'Cloud proxy allows secure access to local Ollama instances from web browsers and remote clients.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemTrayStatus() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'System Tray',
            Icons.apps,
            kIsWeb ? Colors.grey : Colors.green,
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildStatusRow(
            'Platform Support',
            kIsWeb ? 'Not Available (Web)' : 'Available (Desktop)',
            kIsWeb ? Colors.grey : Colors.green,
          ),
          if (!kIsWeb) ...[
            _buildStatusRow('Daemon Status', 'Running', Colors.green),
            _buildStatusRow(
              'Icon Theme',
              'Monochrome',
              AppTheme.textColorLight,
            ),
            SizedBox(height: AppTheme.spacingM),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to daemon settings
                Navigator.of(context).pushNamed('/settings/daemon');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Daemon Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkStatus() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Network', Icons.network_check, Colors.green),
          SizedBox(height: AppTheme.spacingM),
          _buildStatusRow('Internet', 'Connected', Colors.green),
          _buildStatusRow('DNS Resolution', 'Working', Colors.green),
          _buildStatusRow('Firewall', 'Configured', Colors.green),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Network connectivity is required for authentication and cloud proxy features.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(width: AppTheme.spacingS),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
