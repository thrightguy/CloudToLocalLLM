// Flutter framework imports
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Local configuration imports
// Note: Using relative imports for app-specific files in the modular architecture
import 'config/app_config.dart';

// Screen imports
import 'screens/loading_screen.dart';

// Configuration imports
import 'config/theme.dart';
import 'config/router.dart';

// Service imports
// All services are app-specific and use relative imports
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/ipc_chat_service.dart';
import 'services/simplified_connection_service.dart';

// Simple logger class for now
class AppLogger {
  final String name;
  AppLogger(this.name);
  void info(String message) => debugPrint('[$name] INFO: $message');
  void warning(String message) => debugPrint('[$name] WARN: $message');
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$name] ERROR: $message');
    if (error != null) debugPrint('[$name] ERROR: $error');
  }

  void debug(String message) => debugPrint('[$name] DEBUG: $message');
}

// Global navigator key for navigation from IPC
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const CloudToLocalLLMChatApp());
}

class CloudToLocalLLMChatApp extends StatefulWidget {
  const CloudToLocalLLMChatApp({super.key});

  @override
  State<CloudToLocalLLMChatApp> createState() => _CloudToLocalLLMChatAppState();
}

class _CloudToLocalLLMChatAppState extends State<CloudToLocalLLMChatApp> {
  bool _isInitialized = false;
  late final AppLogger _logger;
  late final IPCChatService _ipcService;

  @override
  void initState() {
    super.initState();
    _logger = AppLogger('chat');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      _logger.info(
        'Initializing CloudToLocalLLM Chat Application v${AppConfig.appVersion}',
      );

      // Show the UI immediately to prevent black screen
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Initialize IPC service for communication with other apps
      if (!kIsWeb) {
        await _initializeIPCService();
      }

      _logger.info('Chat application initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Error during app initialization', e, stackTrace);
      // Still show the UI even if initialization fails
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _initializeIPCService() async {
    try {
      _logger.info('Initializing IPC service...');

      _ipcService = IPCChatService();
      final success = await _ipcService.initialize(
        onShowWindow: _handleShowWindow,
        onHideWindow: _handleHideWindow,
        onToggleWindow: _handleToggleWindow,
        onOpenSettings: _handleOpenSettings,
        onQuit: _handleQuit,
      );

      if (success) {
        _logger.info('IPC service initialized successfully');
      } else {
        _logger.warning(
          'IPC service initialization failed - continuing without IPC',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize IPC service', e, stackTrace);
    }
  }

  // IPC Event Handlers
  void _handleShowWindow() {
    _logger.debug('IPC: Show window requested');
    // Window management will be handled by the Flutter framework
  }

  void _handleHideWindow() {
    _logger.debug('IPC: Hide window requested');
    // Window management will be handled by the Flutter framework
  }

  void _handleToggleWindow() {
    _logger.debug('IPC: Toggle window requested');
    // Window management will be handled by the Flutter framework
  }

  void _handleOpenSettings() {
    _logger.debug('IPC: Open settings requested');
    final context = navigatorKey.currentContext;
    if (context != null) {
      context.go('/settings');
    }
  }

  void _handleQuit() {
    _logger.info('IPC: Quit application requested');
    // Perform cleanup and exit
    _cleanup();
    // Note: Actual app termination should be handled by the tray app
  }

  Future<void> _cleanup() async {
    try {
      _logger.info('Cleaning up chat application...');
      await _ipcService.dispose();
      _logger.info('Chat application cleanup completed');
    } catch (e) {
      _logger.error('Error during cleanup', e);
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: AppConfig.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppConfig.enableDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: const LoadingScreen(
          message: 'Initializing CloudToLocalLLM Chat...',
        ),
      );
    }

    return MultiProvider(
      providers: [
        // Authentication service
        ChangeNotifierProvider(create: (_) => AuthService()),

        // Chat service
        ChangeNotifierProvider(create: (_) => ChatService()),

        // Connection service
        ChangeNotifierProvider(create: (_) => SimplifiedConnectionService()),
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
        home: _buildMainApp(),
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
