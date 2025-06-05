import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/tunnel_config.dart';

class ConfigService extends ChangeNotifier {
  static const String _configFileName = 'tunnel_config.json';

  TunnelConfig _config = TunnelConfig.defaultConfig;
  String? _configPath;
  StreamSubscription<FileSystemEvent>? _watcherSubscription;

  // Getters
  TunnelConfig get config => _config;
  String? get configPath => _configPath;
  bool get isWatching => _watcherSubscription != null;

  /// Initialize the configuration service
  Future<void> initialize() async {
    _configPath = await _getConfigFilePath();

    debugPrint('Initializing config service with path: $_configPath');

    // Load existing configuration or create default
    await _loadConfiguration();

    // Start watching for changes
    await _startConfigWatcher();

    debugPrint('Configuration service initialized successfully');
  }

  /// Dispose of resources
  @override
  void dispose() {
    _stopConfigWatcher();
    super.dispose();
  }

  /// Get the configuration file path
  Future<String> _getConfigFilePath() async {
    final configDir = await _getConfigDirectory();
    return path.join(configDir.path, _configFileName);
  }

  /// Get the configuration directory
  Future<Directory> _getConfigDirectory() async {
    late Directory configDir;

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        configDir = Directory(path.join(localAppData, 'CloudToLocalLLM'));
      } else {
        configDir = Directory(
          path.join(
            Platform.environment['USERPROFILE']!,
            'AppData',
            'Local',
            'CloudToLocalLLM',
          ),
        );
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME']!;
      configDir = Directory(
        path.join(home, 'Library', 'Application Support', 'CloudToLocalLLM'),
      );
    } else {
      // Linux and other Unix-like systems
      final home = Platform.environment['HOME']!;
      configDir = Directory(path.join(home, '.cloudtolocalllm'));
    }

