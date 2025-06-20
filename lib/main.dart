import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'screens/loading_screen.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/ollama_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/unified_connection_service.dart';
import 'services/tunnel_manager_service.dart';
import 'services/local_ollama_connection_service.dart';
import 'services/connection_manager_service.dart';
import 'services/streaming_chat_service.dart';
import 'services/native_tray_service.dart';
import 'services/window_manager_service.dart';
import 'services/desktop_client_detection_service.dart';
import 'widgets/debug_version_overlay.dart';
import 'widgets/window_listener_widget.dart';

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
    try {
      // Show the UI immediately to prevent black screen
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Initialize system tray for desktop platforms in background
      if (!kIsWeb) {
        // Run system tray initialization asynchronously without blocking UI
        _initializeSystemTray();
      }
    } catch (e) {
      debugPrint("💥 [App] Error during app initialization: $e");
      // Still show the UI even if initialization fails
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _initializeSystemTray() async {
    try {
      debugPrint("🚀 [SystemTray] Initializing native tray service...");

      // Initialize window manager service first
      final windowManager = WindowManagerService();
      await windowManager.initialize();

      // Note: Tray service will be initialized after providers are set up
      // This ensures all required services are available
    } catch (e, stackTrace) {
      debugPrint("💥 [SystemTray] Failed to initialize system tray: $e");
      debugPrint("💥 [SystemTray] Stack trace: $stackTrace");
    }
  }

  void _navigateToRoute(String route) {
    try {
      debugPrint("🧭 [Navigation] Attempting to navigate to route: $route");

      // Try multiple approaches to get a valid context
      BuildContext? context = navigatorKey.currentContext;

      context ??= navigatorKey.currentState?.context;
      context ??= _getCurrentAppContext();

      if (context != null && context.mounted) {
        debugPrint(
          "✅ [Navigation] Context available, executing navigation to: $route",
        );

        // Use post-frame callback to ensure navigation happens after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (context!.mounted) {
              context.go(route);
              debugPrint(
                "✅ [Navigation] Navigation command sent for route: $route",
              );
            } else {
              debugPrint(
                "❌ [Navigation] Context no longer mounted for route: $route",
              );
            }
          } catch (e) {
            debugPrint(
              "💥 [Navigation] Post-frame navigation error for $route: $e",
            );
          }
        });
      } else {
        debugPrint(
          "❌ [Navigation] Cannot navigate to $route: no valid context available",
        );

        // Schedule retry after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _retryNavigation(route, 1);
        });
      }
    } catch (e, stackTrace) {
      debugPrint("💥 [Navigation] Error navigating to $route: $e");
      debugPrint("💥 [Navigation] Stack trace: $stackTrace");
    }
  }

  void _retryNavigation(String route, int attempt) {
    if (attempt > 3) {
      debugPrint("❌ [Navigation] Max retry attempts reached for route: $route");
      return;
    }

    debugPrint("🔄 [Navigation] Retry attempt $attempt for route: $route");

    final context =
        navigatorKey.currentContext ?? navigatorKey.currentState?.context;
    if (context != null && context.mounted) {
      try {
        context.go(route);
        debugPrint("✅ [Navigation] Retry successful for route: $route");
      } catch (e) {
        debugPrint("💥 [Navigation] Retry failed for $route: $e");
        Future.delayed(const Duration(milliseconds: 1000), () {
          _retryNavigation(route, attempt + 1);
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _retryNavigation(route, attempt + 1);
      });
    }
  }

  BuildContext? _getCurrentAppContext() {
    try {
      // Try to get context from the current widget tree
      return navigatorKey.currentState?.context;
    } catch (e) {
      debugPrint("🔍 [Navigation] Could not get alternative context: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication service
        ChangeNotifierProvider(create: (_) => AuthService()),
        // Streaming proxy service
        ChangeNotifierProvider(
          create: (context) =>
              StreamingProxyService(authService: context.read<AuthService>()),
        ),
        // Ollama service
        ChangeNotifierProvider(
          create: (context) =>
              OllamaService(authService: context.read<AuthService>()),
        ),
        // Local Ollama connection service (independent of tunnel)
        ChangeNotifierProvider(
          create: (context) {
            final localOllama = LocalOllamaConnectionService();
            // Initialize the local Ollama service asynchronously
            localOllama.initialize();
            return localOllama;
          },
        ),
        // Tunnel manager service (cloud proxy only)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final tunnelManager = TunnelManagerService(
              authService: authService,
            );
            // Initialize the tunnel manager service asynchronously
            tunnelManager.initialize();
            return tunnelManager;
          },
        ),
        // Desktop client detection service (web platform only)
        ChangeNotifierProvider(
          create: (context) {
            final authService = context.read<AuthService>();
            final clientDetection = DesktopClientDetectionService(
              authService: authService,
            );
            // Initialize the client detection service asynchronously
            clientDetection.initialize();
            return clientDetection;
          },
        ),
        // Connection manager service (coordinates local and cloud)
        ChangeNotifierProvider(
          create: (context) {
            final localOllama = context.read<LocalOllamaConnectionService>();
            final tunnelManager = context.read<TunnelManagerService>();
            final connectionManager = ConnectionManagerService(
              localOllama: localOllama,
              tunnelManager: tunnelManager,
            );
            // Initialize the connection manager service
            connectionManager.initialize();
            return connectionManager;
          },
        ),
        // Streaming chat service (uses connection manager)
        ChangeNotifierProvider(
          create: (context) {
            final connectionManager = context.read<ConnectionManagerService>();
            return StreamingChatService(connectionManager);
          },
        ),
        // Unified connection service (depends on connection manager)
        ChangeNotifierProvider(
          create: (context) {
            final unifiedService = UnifiedConnectionService();
            // TODO: Update UnifiedConnectionService to use ConnectionManagerService
            // final connectionManager = context.read<ConnectionManagerService>();
            // unifiedService.setConnectionManager(connectionManager);
            // Initialize the unified connection service
            unifiedService.initialize();
            return unifiedService;
          },
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
            : const LoadingScreen(message: 'Initializing CloudToLocalLLM...'),
      ),
    );
  }

  Widget _buildMainApp() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Initialize tray service after providers are available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeTrayService(context);
        });

        return WindowListenerWidget(
          child: DebugVersionWrapper(
            child: MaterialApp.router(
              // App configuration
              title: AppConfig.appName,
              debugShowCheckedModeBanner: false,

              // Theme configuration
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: AppConfig.enableDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,

              // Router configuration
              routerConfig: AppRouter.createRouter(navigatorKey: navigatorKey),

              // Builder for additional configuration
              builder: (context, child) {
                return MediaQuery(
                  // Ensure text scaling doesn't break the UI
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      MediaQuery.of(
                        context,
                      ).textScaler.scale(1.0).clamp(0.8, 1.2),
                    ),
                  ),
                  child: child!,
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _trayInitialized = false;

  /// Initialize tray service after providers are available
  Future<void> _initializeTrayService(BuildContext context) async {
    if (_trayInitialized) return;
    _trayInitialized = true;

    try {
      debugPrint("🚀 [SystemTray] Initializing native tray service...");

      // Get services from providers
      final connectionManager = context.read<ConnectionManagerService>();
      final localOllama = context.read<LocalOllamaConnectionService>();
      final tunnelManager = context.read<TunnelManagerService>();

      // Get window manager service
      final windowManager = WindowManagerService();

      // Initialize native tray service
      final nativeTray = NativeTrayService();
      final success = await nativeTray.initialize(
        connectionManager: connectionManager,
        localOllama: localOllama,
        tunnelManager: tunnelManager,
        onShowWindow: () {
          debugPrint("🪟 [SystemTray] Native tray requested to show window");
          windowManager.showWindow();
        },
        onHideWindow: () {
          debugPrint("🫥 [SystemTray] Native tray requested to hide window");
          windowManager.hideToTray();
        },
        onSettings: () {
          debugPrint("⚙️ [SystemTray] Native tray requested to open settings");
          _navigateToRoute('/settings');
        },
        onQuit: () {
          debugPrint(
            "🚪 [SystemTray] Native tray requested to quit application",
          );
          windowManager.forceClose();
        },
      );

      if (success) {
        debugPrint(
          "✅ [SystemTray] Native tray service initialized successfully",
        );
      } else {
        debugPrint("❌ [SystemTray] Failed to initialize native tray service");
      }
    } catch (e, stackTrace) {
      debugPrint("💥 [SystemTray] Failed to initialize system tray: $e");
      debugPrint("💥 [SystemTray] Stack trace: $stackTrace");
    }
  }
}
