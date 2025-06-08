import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/loading_screen.dart';
import '../screens/callback_screen.dart';
import '../screens/ollama_test_screen.dart';

import '../screens/settings/llm_provider_settings_screen.dart';
import '../screens/settings/daemon_settings_screen.dart';
import '../screens/settings/connection_status_screen.dart';
import '../screens/tunnel_settings_screen.dart';

/// Application router configuration using GoRouter
class AppRouter {
  static GoRouter createRouter({GlobalKey<NavigatorState>? navigatorKey}) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      debugLogDiagnostics: false,
      routes: [
        // Home route
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),

        // Login route
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),

        // Auth callback route
        GoRoute(
          path: '/callback',
          name: 'callback',
          builder: (context, state) => const CallbackScreen(),
        ),

        // Loading route
        GoRoute(
          path: '/loading',
          name: 'loading',
          builder: (context, state) {
            final message =
                state.uri.queryParameters['message'] ?? 'Loading...';
            return LoadingScreen(message: message);
          },
        ),

        // Ollama test route
        GoRoute(
          path: '/ollama-test',
          name: 'ollama-test',
          builder: (context, state) => const OllamaTestScreen(),
        ),

        // Settings route - now displays tunnel settings as primary interface
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const TunnelSettingsScreen(),
        ),

        // LLM Provider Settings route
        GoRoute(
          path: '/settings/llm-provider',
          name: 'llm-provider-settings',
          builder: (context, state) => const LLMProviderSettingsScreen(),
        ),

        // Daemon Settings route
        GoRoute(
          path: '/settings/daemon',
          name: 'daemon-settings',
          builder: (context, state) {
            debugPrint("🔧 [Router] Building DaemonSettingsScreen");
            return const DaemonSettingsScreen();
          },
        ),

        // Connection Status route
        GoRoute(
          path: '/settings/connection-status',
          name: 'connection-status',
          builder: (context, state) {
            debugPrint("📊 [Router] Building ConnectionStatusScreen");
            return const ConnectionStatusScreen();
          },
        ),
      ],

      // Redirect logic for authentication
      redirect: (context, state) {
        final authService = context.read<AuthService>();
        final isAuthenticated = authService.isAuthenticated.value;
        final isLoggingIn = state.matchedLocation == '/login';
        final isCallback = state.matchedLocation == '/callback';
        final isLoading = state.matchedLocation == '/loading';

        // Allow access to login, callback, and loading pages
        if (isLoggingIn || isCallback || isLoading) {
          return null;
        }

        // Redirect to login if not authenticated
        if (!isAuthenticated) {
          return '/login';
        }

        // Allow access to protected routes
        return null;
      },

      // Error handling
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page Not Found',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'The page "${state.matchedLocation}" could not be found.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
