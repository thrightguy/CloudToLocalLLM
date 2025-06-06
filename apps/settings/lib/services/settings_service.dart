import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Settings service for CloudToLocalLLM configuration management
///
/// Manages application settings including:
/// - Connection preferences (local Ollama vs cloud proxy)
/// - Authentication settings
/// - UI preferences
/// - System integration settings
class SettingsService extends ChangeNotifier {
  Map<String, dynamic> _settings = {};
  String _status = 'Not Initialized';
  File? _settingsFile;

  /// Default settings values
  static const Map<String, dynamic> _defaultSettings = {
    'version': '3.2.1',
    'connectionMode': 'auto', // auto, local, cloud
    'ollamaUrl': 'http://localhost:11434',
    'cloudProxyUrl': 'https://api.cloudtolocalllm.online',
    'autoConnectOllama': true,
    'preferLocalConnection': true,
    'connectionTimeout': 10000, // milliseconds
    'retryAttempts': 3,
    'enableNotifications': true,
    'minimizeToTray': true,
    'startMinimized': false,
    'autoStartTray': true,
    'theme': 'dark', // light, dark, system
    'language': 'en',
    'logLevel': 'info', // debug, info, warning, error
    'enableTelemetry': false,
    'checkUpdates': true,
    'auth': {
      'rememberLogin': false,
      'autoLogin': false,
      'sessionTimeout': 3600000, // 1 hour in milliseconds
    },
    'ollama': {
      'defaultModel': '',
      'maxTokens': 2048,
      'temperature': 0.7,
      'topP': 0.9,
      'streamResponse': true,
    },
  };

  /// Get current settings status
  String get status => _status;

