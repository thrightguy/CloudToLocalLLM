import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../screens/unified_settings_screen.dart';

// Marketing screens (web-only)
import '../screens/marketing/homepage_screen.dart';
import '../screens/marketing/download_screen.dart';
import '../screens/marketing/documentation_screen.dart';

/// Application router configuration using GoRouter
class AppRouter {
  static GoRouter createRouter({GlobalKey<NavigatorState>? navigatorKey}) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      debugLogDiagnostics: false,
      routes: [
        // Home route - platform-specific routing
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) {
            // Web: Domain detection handled by redirect logic
            // Desktop: Chat interface
            if (kIsWeb) {
              // Check if we're on the app subdomain
              final isAppSubdomain = state.uri.host.startsWith('app.');

              if (isAppSubdomain) {
                // App subdomain - show chat interface (auth handled by redirect)
                return const HomeScreen();
              } else {
                // Root domain - show marketing homepage
                return const HomepageScreen();
              }
            } else {
              // For desktop, home is the chat interface
              return const HomeScreen();
            }
          },
        ),

        // Chat route - main app interface (accessible via app subdomain)
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) => const HomeScreen(),
        ),

        // Download route - web-only marketing page
        GoRoute(
          path: '/download',
          name: 'download',
          builder: (context, state) {
            // Only available on web platform
            if (kIsWeb) {
              return const DownloadScreen();
            } else {
              // Redirect desktop users to main app
              return const HomeScreen();
            }
          },
        ),

        // Documentation route - web-only
        GoRoute(
          path: '/docs',
          name: 'docs',
          builder: (context, state) {
            // Only available on web platform
            if (kIsWeb) {
              return const DocumentationScreen();
            } else {
              // Redirect desktop users to main app
              return const HomeScreen();
            }
          },
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

        // Settings route - unified settings interface with sidebar layout
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const UnifiedSettingsScreen(),
        ),

        // Tunnel Settings route (legacy/advanced tunnel configuration)
        GoRoute(
          path: '/settings/tunnels',
          name: 'tunnel-settings',
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

      // Redirect logic for authentication and domain-based routing
      redirect: (context, state) {
        final authService = context.read<AuthService>();
        final isAuthenticated = authService.isAuthenticated.value;
        final isLoggingIn = state.matchedLocation == '/login';
        final isCallback = state.matchedLocation == '/callback';
        final isLoading = state.matchedLocation == '/loading';
        final isHomepage = state.matchedLocation == '/' && kIsWeb;
        final isDownload = state.matchedLocation == '/download' && kIsWeb;
        final isDocs = state.matchedLocation == '/docs' && kIsWeb;

        // Check if we're on app subdomain
        final isAppSubdomain = kIsWeb && state.uri.host.startsWith('app.');

        // Allow access to marketing pages on web root domain without authentication
        if (kIsWeb && !isAppSubdomain && (isHomepage || isDownload || isDocs)) {
          return null;
        }

        // Allow access to login, callback, and loading pages
        if (isLoggingIn || isCallback || isLoading) {
          return null;
        }

        // For app subdomain or desktop, require authentication
        if (!isAuthenticated && (isAppSubdomain || !kIsWeb)) {
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
