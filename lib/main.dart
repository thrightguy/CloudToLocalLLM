import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'screens/loading_screen.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/unified_connection_service.dart';
import 'services/enhanced_tray_service.dart';

// Global navigator key for navigation from system tray
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const CloudToLocalLLMApp());
}

/// Main application widget with comprehensive loading screen
class CloudToLocalLLMApp extends StatefulWidget {
  const CloudToLocalLLMApp({super.key});

  @override
  State<CloudToLocalLLMApp> createState() => _CloudToLocalLLMAppState();
}

class _CloudToLocalLLMAppState extends State<CloudToLocalLLMApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize system tray for desktop platforms
    if (!kIsWeb) {
      await _initializeSystemTray();
    }

    // Simulate initialization delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initializeSystemTray() async {
    try {
      final enhancedTray = EnhancedTrayService();
      await enhancedTray.initialize(
        onShowWindow: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to show window");
          }
          // Show window logic would go here
        },
        onHideWindow: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to hide window");
          }
          // Hide window logic would go here
        },
        onSettings: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to open settings");
          }
          _navigateToRoute('/settings');
        },
        onDaemonSettings: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to open daemon settings");
          }
          _navigateToRoute('/settings/daemon');
        },
        onConnectionStatus: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to show connection status");
          }
          _navigateToRoute('/settings/connection-status');
        },
        onOllamaTest: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to open Ollama test");
          }
          _navigateToRoute('/ollama-test');
        },
        onQuit: () {
          if (kDebugMode) {
            debugPrint("Enhanced tray requested to quit application");
          }
          // Quit application logic would go here
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Failed to initialize system tray: $e");
      }
    }
  }

  void _navigateToRoute(String route) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        if (kDebugMode) {
          debugPrint("Navigating to route: $route");
        }
        context.go(route);
      } else {
        if (kDebugMode) {
          debugPrint("Cannot navigate to $route: no context available");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error navigating to $route: $e");
      }
    }
  }

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
      child: MaterialApp(
        // App configuration
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,

        // Theme configuration
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light,

        // Show loading screen until initialization is complete
        home: _isInitialized
            ? _buildMainApp()
            : const LoadingScreen(
                message: 'Initializing CloudToLocalLLM...',
              ),
      ),
    );
  }

  Widget _buildMainApp() {
    return Consumer<AuthService>(
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
                  MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2),
                ),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
