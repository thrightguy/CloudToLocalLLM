import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/loading_screen.dart';
import '../screens/callback_screen.dart';

/// Application router configuration using GoRouter
class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
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
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
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
