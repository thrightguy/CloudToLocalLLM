import 'package:flutter/foundation.dart';

/// Global application configuration
class AppConfig {
  /// App version information
  static const String appVersion = "1.3.1";
  static const String buildNumber = "202405051630";

  /// Base URL for API calls
  static String get apiBaseUrl {
    if (kDebugMode) {
      // Development environment
      return 'http://localhost:3000/v1';
    } else {
      // Production environment
      return 'https://api.cloudtolocalllm.online/v1';
    }
  }

  /// Cloud service base URL
  static String get cloudBaseUrl {
    if (kDebugMode) {
      return 'http://localhost:3000';
    } else {
      return 'https://cloudtolocalllm.online';
    }
  }

  /// License verification settings
  static const Duration licenseVerificationInterval = Duration(days: 1);

  /// Maximum offline days for license
  static const int maxOfflineDays = 7;

  /// Flag to enable/disable license verification (for development)
  static final bool enableLicenseVerification = !kDebugMode;

  /// Trial license key
  static const String trialLicenseKey = 'FREE-TRIAL-KEY-123456';

  // LLM Service Configuration
  static const String ollamaBaseUrl = 'http://localhost:11434';
  static const String lmStudioBaseUrl = 'http://127.0.0.11:1234/v1';

  // Cloud Service Configuration
  static const bool useCloudAuthentication = true;

  // Authentication Configuration
  static const String auth0Domain = 'dev-v2f2p008x3dr74ww.us.auth0.com';
  static const String auth0ClientId = 'WBibIxpJlvVp64UlpfMqYxDyYC0XDWbU';
  static const String auth0RedirectUri =
      'https://cloudtolocalllm.online/auth0-callback.html';
  static const String auth0Audience = 'https://api.cloudtolocalllm.online';

  // Local Storage Keys
  static const String tokenStorageKey = 'auth_token';
  static const String userStorageKey = 'user_profile';
  static const String settingsStorageKey = 'app_settings';
  static const String authCodeStorageKey = 'auth_code';
  static const String authStateStorageKey = 'auth_state';

  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enableModelDownload = true;
  static const bool enableCloudSync = true;

  // Default Settings
  static const String defaultLlmProvider = 'ollama'; // 'ollama' or 'lmstudio'
  static const String defaultModel = 'tinyllama';
  static const int maxContextLength = 4096;

  // Debug Settings
  static bool get isDebugMode => kDebugMode;

  // Premium Feature Settings
  static const bool freePremiumFeaturesDuringTesting =
      true; // Set to false when ready to monetize

  // Auth0 web authentication (used for desktop app)
  static const bool useExternalBrowser = true;
  static const int authSessionTimeout = 300; // 5 minutes
}
