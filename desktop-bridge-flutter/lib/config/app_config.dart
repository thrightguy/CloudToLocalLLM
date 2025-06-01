import 'package:flutter/foundation.dart';

/// Application configuration constants for the desktop bridge
class AppConfig {
  // App Information
  static const String appName = 'CloudToLocalLLM Bridge';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Secure bridge connecting local Ollama to CloudToLocalLLM cloud service';

  // URLs
  static const String homepageUrl = 'https://cloudtolocalllm.online';
  static const String appUrl = 'https://app.cloudtolocalllm.online';
  static const String githubUrl = 'https://github.com/imrightguy/CloudToLocalLLM';

  // Auth0 Configuration (same as main app)
  static const String auth0Domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';
  static const String auth0Audience = 'https://app.cloudtolocalllm.online';
  static const String auth0Issuer = 'https://dev-xafu7oedkd5wlrbo.us.auth0.com/';
  
  // Desktop-specific client ID (different from web app)
  static const String auth0ClientId = 'ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29';
  static const String auth0DesktopRedirectUri = 'http://localhost:3025/callback';
  
  // OAuth2 Scopes
  static const List<String> auth0Scopes = ['openid', 'profile', 'email'];

  // Ollama Configuration
  static const String defaultOllamaHost = 'localhost';
  static const int defaultOllamaPort = 11434;
  static const String defaultOllamaUrl = 'http://localhost:11434';
  static const Duration ollamaTimeout = Duration(seconds: 60);

  // Cloud Configuration
  static const String cloudWebSocketUrl = 'wss://app.cloudtolocalllm.online/ws/bridge';
  static const String cloudStatusUrl = 'https://app.cloudtolocalllm.online/api/ollama/bridge/status';
  static const String cloudRegisterUrl = 'https://app.cloudtolocalllm.online/api/ollama/bridge/register';

  // Bridge Configuration
  static const int bridgePort = 3025;
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const int maxReconnectAttempts = 10;

  // UI Configuration
  static const double windowWidth = 400.0;
  static const double windowHeight = 300.0;
  static const double settingsWindowWidth = 600.0;
  static const double settingsWindowHeight = 500.0;

  // Feature Flags
  static const bool enableDebugMode = kDebugMode;
  static const bool enableVerboseLogging = kDebugMode;
  static const bool enableSystemTray = true;
  static const bool enableAutoStart = false;

  // Storage Keys
  static const String storageKeyAuthTokens = 'auth_tokens';
  static const String storageKeyBridgeConfig = 'bridge_config';
  static const String storageKeyUserPreferences = 'user_preferences';

  // Notification Settings
  static const String notificationAppName = 'CloudToLocalLLM Bridge';
  static const Duration notificationDuration = Duration(seconds: 5);

  // Logging Configuration
  static const String logFileName = 'cloudtolocalllm_bridge.log';
  static const int maxLogFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxLogFiles = 5;

  // System Tray Configuration
  static const String trayIconPath = 'assets/icons/tray_icon.png';
  static const String trayIconConnectedPath = 'assets/icons/tray_icon_connected.png';
  static const String trayIconDisconnectedPath = 'assets/icons/tray_icon_disconnected.png';
  static const String trayIconErrorPath = 'assets/icons/tray_icon_error.png';

  // Development mode settings
  static const bool enableDevMode = kDebugMode;
  static const String devModeUser = 'dev@cloudtolocalllm.online';

  // Validation helpers
  static bool get isValidOllamaUrl {
    try {
      final uri = Uri.parse(defaultOllamaUrl);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  static bool get isValidCloudUrl {
    try {
      final uri = Uri.parse(cloudWebSocketUrl);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  // Debug logging for configuration
  static void logConfiguration() {
    if (enableDebugMode) {
      debugPrint('[DEBUG] AppConfig loaded:');
      debugPrint('[DEBUG] - App Name: $appName');
      debugPrint('[DEBUG] - App Version: $appVersion');
      debugPrint('[DEBUG] - Ollama URL: $defaultOllamaUrl');
      debugPrint('[DEBUG] - Cloud WebSocket URL: $cloudWebSocketUrl');
      debugPrint('[DEBUG] - Auth0 Domain: $auth0Domain');
      debugPrint('[DEBUG] - Auth0 Client ID: $auth0ClientId');
      debugPrint('[DEBUG] - Bridge Port: $bridgePort');
      debugPrint('[DEBUG] - System Tray Enabled: $enableSystemTray');
      debugPrint('[DEBUG] - Auto Start Enabled: $enableAutoStart');
    }
  }

  // Environment-specific configurations
  static String get environmentName {
    if (kDebugMode) return 'development';
    if (kProfileMode) return 'profile';
    return 'production';
  }

  static bool get isProduction => environmentName == 'production';
  static bool get isDevelopment => environmentName == 'development';
  static bool get isProfile => environmentName == 'profile';

  // Platform-specific configurations
  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  // Get platform-specific paths
  static String get platformName {
    if (isLinux) return 'linux';
    if (isWindows) return 'windows';
    if (isMacOS) return 'macos';
    return 'unknown';
  }

  // Timeout configurations
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration authTimeout = Duration(minutes: 5);
  static const Duration tunnelTimeout = Duration(seconds: 60);

  // Error retry configurations
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration exponentialBackoffBase = Duration(seconds: 1);

  // WebSocket configurations
  static const Duration websocketPingInterval = Duration(seconds: 30);
  static const Duration websocketPongTimeout = Duration(seconds: 10);
  static const int websocketMaxReconnectAttempts = 5;
}
