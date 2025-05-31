/// Application configuration constants
class AppConfig {
  // App Information
  static const String appName = 'CloudToLocalLLM';
  static const String appVersion = '2.0.0';
  static const String appDescription =
      'Manage and run powerful Large Language Models locally, orchestrated via a cloud interface.';

  // URLs
  static const String homepageUrl = 'https://cloudtolocalllm.online';
  static const String appUrl = 'https://app.cloudtolocalllm.online';
  static const String githubUrl =
      'https://github.com/imrightguy/CloudToLocalLLM';

  // Auth0 Configuration
  static const String auth0Domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';
  static const String auth0ClientId = 'H10eY1pG9e2g6MvFKPDFbJ3ASIhxDgNu';
  static const String auth0RedirectUri =
      'https://app.cloudtolocalllm.online/callback';
  static const String auth0Audience = 'https://api.cloudtolocalllm.online';

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
  static const bool enableDebugMode = false;
}
