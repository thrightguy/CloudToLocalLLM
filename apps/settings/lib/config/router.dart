import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/settings_home.dart';
import '../screens/connection_settings.dart';
import '../screens/ollama_test.dart';
import '../screens/about_screen.dart';
import '../main.dart';

/// Router configuration for CloudToLocalLLM Settings app
class SettingsRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return SettingsAppInitializer(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const SettingsHome(),
          ),
          GoRoute(
            path: '/connection',
            name: 'connection',
            builder: (context, state) => const ConnectionSettings(),
          ),
          GoRoute(
            path: '/ollama-test',
            name: 'ollama-test',
            builder: (context, state) => const OllamaTest(),
          ),
          GoRoute(
            path: '/about',
            name: 'about',
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
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
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Unknown error',
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
