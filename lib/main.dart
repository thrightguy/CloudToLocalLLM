import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/system_tray_manager.dart';
import 'services/window_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize system tray for desktop platforms (only on non-web)
  // System tray is DISABLED by default due to Linux compatibility issues
  // Can be enabled with ENABLE_SYSTEM_TRAY=true environment variable
  if (!kIsWeb && _isDesktopPlatform() && _isSystemTrayEnabled()) {
    await _initializeSystemTray();
  } else {
    // Show main window by default for reliable operation
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

/// Check if system tray should be enabled via environment variable
/// System tray is DISABLED by default due to Linux compatibility issues
bool _isSystemTrayEnabled() {
  try {
    final enableSystemTray = Platform.environment['ENABLE_SYSTEM_TRAY'];
    return enableSystemTray == 'true' || enableSystemTray == '1';
  } catch (e) {
    // If Platform.environment is not available, default to false (disable system tray)
    return false;
  }
}

/// Initialize system tray functionality with robust error handling and fallback
Future<void> _initializeSystemTray() async {
  try {
    if (kDebugMode) {
      debugPrint("Initializing system tray with enhanced error handling...");
    }

    final systemTray = SystemTrayManager();
    final windowManager = WindowManagerService();

    // Check if system tray is supported before attempting initialization
    if (!systemTray.isSupported) {
      if (kDebugMode) {
        debugPrint(
            "System tray not supported on this platform, showing main window");
      }
      await _showMainWindow();
      return;
    }

    // Attempt system tray initialization with timeout
    bool success = false;
    try {
      success = await systemTray.initialize(
        onShowWindow: () async {
          if (kDebugMode) {
            debugPrint("System tray requested to show window");
          }
          await windowManager.showWindow();
        },
        onHideWindow: () async {
          if (kDebugMode) {
            debugPrint("System tray requested to hide window");
          }
          await windowManager.hideToTray();
        },
        onSettings: () {
          if (kDebugMode) {
            debugPrint("System tray requested to open settings");
          }
          // TODO: Navigate to settings screen
        },
        onQuit: () {
          if (kDebugMode) {
            debugPrint("System tray requested to quit application");
          }
          SystemNavigator.pop();
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint("System tray initialization timed out");
          return false;
        },
      );
    } catch (e) {
      debugPrint("System tray initialization failed with error: $e");
      success = false;
    }

    if (success) {
      await systemTray.setTooltip('CloudToLocalLLM - Multi-Tenant Streaming');

      // Start minimized to system tray by default
      await windowManager.hideToTray();

      if (kDebugMode) {
        debugPrint("System tray initialization completed successfully");
        debugPrint("Application started minimized to system tray");
      }
    } else {
      if (kDebugMode) {
        debugPrint(
            "System tray initialization failed, showing main window as fallback");
      }
      await _showMainWindow();
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint("System tray initialization error: $e");
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
            routerConfig: AppRouter.createRouter(),

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
