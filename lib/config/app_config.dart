import 'package:flutter/foundation.dart';

/// Application configuration constants
class AppConfig {
  // App Information
  static const String appName = 'CloudToLocalLLM';
  static const String appVersion = '3.9.1'; // Updated by build scripts
  static const String appDescription =
      'Manage and run powerful Large Language Models locally, orchestrated via a cloud interface.';

  // URLs
  static const String homepageUrl = 'https://cloudtolocalllm.online';
  static const String appUrl = 'https://app.cloudtolocalllm.online';
  static const String githubUrl =
      'https://github.com/imrightguy/CloudToLocalLLM';
  static const String githubReleasesUrl =
      'https://github.com/imrightguy/CloudToLocalLLM/releases/latest';

  // Auth0 Configuration
  static const String auth0Domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';
  static const String auth0Audience = 'https://app.cloudtolocalllm.online';
  static const String auth0Issuer =
      'https://dev-xafu7oedkd5wlrbo.us.auth0.com/';

  // Universal Client Configuration (works for both web and desktop)
  static const String auth0ClientId = 'ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29';

  // Platform-specific redirect URIs
  static const String auth0WebRedirectUri =
      'https://app.cloudtolocalllm.online/callback';
  static const String auth0DesktopRedirectUri =
      'http://localhost:8080/callback';

  // OAuth2 Scopes
  static const List<String> auth0Scopes = ['openid', 'profile', 'email'];

  // Development mode settings
  static const bool enableDevMode = true; // Set to false for production
  static const String devModeUser = 'dev@cloudtolocalllm.online';

  // API Configuration
  static const String apiBaseUrl = 'https://api.cloudtolocalllm.online';
  static const Duration apiTimeout = Duration(seconds: 30);

  // UI Configuration
  static const double maxContentWidth = 1200.0;
  static const double mobileBreakpoint = 768.0;
  static const double tabletBreakpoint = 1024.0;

  // Feature Flags
  static const bool enableDarkMode = true;
  static const bool enableAnalytics = false; // Disabled for privacy
  static const bool enableDebugMode = true; // Enabled for v3.5.2 development

  // Enhanced debug features for v3.5.2
  static const bool showTunnelDebugInfo = true;
  static const bool enableVerboseLogging = true;

  // Ollama Configuration (Direct Local Connection for Desktop)
  static const String defaultOllamaHost = 'localhost';
  static const int defaultOllamaPort = 11434;
  static const String defaultOllamaUrl = 'http://localhost:11434';
  static const Duration ollamaTimeout = Duration(seconds: 60);

  // Cloud Relay Configuration (for web/mobile)
  static const String cloudOllamaUrl =
      'https://app.cloudtolocalllm.online/api/ollama';

  // Admin Interface Configuration
  static const bool enableAdminInterface = true;
  static const int adminServerPort = 3001;

  // Platform-specific admin server URLs
  static const String adminServerUrlWeb =
      'https://app.cloudtolocalllm.online:3001';
  static const String adminServerUrlDesktop = 'http://localhost:3001';

  // Get admin server URL based on platform
  static String get adminServerUrl =>
      kIsWeb ? adminServerUrlWeb : adminServerUrlDesktop;
  static String get adminApiBaseUrl => '$adminServerUrl/api/admin';

  static const Duration adminApiTimeout = Duration(seconds: 45);

  // Admin Interface Feature Flags
  static const bool enableAdminSystemMonitoring = true;
  static const bool enableAdminUserManagement = true;
  static const bool enableAdminConfigManagement = true;
  static const bool enableAdminContainerManagement = true;
  static const bool enableAdminDataFlush = true;

  // Admin Interface Security Settings
  static const bool requireAdminRole = true;
  static const bool enableAdminAuditLogging = true;
  static const bool enableAdminRateLimiting = true;
  static const int adminSessionTimeoutMinutes = 30;

  // Admin Interface UI Configuration
  static const int adminDashboardRefreshIntervalSeconds = 30;
  static const int adminRealtimeUpdateIntervalSeconds = 5;
  static const bool enableAdminDarkMode = true;
  static const bool showAdminDebugInfo = enableDebugMode;

  // Debug logging for configuration
  static void logConfiguration() {
    debugPrint('[DEBUG] AppConfig loaded:');
    debugPrint('[DEBUG] - Ollama URL: $defaultOllamaUrl');
    debugPrint('[DEBUG] - Bridge Status URL: $bridgeStatusUrl');
    debugPrint('[DEBUG] - Bridge Register URL: $bridgeRegisterUrl');
    debugPrint('[DEBUG] - Admin Server URL: $adminServerUrl');
    debugPrint('[DEBUG] - Admin API Base URL: $adminApiBaseUrl');
  }

  // Bridge Configuration
  static const String bridgeStatusUrl =
      'https://app.cloudtolocalllm.online/api/ollama/bridge/status';
  static const String bridgeRegisterUrl =
      'https://app.cloudtolocalllm.online/api/ollama/bridge/register';
}
