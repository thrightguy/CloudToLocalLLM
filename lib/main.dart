import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/enhanced_tray_service.dart';
import 'services/unified_connection_service.dart';
import 'services/window_manager_service.dart';

// Global navigator key for navigation from system tray
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to system tray daemon for desktop platforms (only on non-web)
  // The tray daemon should be running independently as a service
  if (!kIsWeb && _isDesktopPlatform()) {
    await _connectToSystemTray();
  } else {
    // Show main window by default for web and unsupported platforms
    await _showMainWindow();
  }

  runApp(const CloudToLocalLLMApp());
}

/// Check if running on desktop platform using Flutter's platform detection
bool _isDesktopPlatform() {
  try {
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
  } catch (e) {
    return false;
  }
}

/// Connect to the independent system tray daemon
Future<void> _connectToSystemTray() async {
  try {
    if (kDebugMode) {
      debugPrint("Connecting to system tray daemon...");
    }

    final enhancedTray = EnhancedTrayService();
    final windowManager = WindowManagerService();
    final connectionService = UnifiedConnectionService();

    // Initialize enhanced tray service
    bool success = false;
    try {
      success = await enhancedTray.initialize(
        onShowWindow: () async {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to show window");
          }
          await windowManager.showWindow();
        },
        onHideWindow: () async {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to hide window");
          }
          await windowManager.hideToTray();
        },
        onSettings: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to open settings");
          }
          _navigateToSettings();
        },
        onQuit: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to quit application");
          }
          SystemNavigator.pop();
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint("Enhanced tray initialization timed out");
          return false;
        },
      );
    } catch (e) {
      debugPrint("Enhanced tray initialization failed with error: $e");
      success = false;
    }

    if (success) {
      await enhancedTray.setTooltip('CloudToLocalLLM - Connected');

      if (kDebugMode) {
        debugPrint("Connected to enhanced tray daemon successfully");
        debugPrint("Application will be controlled by enhanced tray daemon");
      }

      // Initialize connection service
      await connectionService.initialize();

      // Set up authentication status monitoring
      _setupAuthenticationMonitoring(enhancedTray);

      // Show main window
      await _showMainWindow();
    } else {
      if (kDebugMode) {
        debugPrint(
            "Could not connect to enhanced tray daemon, showing main window");
      }
      await _showMainWindow();
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint("System tray connection error: $e");
      debugPrint("Falling back to main window mode");
    }
    await _showMainWindow();
  }
}

/// Show the main window as fallback when system tray is not available
Future<void> _showMainWindow() async {
  try {
    final windowManager = WindowManagerService();
    await windowManager.showWindow();
    if (kDebugMode) {
      debugPrint("Main window shown as fallback");
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Failed to show main window: $e");
    }
  }
}

/// Main application widget with clean architecture
class CloudToLocalLLMApp extends StatelessWidget {
  const CloudToLocalLLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication service
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),
        // Streaming proxy service
        ChangeNotifierProvider(
          create: (context) => StreamingProxyService(
            authService: context.read<AuthService>(),
          ),
        ),
        // Unified connection service
        ChangeNotifierProvider(
          create: (_) => UnifiedConnectionService(),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
          return MaterialApp.router(
            // App configuration
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,

            // Theme configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light,

            // Router configuration
            routerConfig: AppRouter.createRouter(navigatorKey: navigatorKey),

            // Builder for additional configuration
            builder: (context, child) {
              return MediaQuery(
                // Ensure text scaling doesn't break the UI
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context)
                        .textScaler
                        .scale(1.0)
                        .clamp(0.8, 1.2),
                  ),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

/// Navigate to settings screen from system tray
void _navigateToSettings() {
  try {
    final context = navigatorKey.currentContext;
    if (context != null) {
      if (kDebugMode) {
        debugPrint("Navigating to settings screen via system tray");
      }
      context.go('/settings');
    } else {
      if (kDebugMode) {
        debugPrint("Cannot navigate to settings: no context available");
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Error navigating to settings: $e");
    }
  }
}

/// Set up authentication status monitoring for enhanced tray
void _setupAuthenticationMonitoring(EnhancedTrayService enhancedTray) {
  try {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Send initial authentication status
      enhancedTray.updateAuthStatus(authService.isAuthenticated.value);

      // Listen for authentication changes
      authService.isAuthenticated.addListener(() {
        final isAuthenticated = authService.isAuthenticated.value;
        if (kDebugMode) {
          debugPrint(
              "Auth status changed, updating enhanced tray daemon: $isAuthenticated");
        }
        enhancedTray.updateAuthStatus(isAuthenticated);

        // Update auth token if authenticated
        if (isAuthenticated) {
          final token = authService.getAccessToken();
          if (token != null) {
            enhancedTray.updateAuthToken(token);
          }
        } else {
          enhancedTray.updateAuthToken('');
        }
      });

      if (kDebugMode) {
        debugPrint("Authentication monitoring set up for enhanced tray");
      }
    } else {
      if (kDebugMode) {
        debugPrint("Cannot set up auth monitoring: no context available");
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Error setting up authentication monitoring: $e");
    }
  }
}
