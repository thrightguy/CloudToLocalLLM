// Required for ImageFilter if we use blur, and for ShaderMask
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/auth0_options.dart';
import 'package:auth0_flutter/auth0_flutter.dart' hide UserProfile;
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
      developer.log('Flutter binding initialized', name: 'main');

      // Platform-specific logging
      if (kIsWeb) {
        developer.log('Running on Web platform', name: 'platform');
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            developer.log('Running on Android platform', name: 'platform');
            break;
          case TargetPlatform.iOS:
            developer.log('Running on iOS platform', name: 'platform');
            break;
          case TargetPlatform.linux:
            developer.log('Running on Linux platform', name: 'platform');
            break;
          case TargetPlatform.macOS:
            developer.log('Running on macOS platform', name: 'platform');
            break;
          case TargetPlatform.windows:
            developer.log('Running on Windows platform', name: 'platform');
            break;
          default:
            developer.log('Running on unknown platform', name: 'platform');
        }
      }

      // Initialize AuthService
      await _initializeAuthService();
      developer.log('About to run app', name: 'main');
      runApp(const CloudToLocalLLMApp());
      developer.log('App started', name: 'main');
    },
    (error, stack) {
      // Handle zone errors with standard logging
      developer.log('Zone error: $error',
          name: 'zone_error', error: error, stackTrace: stack);
    },
  );
}

Future<void> _initializeAuthService() async {
  try {
    developer.log('Initializing AuthService...', name: 'auth_service');
    developer.log('Auth0 Domain: ${Auth0Options.domain}', name: 'auth_service');
    developer.log('Auth0 Client ID: ${Auth0Options.clientId}',
        name: 'auth_service');

    await _authService.initialize();
    developer.log('AuthService initialized successfully', name: 'auth_service');
  } catch (e, stackTrace) {
    developer.log('AuthService initialization failed: $e',
        name: 'auth_service', error: e, stackTrace: stackTrace);
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
        return const HomeScreen();
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
    GoRoute(
      path: '/debug',
      builder: (BuildContext context, GoRouterState state) {
        return const DebugScreen();
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

// Debug screen to show Auth0 status
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auth0 Authentication State',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                        valueListenable: _authService.isAuthenticated,
                        builder: (context, isAuthenticated, _) {
                          return Text(
                              'Logged in: ${isAuthenticated ? 'YES' : 'NO'}');
                        }),
                    ValueListenableBuilder<UserProfile?>(
                        valueListenable: _authService.currentUser,
                        builder: (context, user, _) {
                          if (user == null) {
                            return const Text('No user logged in');
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('User ID: ${user.sub}'),
                              Text('Email: ${user.email}'),
                              Text('Name: ${user.name}'),
                            ],
                          );
                        }),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final token = await _authService.getAccessToken();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Token: ${token ?? 'None'}')),
                        );
                      },
                      child: const Text('Show Token'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                GoRouter.of(context).go('/');
              },
              child: const Text('Back to Home'),
            ),
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
      developer.log('First frame callback triggered', name: 'flutter_frame');
      if (kIsWeb) {
        // Dispatch flutter-first-frame event for web
        try {
          web.window.dispatchEvent(web.CustomEvent('flutter-first-frame'));
          developer.log('flutter-first-frame event dispatched successfully',
              name: 'flutter_frame');
        } catch (e, stackTrace) {
          developer.log('Error dispatching flutter-first-frame event: $e',
              name: 'flutter_frame', error: e, stackTrace: stackTrace);
        }
      }
    });

    return MaterialApp.router(
      routerConfig: _router,
      title: 'CloudToLocalLLM Portal',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
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

// Basic HomeScreen
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudToLocalLLM'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'CloudToLocalLLM',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Run powerful Large Language Models locally with cloud-based management',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Basic LoginScreen
class LoginScreen extends StatelessWidget {
  final AuthService authService;
  final bool isRegistrationMode;
  const LoginScreen(
      {super.key, required this.authService, this.isRegistrationMode = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome to CloudToLocalLLM',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await authService.login();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Login error: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Basic ChatScreen
class ChatScreen extends StatelessWidget {
  final AuthService authService;
  const ChatScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                GoRouter.of(context).go('/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chat Interface',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text('Chat functionality coming soon!'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
