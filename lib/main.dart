// Required for ImageFilter if we use blur, and for ShaderMask
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/auth0_options.dart';
import 'package:cloudtolocalllm/config/theme.dart';
import 'package:cloudtolocalllm/screens/home_screen.dart';
import 'package:cloudtolocalllm/screens/login_screen.dart';
import 'package:cloudtolocalllm/screens/chat_screen.dart';
import 'package:auth0_flutter/auth0_flutter.dart' hide UserProfile;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

// Global instance of AuthService
final AuthService _authService = AuthService(
  Auth0(
    Auth0Options.domain,
    Auth0Options.clientId,
  ),
);

Future<void> main() async {
  runZonedGuarded(
    () async {
      // Ensure Flutter is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize AuthService
      await _initializeAuthService();
      runApp(const CloudToLocalLLMApp());
    },
    (error, stack) {
      // Handle zone errors gracefully in production
      // In production, you might want to send errors to a crash reporting service
    },
  );
}

Future<void> _initializeAuthService() async {
  try {
    await _authService.initialize();
  } catch (e) {
    // Don't rethrow - allow app to continue even if auth fails
  }
}

// 1. Define the GoRouter configuration
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return HomeScreen(authService: _authService);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return LoginScreen(authService: _authService);
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (BuildContext context, GoRouterState state) {
        // Check if user is logged in, redirect to login if not
        final bool isLoggedIn = _authService.isAuthenticated.value;
        if (!isLoggedIn) {
          return LoginScreen(authService: _authService);
        }
        return ChatScreen(authService: _authService);
      },
    ),
    GoRoute(
      path: '/callback',
      builder: (BuildContext context, GoRouterState state) {
        return const CallbackScreen();
      },
    ),
    GoRoute(
      path: '/oauthredirect',
      builder: (BuildContext context, GoRouterState state) {
        return OAuthRedirectScreen(responseUri: state.uri);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);

// Auth0 callback screen
class CallbackScreen extends StatefulWidget {
  const CallbackScreen({super.key});

  @override
  State<CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends State<CallbackScreen> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    // The actual callback processing happens in AuthService.initialize()
    // This is just a redirect after a short delay
    final context = this.context;
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      GoRouter.of(context).go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Processing authentication...'),
          ],
        ),
      ),
    );
  }
}

// Main app wrapper without Firebase dependency
class CloudToLocalLLMApp extends StatelessWidget {
  const CloudToLocalLLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Trigger flutter-first-frame event after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        // Dispatch flutter-first-frame event for web
        try {
          web.window.dispatchEvent(web.CustomEvent('flutter-first-frame'));
        } catch (e) {
          // Silently handle errors in production
        }
      }
    });

    return MaterialApp.router(
      routerConfig: _router,
      title: 'CloudToLocalLLM Portal',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}

// 3. Create the OAuthRedirectScreen widget
class OAuthRedirectScreen extends StatefulWidget {
  final Uri responseUri;
  const OAuthRedirectScreen({super.key, required this.responseUri});

  @override
  State<OAuthRedirectScreen> createState() => _OAuthRedirectScreenState();
}

class _OAuthRedirectScreenState extends State<OAuthRedirectScreen> {
  @override
  void initState() {
    super.initState();
    _handleLoginRedirect();
  }

  Future<void> _handleLoginRedirect() async {
    try {
      await _authService.handleRedirectAndLogin(widget.responseUri);
      if (!mounted) return; // Check mounted after await
      // Always navigate to home page after login attempt
      GoRouter.of(context).go('/');
    } catch (e) {
      if (!mounted) return; // Check mounted after await
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during login: $e')),
      );
      GoRouter.of(context).go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while processing
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Processing login...'),
          ],
        ),
      ),
    );
  }
}
