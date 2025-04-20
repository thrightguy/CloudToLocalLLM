import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/storage_service.dart';
import '../services/tunnel_service.dart';
import '../services/ollama_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService storageService;
  final TunnelService tunnelService;
  final OllamaService ollamaService;

  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';

  // Settings
  ThemeMode _themeMode = ThemeMode.system;
  String _llmProvider = AppConfig.defaultLlmProvider;
  bool _enableCloudSync = AppConfig.enableCloudSync;
  bool _enableOfflineMode = AppConfig.enableOfflineMode;
  bool _enableModelDownload = AppConfig.enableModelDownload;
  bool _enableTunnel = false;

  SettingsProvider({
    required this.storageService,
    required this.tunnelService,
    required this.ollamaService,
  });

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get error => _error;
  ThemeMode get themeMode => _themeMode;
  String get llmProvider => _llmProvider;
  bool get enableCloudSync => _enableCloudSync;
  bool get enableOfflineMode => _enableOfflineMode;
  bool get enableModelDownload => _enableModelDownload;
  bool get enableTunnel => _enableTunnel;
  bool get isTunnelConnected => tunnelService.isConnected.value;
  String get tunnelUrl => tunnelService.tunnelUrl.value;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);

    try {
      // Load settings from storage
      await _loadSettings();

      // Listen for tunnel status changes
      tunnelService.isConnected.addListener(_onTunnelStatusChanged);
      tunnelService.tunnelUrl.addListener(_onTunnelUrlChanged);

      _isInitialized = true;
      _error = '';
    } catch (e) {
      _error = 'Error initializing settings provider: $e';
      print(_error);
    } finally {
      _setLoading(false);
    }
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final settings = await storageService.getSettings();

      // Theme mode
      final themeModeStr = settings['themeMode'] as String? ?? 'system';
      _themeMode = _parseThemeMode(themeModeStr);

      // LLM provider
      _llmProvider = settings['llmProvider'] as String? ?? AppConfig.defaultLlmProvider;

      // Feature flags
      _enableCloudSync = settings['enableCloudSync'] as bool? ?? AppConfig.enableCloudSync;
      _enableOfflineMode = settings['enableOfflineMode'] as bool? ?? AppConfig.enableOfflineMode;
      _enableModelDownload = settings['enableModelDownload'] as bool? ?? AppConfig.enableModelDownload;
      _enableTunnel = settings['enableTunnel'] as bool? ?? false;

      // Start tunnel if enabled
      if (_enableTunnel) {
        await _startTunnel();
      }

      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
      // Use defaults
    }
  }

  // Save settings to storage
  Future<void> _saveSettings() async {
    try {
      final settings = {
        'themeMode': _themeModeToString(_themeMode),
        'llmProvider': _llmProvider,
        'enableCloudSync': _enableCloudSync,
        'enableOfflineMode': _enableOfflineMode,
        'enableModelDownload': _enableModelDownload,
        'enableTunnel': _enableTunnel,
      };

      await storageService.saveSettings(settings);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  // Set LLM provider
  Future<void> setLlmProvider(String provider) async {
    if (_llmProvider == provider) return;

    _llmProvider = provider;
    await _saveSettings();

    // Update the OllamaService with the new base URL
    try {
      // Update the base URL based on the provider
      final newBaseUrl = provider == 'lmstudio' 
          ? AppConfig.lmStudioBaseUrl 
          : AppConfig.ollamaBaseUrl;

      ollamaService.updateBaseUrl(newBaseUrl);

      // Note: The LlmProvider will be notified of the change through the ChangeNotifierProxyProvider
      // and will refresh its models accordingly
    } catch (e) {
      print('Error updating OllamaService base URL: $e');
    }

    notifyListeners();
  }

  // Set cloud sync
  Future<void> setEnableCloudSync(bool enable) async {
    _enableCloudSync = enable;
    await _saveSettings();
    notifyListeners();
  }

  // Set offline mode
  Future<void> setEnableOfflineMode(bool enable) async {
    _enableOfflineMode = enable;
    await _saveSettings();
    notifyListeners();
  }

  // Set model download
  Future<void> setEnableModelDownload(bool enable) async {
    _enableModelDownload = enable;
    await _saveSettings();
    notifyListeners();
  }

  // Set tunnel
  Future<void> setEnableTunnel(bool enable) async {
    if (_enableTunnel == enable) return;

    _enableTunnel = enable;

    if (enable) {
      await _startTunnel();
    } else {
      await _stopTunnel();
    }

    await _saveSettings();
    notifyListeners();
  }

  // Start the tunnel
  Future<bool> _startTunnel() async {
    try {
      return await tunnelService.startTunnel();
    } catch (e) {
      print('Error starting tunnel: $e');
      return false;
    }
  }

  // Stop the tunnel
  Future<void> _stopTunnel() async {
    try {
      await tunnelService.stopTunnel();
    } catch (e) {
      print('Error stopping tunnel: $e');
    }
  }

  // Check tunnel status
  Future<bool> checkTunnelStatus() async {
    try {
      return await tunnelService.checkTunnelStatus();
    } catch (e) {
      print('Error checking tunnel status: $e');
      return false;
    }
  }

  // Reset settings to defaults
  Future<void> resetSettings() async {
    _themeMode = ThemeMode.system;
    _llmProvider = AppConfig.defaultLlmProvider;
    _enableCloudSync = AppConfig.enableCloudSync;
    _enableOfflineMode = AppConfig.enableOfflineMode;
    _enableModelDownload = AppConfig.enableModelDownload;

    // Stop tunnel if it's running
    if (_enableTunnel) {
      await _stopTunnel();
    }
    _enableTunnel = false;

    await _saveSettings();
    notifyListeners();
  }

  // Handle tunnel status changes
  void _onTunnelStatusChanged() {
    notifyListeners();
  }

  // Handle tunnel URL changes
  void _onTunnelUrlChanged() {
    notifyListeners();
  }

  // Helper to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Helper to parse theme mode from string
  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  // Helper to convert theme mode to string
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  @override
  void dispose() {
    tunnelService.isConnected.removeListener(_onTunnelStatusChanged);
    tunnelService.tunnelUrl.removeListener(_onTunnelUrlChanged);
    super.dispose();
  }
}
