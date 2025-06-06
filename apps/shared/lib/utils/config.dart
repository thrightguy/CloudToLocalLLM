import 'dart:io';

/// Shared configuration constants for CloudToLocalLLM applications
class AppConfig {
  // Application Information
  static const String appName = 'CloudToLocalLLM';
  static const String appVersion = '3.2.1';
  static const String appDescription = 'Your Personal AI Powerhouse';

  // Auth0 Configuration
  static const String auth0Domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';
  static const String auth0ClientId = 'H10eY1pG9e2g6MvFKPDFbJ3ASIhxDgNu';
  static const String auth0Audience = 'https://api.cloudtolocalllm.online';
  static const String webCallbackUrl =
      'https://app.cloudtolocalllm.online/callback';
  static const String desktopCallbackUrl = 'http://localhost:8080/callback';

  // IPC Configuration
  static const String ipcHost = 'localhost';
  static const int chatTunnelPort = 8181;
  static const int trayChatPort = 8183;
  static const int trayTunnelPort = 8184;
  static const int trayHealthPort = 8185;
  static const int webProxyPort = 8182;

  // Ollama Configuration
  static const String ollamaBaseUrl = 'http://localhost:11434';
  static const Duration ollamaTimeout = Duration(seconds: 30);

  // Application Timeouts
  static const Duration ipcConnectionTimeout = Duration(seconds: 5);
  static const Duration ipcMessageTimeout = Duration(seconds: 30);
  static const Duration trayInitTimeout = Duration(seconds: 10);
  static const Duration healthCheckInterval = Duration(seconds: 30);

  // Retry Configuration
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);

  // File Paths
  static const String logDirectory = '/tmp';
  static const String configDirectory = '.cloudtolocalllm';

  // Theme Configuration
  static const bool enableDarkMode = true;
  static const bool enableAnimations = true;

  // Feature Flags
  static const bool enableCloudSync = false; // Coming Soon
  static const bool enableSystemTray = true;
  static const bool enableAutoStart = false;

  /// Get the appropriate callback URL based on platform
  static String get callbackUrl {
    if (Platform.isAndroid || Platform.isIOS) {
      return desktopCallbackUrl; // Mobile uses same as desktop for now
    } else {
      return desktopCallbackUrl;
    }
  }

  /// Get the user's home directory
  static String get homeDirectory {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
  }

  /// Get the application config directory path
  static String get configDirectoryPath {
    return '$homeDirectory/$configDirectory';
  }

  /// Check if running on a supported platform
  static bool get isSupportedPlatform {
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  /// Check if running on Linux
  static bool get isLinux => Platform.isLinux;

  /// Check if running on Windows
  static bool get isWindows => Platform.isWindows;

  /// Check if running on macOS
  static bool get isMacOS => Platform.isMacOS;

  /// Get the desktop environment (Linux only)
  static String? get desktopEnvironment {
    if (!Platform.isLinux) return null;
    return Platform.environment['XDG_CURRENT_DESKTOP'];
  }

  /// Get the desktop session (Linux only)
  static String? get desktopSession {
    if (!Platform.isLinux) return null;
    return Platform.environment['DESKTOP_SESSION'];
  }

  /// Check if system tray is likely supported
  static bool get isSystemTraySupported {
    if (!isSupportedPlatform) return false;

    if (Platform.isLinux) {
      final desktop = desktopEnvironment?.toLowerCase();
      if (desktop == null) return false;

      const supportedDesktops = [
        'gnome',
        'kde',
        'xfce',
        'mate',
        'cinnamon',
        'lxde',
        'lxqt',
      ];

      return supportedDesktops.any((d) => desktop.contains(d));
    }

    return true; // Windows and macOS generally support system tray
  }
}