    // Create directory if it doesn't exist
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
      debugPrint('Created config directory: ${configDir.path}');
    }

    return configDir;
  }

  /// Load configuration from file
  Future<void> _loadConfiguration() async {
    if (_configPath == null) return;

    final configFile = File(_configPath!);

    if (await configFile.exists()) {
      try {
        final configContent = await configFile.readAsString();
        final configJson = json.decode(configContent) as Map<String, dynamic>;

        _config = TunnelConfig.fromJson(configJson);

        // Validate configuration
        final validationErrors = _config.validate();
        if (validationErrors.isNotEmpty) {
          debugPrint(
            'Configuration validation warnings: ${validationErrors.join(', ')}',
          );
        }

        debugPrint('Configuration loaded successfully');
      } catch (e) {
        debugPrint('Failed to load configuration: $e');
        debugPrint('Using default configuration');
        _config = TunnelConfig.defaultConfig;

        // Save default configuration
        await _saveConfiguration();
      }
    } else {
      debugPrint('Configuration file not found, creating default');
      _config = TunnelConfig.defaultConfig;
      await _saveConfiguration();
    }

    notifyListeners();
  }

  /// Save configuration to file
  Future<void> _saveConfiguration() async {
    if (_configPath == null) return;

    try {
      final configFile = File(_configPath!);
      final configJson = _config.toJson();
      final configContent = const JsonEncoder.withIndent(
        '  ',
      ).convert(configJson);

      await configFile.writeAsString(configContent);
      debugPrint('Configuration saved successfully');
    } catch (e) {
      debugPrint('Failed to save configuration: $e');
      rethrow;
    }
  }

  /// Update configuration
  Future<void> updateConfig(TunnelConfig newConfig) async {
    // Validate new configuration
    final validationErrors = newConfig.validate();
    if (validationErrors.isNotEmpty) {
      throw Exception(
        'Configuration validation failed: ${validationErrors.join(', ')}',
      );
    }

    _config = newConfig;
    await _saveConfiguration();
    notifyListeners();

    debugPrint('Configuration updated successfully');
  }

  /// Update specific configuration values
  Future<void> updateConfigValues({
    bool? enableLocalOllama,
    String? ollamaHost,
    int? ollamaPort,
    bool? enableCloudProxy,
    String? cloudProxyUrl,
    int? apiServerPort,
    bool? enableApiServer,
    int? healthCheckInterval,
    bool? minimizeToTray,
    bool? showNotifications,
    String? logLevel,
    bool? autoStartTunnel,
  }) async {
    final updatedConfig = _config.copyWith(
      enableLocalOllama: enableLocalOllama,
      ollamaHost: ollamaHost,
      ollamaPort: ollamaPort,
      enableCloudProxy: enableCloudProxy,
      cloudProxyUrl: cloudProxyUrl,
      apiServerPort: apiServerPort,
      enableApiServer: enableApiServer,
      healthCheckInterval: healthCheckInterval,
      minimizeToTray: minimizeToTray,
      showNotifications: showNotifications,
      logLevel: logLevel,
      autoStartTunnel: autoStartTunnel,
    );

    await updateConfig(updatedConfig);
  }

  /// Reset configuration to defaults
  Future<void> resetToDefaults() async {
    await updateConfig(TunnelConfig.defaultConfig);
    debugPrint('Configuration reset to defaults');
  }

  /// Load development configuration
  Future<void> loadDevelopmentConfig() async {
    await updateConfig(TunnelConfig.developmentConfig);
    debugPrint('Development configuration loaded');
  }

  /// Load production configuration
  Future<void> loadProductionConfig() async {
    await updateConfig(TunnelConfig.productionConfig);
    debugPrint('Production configuration loaded');
  }

  /// Start watching configuration file for changes
  Future<void> _startConfigWatcher() async {
    if (_configPath == null) return;

    try {
      final configFile = File(_configPath!);
      final configDir = configFile.parent;

      final configWatcher = configDir.watch(events: FileSystemEvent.modify);
      _watcherSubscription = configWatcher.listen((event) {
        if (event.path == _configPath && event.type == FileSystemEvent.modify) {
          debugPrint('Configuration file changed, reloading...');
          _reloadConfiguration();
        }
      });

      debugPrint('Configuration file watcher started');
    } catch (e) {
      debugPrint('Failed to start configuration watcher: $e');
    }
  }

  /// Stop watching configuration file
  void _stopConfigWatcher() {
    _watcherSubscription?.cancel();
    _watcherSubscription = null;
    debugPrint('Configuration file watcher stopped');
  }

  /// Reload configuration from file (hot-reload)
  Future<void> _reloadConfiguration() async {
    try {
      final oldConfig = _config;
      await _loadConfiguration();

      // Check if configuration actually changed
      if (_config.toJson().toString() != oldConfig.toJson().toString()) {
        debugPrint('Configuration reloaded with changes');
        // Configuration change will be notified by _loadConfiguration
      } else {
        debugPrint('Configuration file changed but content is the same');
      }
    } catch (e) {
      debugPrint('Failed to reload configuration: $e');
    }
  }

  /// Export configuration to a file
  Future<void> exportConfig(String filePath) async {
    try {
      final exportFile = File(filePath);
      final configJson = _config.toJson();
      final configContent = const JsonEncoder.withIndent(
        '  ',
      ).convert(configJson);

      await exportFile.writeAsString(configContent);
      debugPrint('Configuration exported to: $filePath');
    } catch (e) {
      debugPrint('Failed to export configuration: $e');
      rethrow;
    }
  }

  /// Import configuration from a file
  Future<void> importConfig(String filePath) async {
    try {
      final importFile = File(filePath);

      if (!await importFile.exists()) {
        throw Exception('Import file does not exist: $filePath');
      }

      final configContent = await importFile.readAsString();
      final configJson = json.decode(configContent) as Map<String, dynamic>;
      final importedConfig = TunnelConfig.fromJson(configJson);

      await updateConfig(importedConfig);
      debugPrint('Configuration imported from: $filePath');
    } catch (e) {
      debugPrint('Failed to import configuration: $e');
      rethrow;
    }
  }

  /// Create a backup of current configuration
  Future<String> createBackup() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFileName = 'tunnel_config_backup_$timestamp.json';

    final configDir = await _getConfigDirectory();
    final backupPath = path.join(configDir.path, 'backups', backupFileName);

    // Create backups directory if it doesn't exist
    final backupsDir = Directory(path.dirname(backupPath));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    await exportConfig(backupPath);
    debugPrint('Configuration backup created: $backupPath');

    return backupPath;
  }

  /// Get configuration summary for debugging
  Map<String, dynamic> getConfigSummary() {
    return {
      'config_path': _configPath,
      'is_watching': isWatching,
      'local_ollama_enabled': _config.enableLocalOllama,
      'cloud_proxy_enabled': _config.enableCloudProxy,
      'api_server_enabled': _config.enableApiServer,
      'api_server_port': _config.apiServerPort,
      'health_check_interval': _config.healthCheckInterval,
      'log_level': _config.logLevel,
      'auto_start_tunnel': _config.autoStartTunnel,
      'validation_errors': _config.validate(),
    };
  }
}