  /// Get setting value with type safety
  T get<T>(String key, [T? defaultValue]) {
    final keys = key.split('.');
    dynamic value = _settings;
    
    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        // Try to get from defaults
        value = _defaultSettings;
        for (final dk in keys) {
          if (value is Map<String, dynamic> && value.containsKey(dk)) {
            value = value[dk];
          } else {
            return defaultValue ?? value as T;
          }
        }
        break;
      }
    }
    
    return value as T? ?? defaultValue ?? value as T;
  }

  /// Set setting value
  Future<void> set(String key, dynamic value) async {
    final keys = key.split('.');
    Map<String, dynamic> current = _settings;
    
    // Navigate to the parent of the target key
    for (int i = 0; i < keys.length - 1; i++) {
      final k = keys[i];
      if (!current.containsKey(k) || current[k] is! Map<String, dynamic>) {
        current[k] = <String, dynamic>{};
      }
      current = current[k] as Map<String, dynamic>;
    }
    
    // Set the value
    current[keys.last] = value;
    
    await _saveSettings();
    notifyListeners();
  }

  /// Get all settings
  Map<String, dynamic> get settings => Map.from(_settings);

  /// Initialize settings service
  Future<bool> initialize() async {
    try {
      debugPrint("Initializing SettingsService...");
      _status = "Initializing";
      notifyListeners();

      // Get settings file path
      _settingsFile = File(_getSettingsFilePath());

      // Load existing settings or create default
      await _loadSettings();

      _status = "Initialized";
      notifyListeners();

      debugPrint("SettingsService initialized successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to initialize SettingsService: $e");
      _status = "Error: $e";
      notifyListeners();
      return false;
    }
  }

  /// Load settings from file
  Future<void> _loadSettings() async {
    try {
      if (_settingsFile == null) return;

      if (await _settingsFile!.exists()) {
        final settingsData = await _settingsFile!.readAsString();
        final loadedSettings = jsonDecode(settingsData) as Map<String, dynamic>;
        
        // Deep merge with defaults to ensure all keys exist
        _settings = _deepMerge(_defaultSettings, loadedSettings);
        
        debugPrint("Settings loaded from ${_settingsFile!.path}");
      } else {
        // Use default settings
        _settings = _deepCopy(_defaultSettings);
        await _saveSettings();
        debugPrint("Default settings created");
      }

      // Validate and migrate settings if needed
      await _validateAndMigrateSettings();
    } catch (e) {
      debugPrint("Failed to load settings, using defaults: $e");
      _settings = _deepCopy(_defaultSettings);
    }
  }

  /// Save settings to file
  Future<void> _saveSettings() async {
    try {
      if (_settingsFile == null) return;

      // Ensure directory exists
      await _settingsFile!.parent.create(recursive: true);

      // Write settings
      final settingsJson = jsonEncode(_settings);
      await _settingsFile!.writeAsString(settingsJson);

      debugPrint("Settings saved to ${_settingsFile!.path}");
    } catch (e) {
      debugPrint("Failed to save settings: $e");
    }
  }

  /// Validate and migrate settings
  Future<void> _validateAndMigrateSettings() async {
    bool needsSave = false;

    // Check version and migrate if needed
    final settingsVersion = _settings['version'] as String?;
    final currentVersion = _defaultSettings['version'] as String;

    if (settingsVersion != currentVersion) {
      debugPrint("Migrating settings from $settingsVersion to $currentVersion");
      _settings['version'] = currentVersion;
      needsSave = true;
    }

    // Validate connection settings
    final ollamaUrl = _settings['ollamaUrl'] as String?;
    if (ollamaUrl == null || !_isValidUrl(ollamaUrl)) {
      _settings['ollamaUrl'] = _defaultSettings['ollamaUrl'];
      needsSave = true;
    }

    // Validate timeout values
    if (_settings['connectionTimeout'] is! int || 
        (_settings['connectionTimeout'] as int) < 1000) {
      _settings['connectionTimeout'] = _defaultSettings['connectionTimeout'];
      needsSave = true;
    }

    if (needsSave) {
      await _saveSettings();
    }
  }

  /// Check if URL is valid
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Deep merge two maps
  Map<String, dynamic> _deepMerge(Map<String, dynamic> base, Map<String, dynamic> overlay) {
    final result = Map<String, dynamic>.from(base);
    
    for (final entry in overlay.entries) {
      if (result.containsKey(entry.key) && 
          result[entry.key] is Map<String, dynamic> && 
          entry.value is Map<String, dynamic>) {
        result[entry.key] = _deepMerge(
          result[entry.key] as Map<String, dynamic>,
          entry.value as Map<String, dynamic>,
        );
      } else {
        result[entry.key] = entry.value;
      }
    }
    
    return result;
  }

  /// Deep copy a map
  Map<String, dynamic> _deepCopy(Map<String, dynamic> original) {
    return jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
  }

  /// Get settings file path
  String _getSettingsFilePath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final platform = Platform.operatingSystem;

    String configDir;
    if (platform == 'windows') {
      configDir = path.join(
          Platform.environment['LOCALAPPDATA'] ?? home, 'CloudToLocalLLM');
    } else if (platform == 'macos') {
      configDir =
          path.join(home, 'Library', 'Application Support', 'CloudToLocalLLM');
    } else {
      configDir = path.join(home, '.cloudtolocalllm');
    }

    return path.join(configDir, 'settings.json');
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    _settings = _deepCopy(_defaultSettings);
    await _saveSettings();
    notifyListeners();
    debugPrint("Settings reset to defaults");
  }

  /// Export settings
  Map<String, dynamic> exportSettings() {
    return _deepCopy(_settings);
  }

  /// Import settings
  Future<bool> importSettings(Map<String, dynamic> newSettings) async {
    try {
      // Validate imported settings
      final validatedSettings = _deepMerge(_defaultSettings, newSettings);
      
      _settings = validatedSettings;
      await _saveSettings();
      notifyListeners();

      debugPrint("Settings imported successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to import settings: $e");
      return false;
    }
  }

  // Convenience getters for common settings
  String get connectionMode => get<String>('connectionMode', 'auto');
  String get ollamaUrl => get<String>('ollamaUrl', 'http://localhost:11434');
  String get cloudProxyUrl => get<String>('cloudProxyUrl', 'https://api.cloudtolocalllm.online');
  bool get autoConnectOllama => get<bool>('autoConnectOllama', true);
  bool get preferLocalConnection => get<bool>('preferLocalConnection', true);
  int get connectionTimeout => get<int>('connectionTimeout', 10000);
  int get retryAttempts => get<int>('retryAttempts', 3);
  bool get enableNotifications => get<bool>('enableNotifications', true);
  bool get minimizeToTray => get<bool>('minimizeToTray', true);
  bool get startMinimized => get<bool>('startMinimized', false);
  bool get autoStartTray => get<bool>('autoStartTray', true);
  String get theme => get<String>('theme', 'dark');
  String get language => get<String>('language', 'en');
  String get logLevel => get<String>('logLevel', 'info');

  // Auth settings
  bool get rememberLogin => get<bool>('auth.rememberLogin', false);
  bool get autoLogin => get<bool>('auth.autoLogin', false);
  int get sessionTimeout => get<int>('auth.sessionTimeout', 3600000);

  // Ollama settings
  String get defaultModel => get<String>('ollama.defaultModel', '');
  int get maxTokens => get<int>('ollama.maxTokens', 2048);
  double get temperature => get<double>('ollama.temperature', 0.7);
  double get topP => get<double>('ollama.topP', 0.9);
  bool get streamResponse => get<bool>('ollama.streamResponse', true);

  /// Cleanup resources
  @override
  Future<void> dispose() async {
    super.dispose();
  }
}
