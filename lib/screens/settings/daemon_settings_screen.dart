import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../components/modern_card.dart';
import '../../components/gradient_button.dart';

/// System Tray Daemon Settings Screen
class DaemonSettingsScreen extends StatefulWidget {
  const DaemonSettingsScreen({super.key});

  @override
  State<DaemonSettingsScreen> createState() => _DaemonSettingsScreenState();
}

class _DaemonSettingsScreenState extends State<DaemonSettingsScreen> {
  bool _enableSystemTray = true;
  bool _startMinimized = false;
  bool _enableNotifications = true;
  bool _autoStartDaemon = true;
  String _selectedTheme = 'system';
  int _connectionTimeout = 5;
  int _healthCheckInterval = 30;

  @override
  void initState() {
    super.initState();
    debugPrint("🔧 [DaemonSettingsScreen] Initializing screen");
    _loadSettings();
  }

  void _loadSettings() {
    // Load current daemon settings
    // This would typically load from a configuration file or service
    setState(() {
      _enableSystemTray = true;
      _startMinimized = false;
      _enableNotifications = true;
      _autoStartDaemon = true;
      _selectedTheme = 'system';
      _connectionTimeout = 5;
      _healthCheckInterval = 30;
    });
  }

  Future<void> _saveSettings() async {
    try {
      // Save settings to configuration
      // This would typically save to a configuration file or service

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daemon settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restartDaemon() async {
    try {
      // Restart the system tray daemon
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restarting system tray daemon...'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Add actual daemon restart logic here
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System tray daemon restarted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restart daemon: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🔧 [DaemonSettingsScreen] Building widget");
    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      appBar: AppBar(
        title: const Text('System Tray Daemon Settings'),
        backgroundColor: AppTheme.backgroundMain,
        foregroundColor: AppTheme.textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'System Tray Configuration',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              'Configure the system tray daemon behavior and appearance',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
            ),
            SizedBox(height: AppTheme.spacingXL),

            // General Settings
            _buildGeneralSettings(),
            SizedBox(height: AppTheme.spacingL),

            // Appearance Settings
            _buildAppearanceSettings(),
            SizedBox(height: AppTheme.spacingL),

            // Connection Settings
            _buildConnectionSettings(),
            SizedBox(height: AppTheme.spacingL),

            // Actions
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('General Settings', Icons.settings),
          SizedBox(height: AppTheme.spacingM),
          _buildSwitchTile(
            'Enable System Tray',
            'Show CloudToLocalLLM icon in system tray',
            _enableSystemTray,
            (value) => setState(() => _enableSystemTray = value),
          ),
          _buildSwitchTile(
            'Start Minimized',
            'Start application minimized to system tray',
            _startMinimized,
            (value) => setState(() => _startMinimized = value),
          ),
          _buildSwitchTile(
            'Enable Notifications',
            'Show system notifications for important events',
            _enableNotifications,
            (value) => setState(() => _enableNotifications = value),
          ),
          _buildSwitchTile(
            'Auto-start Daemon',
            'Automatically start tray daemon with system',
            _autoStartDaemon,
            (value) => setState(() => _autoStartDaemon = value),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Appearance', Icons.palette),
          SizedBox(height: AppTheme.spacingM),
          _buildDropdownTile(
            'Tray Icon Theme',
            'Choose icon style for system tray',
            _selectedTheme,
            ['system', 'light', 'dark', 'monochrome'],
            (value) => setState(() => _selectedTheme = value ?? 'system'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Connection Settings', Icons.network_check),
          SizedBox(height: AppTheme.spacingM),
          _buildSliderTile(
            'Connection Timeout',
            'Timeout for daemon connections (seconds)',
            _connectionTimeout.toDouble(),
            1.0,
            30.0,
            (value) => setState(() => _connectionTimeout = value.round()),
          ),
          _buildSliderTile(
            'Health Check Interval',
            'Interval for daemon health checks (seconds)',
            _healthCheckInterval.toDouble(),
            10.0,
            300.0,
            (value) => setState(() => _healthCheckInterval = value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Actions', Icons.build),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  text: 'Save Settings',
                  onPressed: _saveSettings,
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _restartDaemon,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart Daemon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(AppTheme.spacingM),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
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

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColorLight,
                ),
          ),
          SizedBox(height: AppTheme.spacingS),
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option.toUpperCase()),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                '${value.round()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColorLight,
                ),
          ),
          SizedBox(height: AppTheme.spacingS),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
