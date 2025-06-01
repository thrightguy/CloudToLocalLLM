import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/system_tray_service.dart';
import 'services/window_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize system tray for desktop platforms (only on non-web)
  if (!kIsWeb && _isDesktopPlatform()) {
    await _initializeSystemTray();
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

/// Initialize system tray functionality
Future<void> _initializeSystemTray() async {
  try {
    debugPrint("Initializing system tray...");

    final systemTray = SystemTrayService();
    final windowManager = WindowManagerService();

    final success = await systemTray.initialize(
      onShowWindow: () async {
        debugPrint("System tray requested to show window");
        await windowManager.showWindow();
      },
      onHideWindow: () async {
        debugPrint("System tray requested to hide window");
        await windowManager.hideToTray();
      },
      onQuit: () {
        debugPrint("System tray requested to quit application");
        SystemNavigator.pop();
      },
    );

    if (success) {
      await systemTray.setTooltip('CloudToLocalLLM - Local LLM Management');
      debugPrint("System tray initialization completed successfully");
    } else {
      debugPrint(
          "System tray initialization failed, continuing without system tray");
    }
  } catch (e) {
    debugPrint("System tray initialization error: $e");
    debugPrint("Continuing without system tray functionality");
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
