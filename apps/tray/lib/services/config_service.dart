import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Configuration service for tray application
///
/// Manages tray service configuration including:
/// - Startup behavior settings
/// - Icon preferences
/// - IPC communication settings
/// - Authentication state persistence
class ConfigService extends ChangeNotifier {
  Map<String, dynamic> _config = {};
  String _status = 'Not Initialized';
  File? _configFile;

  /// Default configuration values
  static const Map<String, dynamic> _defaultConfig = {
    'version': '3.2.1',
    'autoStart': true,
    'minimizeToTray': true,
    'showNotifications': true,
    'iconTheme': 'monochrome', // monochrome, colored
    'ipcPort': 0, // 0 for auto-assign
    'logLevel': 'info', // debug, info, warning, error
    'authenticationPersist': false,
    'connectionTimeout': 5000, // milliseconds
    'heartbeatInterval': 30000, // milliseconds
  };

  /// Get current configuration status
  String get status => _status;

  /// Get configuration value
  T get<T>(String key, [T? defaultValue]) {
    return _config[key] as T? ?? defaultValue ?? _defaultConfig[key] as T;
  }

  /// Set configuration value
  Future<void> set(String key, dynamic value) async {
    _config[key] = value;
    await _saveConfig();
    notifyListeners();
  }

  /// Get all configuration
  Map<String, dynamic> get config => Map.from(_config);

  /// Initialize configuration service
  Future<bool> initialize() async {
    try {
      debugPrint("Initializing ConfigService...");
      _status = "Initializing";
      notifyListeners();

      // Get config file path
      _configFile = File(_getConfigFilePath());

      // Load existing config or create default
      await _loadConfig();

      _status = "Initialized";
      notifyListeners();

      debugPrint("ConfigService initialized successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to initialize ConfigService: $e");
      _status = "Error: $e";
      notifyListeners();
      return false;
    }
  }

  /// Load configuration from file
  Future<void> _loadConfig() async {
    try {
      if (_configFile == null) return;

      if (await _configFile!.exists()) {
        final configData = await _configFile!.readAsString();
        final loadedConfig = jsonDecode(configData) as Map<String, dynamic>;

        // Merge with defaults to ensure all keys exist
        _config = Map.from(_defaultConfig);
        _config.addAll(loadedConfig);

        debugPrint("Configuration loaded from ${_configFile!.path}");
      } else {
        // Use default configuration
        _config = Map.from(_defaultConfig);
        await _saveConfig();
        debugPrint("Default configuration created");
      }

      // Validate and migrate config if needed
      await _validateAndMigrateConfig();
    } catch (e) {
      debugPrint("Failed to load config, using defaults: $e");
      _config = Map.from(_defaultConfig);
    }
  }

  /// Save configuration to file
  Future<void> _saveConfig() async {
    try {
      if (_configFile == null) return;

      // Ensure directory exists
      await _configFile!.parent.create(recursive: true);

      // Write configuration
      final configJson = jsonEncode(_config);
      await _configFile!.writeAsString(configJson);

      debugPrint("Configuration saved to ${_configFile!.path}");
    } catch (e) {
      debugPrint("Failed to save configuration: $e");
    }
  }

  /// Validate and migrate configuration
  Future<void> _validateAndMigrateConfig() async {
    bool needsSave = false;

    // Check version and migrate if needed
    final configVersion = _config['version'] as String?;
    final currentVersion = _defaultConfig['version'] as String;

    if (configVersion != currentVersion) {
      debugPrint("Migrating config from $configVersion to $currentVersion");
      _config['version'] = currentVersion;
      needsSave = true;
    }

    // Ensure all default keys exist
    for (final entry in _defaultConfig.entries) {
      if (!_config.containsKey(entry.key)) {
        _config[entry.key] = entry.value;
        needsSave = true;
      }
    }

    // Validate value types and ranges
    if (_config['connectionTimeout'] is! int ||
        (_config['connectionTimeout'] as int) < 1000) {
      _config['connectionTimeout'] = _defaultConfig['connectionTimeout'];
      needsSave = true;
    }

    if (_config['heartbeatInterval'] is! int ||
        (_config['heartbeatInterval'] as int) < 10000) {
      _config['heartbeatInterval'] = _defaultConfig['heartbeatInterval'];
      needsSave = true;
    }

    if (needsSave) {
      await _saveConfig();
    }
  }

  /// Get configuration file path
  String _getConfigFilePath() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final platform = Platform.operatingSystem;

    String configDir;
    if (platform == 'windows') {
      configDir = path.join(
        Platform.environment['LOCALAPPDATA'] ?? home,
        'CloudToLocalLLM',
      );
    } else if (platform == 'macos') {
      configDir = path.join(
        home,
        'Library',
        'Application Support',
        'CloudToLocalLLM',
      );
    } else {
      configDir = path.join(home, '.cloudtolocalllm');
    }

    return path.join(configDir, 'tray_config.json');
  }

  /// Reset configuration to defaults
  Future<void> resetToDefaults() async {
    _config = Map.from(_defaultConfig);
    await _saveConfig();
    notifyListeners();
    debugPrint("Configuration reset to defaults");
  }

  /// Export configuration
  Map<String, dynamic> exportConfig() {
    return Map.from(_config);
  }

  /// Import configuration
  Future<bool> importConfig(Map<String, dynamic> newConfig) async {
    try {
      // Validate imported config
      final validatedConfig = Map<String, dynamic>.from(_defaultConfig);

      for (final entry in newConfig.entries) {
        if (_defaultConfig.containsKey(entry.key)) {
          validatedConfig[entry.key] = entry.value;
        }
      }

      _config = validatedConfig;
      await _saveConfig();
      notifyListeners();

      debugPrint("Configuration imported successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to import configuration: $e");
      return false;
    }
  }

  /// Get startup behavior settings
  bool get autoStart => get<bool>('autoStart', true);
  bool get minimizeToTray => get<bool>('minimizeToTray', true);
  bool get showNotifications => get<bool>('showNotifications', true);

  /// Get icon settings
  String get iconTheme => get<String>('iconTheme', 'monochrome');

  /// Get IPC settings
  int get ipcPort => get<int>('ipcPort', 0);
  int get connectionTimeout => get<int>('connectionTimeout', 5000);
  int get heartbeatInterval => get<int>('heartbeatInterval', 30000);

  /// Get authentication settings
  bool get authenticationPersist => get<bool>('authenticationPersist', false);

  /// Get logging settings
  String get logLevel => get<String>('logLevel', 'info');

  /// Update startup settings
  Future<void> updateStartupSettings({
    bool? autoStart,
    bool? minimizeToTray,
    bool? showNotifications,
  }) async {
    if (autoStart != null) await set('autoStart', autoStart);
    if (minimizeToTray != null) await set('minimizeToTray', minimizeToTray);
    if (showNotifications != null) {
      await set('showNotifications', showNotifications);
    }
  }

  /// Update icon settings
  Future<void> updateIconSettings({String? iconTheme}) async {
    if (iconTheme != null) await set('iconTheme', iconTheme);
  }

  /// Update IPC settings
  Future<void> updateIPCSettings({
    int? ipcPort,
    int? connectionTimeout,
    int? heartbeatInterval,
  }) async {
    if (ipcPort != null) await set('ipcPort', ipcPort);
    if (connectionTimeout != null) {
      await set('connectionTimeout', connectionTimeout);
    }
    if (heartbeatInterval != null) {
      await set('heartbeatInterval', heartbeatInterval);
    }
  }

  /// Cleanup resources
  @override
  void dispose() {
    super.dispose();
  }
}
