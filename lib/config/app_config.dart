import 'package:flutter/foundation.dart';

class AppConfig {
  // LLM Service Configuration
  static const String ollamaBaseUrl = 'http://localhost:11434';
  static const String lmStudioBaseUrl = 'http://127.0.0.11:1234/v1';

  // Cloud Service Configuration
  static const String cloudBaseUrl = 'https://cloudtolocalllm.example.com';
  static const bool useCloudAuthentication = true;

  // Authentication Configuration
  static const String auth0Domain = 'your-auth0-domain.auth0.com';
  static const String auth0ClientId = 'your-auth0-client-id';
  static const String auth0RedirectUri = 'com.cloudtolocalllm://login-callback';

  // Local Storage Keys
  static const String tokenStorageKey = 'auth_token';
  static const String userStorageKey = 'user_profile';
  static const String settingsStorageKey = 'app_settings';

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
}
