import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const CloudToLocalLLMApp());
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
