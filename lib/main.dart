// Required for ImageFilter if we use blur, and for ShaderMask
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/screens/login_screen.dart';
import 'package:cloudtolocalllm/screens/chat_screen.dart';
import 'package:cloudtolocalllm/auth0_options.dart';
import 'package:cloudtolocalllm/config/theme.dart';
import 'package:cloudtolocalllm/components/gradient_app_bar.dart';
import 'package:cloudtolocalllm/components/themed_card.dart';
import 'package:cloudtolocalllm/components/gradient_button.dart';
import 'package:auth0_flutter/auth0_flutter.dart' hide UserProfile;
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

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

      // Initialize MCP Toolkit
      MCPToolkitBinding.instance
        ..initialize() // Initializes the Toolkit
        ..initializeFlutterToolkit(); // Adds Flutter related methods to the MCP server

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
      runApp(const CloudToLocalLLMApp());
    },
    (error, stack) {
      // Critical: Handle zone errors for MCP server error reporting
      MCPToolkitBinding.instance.handleZoneError(error, stack);
    },
  );
}

Future<void> _initializeAuthService() async {
  try {
    developer.log('Initializing AuthService...', name: 'auth_service');
    await _authService.initialize();
    developer.log('AuthService initialized successfully', name: 'auth_service');
  } catch (e) {
    developer.log('AuthService initialization failed: $e',
        name: 'auth_service', error: e);
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
    return MaterialApp.router(
      routerConfig: _router,
      title: 'CloudToLocalLLM Portal',
      theme: CloudToLocalLLMTheme.lightTheme,
      darkTheme: CloudToLocalLLMTheme.darkTheme,
      themeMode: ThemeMode.dark,
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

class CircularLlmLogo extends StatelessWidget {
  final double size;
  const CircularLlmLogo({super.key, this.size = 120.0}); // Default size

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CloudToLocalLLMTheme.secondaryColor,
        border: Border.all(
          color: CloudToLocalLLMTheme.primaryColor,
          width: 3,
        ),
        boxShadow: CloudToLocalLLMTheme.smallShadow,
      ),
      child: Center(
        child: Text(
          'LLM',
          style: TextStyle(
            fontSize: size * 0.35, // Adjust text size relative to logo size
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: CloudToLocalLLMTheme.fontFamily,
            shadows: const [
              Shadow(
                blurRadius: 1.0,
                color: Colors.black26,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'CloudToLocalLLM',
        subtitle: 'Run powerful Large Language Models locally',
        showLogo: true,
        actions: [
          // Debug button - visible in all cases
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () {
              GoRouter.of(context).go('/debug');
            },
          ),
          // Authentication state-aware buttons
          ValueListenableBuilder<bool>(
            valueListenable: _authService.isAuthenticated,
            builder: (context, isAuthenticated, _) {
              if (isAuthenticated) {
                // User is logged in
                return Row(
                  children: [
                    // Chat button
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GradientButton(
                        text: 'Chat',
                        icon: Icons.chat,
                        onPressed: () {
                          GoRouter.of(context).go('/chat');
                        },
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        fontSize: 14,
                      ),
                    ),
                    // Logout button
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SecondaryButton(
                        text: 'Logout',
                        icon: Icons.logout,
                        onPressed: () async {
                          await _authService.logout();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Logged out successfully')),
                            );
                          }
                        },
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              } else {
                // User is not logged in
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GradientButton(
                    text: 'Login',
                    onPressed: () {
                      GoRouter.of(context).go('/login');
                    },
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    fontSize: 14,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        // Use Stack for layering background and foreground
        children: [
          // Background layer
          Positioned.fill(
            child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  // Gradient that fades to transparent at the sides, showing scaffold background
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0), // Transparent at edge
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0), // Transparent for a bit
                      Colors.white, // Opaque center for the image to show
                      Colors.white, // Opaque center
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0), // Transparent for a bit
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0), // Transparent at edge
                    ],
                    stops: const [
                      0.0,
                      0.15,
                      0.3,
                      0.7,
                      0.85,
                      1.0
                    ], // Control fade points
                  ).createShader(bounds);
                },
                blendMode: BlendMode
                    .dstOut, // This blend mode will effectively "erase" based on gradient alpha
                // Alternative for fading image: BlendMode.dstIn or use Opacity widgets with gradients
                child: Opacity(
                  // Added overall opacity to the background image to make it more subtle
                  opacity:
                      0.15, // Adjust as needed, 0.1 to 0.3 is usually good for subtle backgrounds
                  child: Image.asset(
                    'assets/images/CloudToLocalLLM_logo.jpg',
                    fit: BoxFit.cover, // Cover the area, might be cropped
                    alignment: Alignment.center,
                  ),
                )),
          ),

          // Content layer
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const CircularLlmLogo(size: 150),
                  const SizedBox(height: 20),
                  const Text(
                    'CloudToLocalLLM',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Run advanced AI models locally, managed by a cloud interface.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Auth state-aware content
                  ValueListenableBuilder<bool>(
                    valueListenable: _authService.isAuthenticated,
                    builder: (context, isAuthenticated, _) {
                      if (isAuthenticated) {
                        // User is logged in
                        return ValueListenableBuilder<UserProfile?>(
                            valueListenable: _authService.currentUser,
                            builder: (context, user, _) {
                              return InfoCard(
                                title:
                                    'Welcome${user?.name != null ? ', ${user!.name}' : ''}!',
                                description:
                                    user?.email ?? 'Authenticated User',
                                icon: Icons.person,
                                iconColor: CloudToLocalLLMTheme.successColor,
                                width: 480,
                                content: Column(
                                  children: [
                                    // Start chatting button
                                    GradientButton(
                                      text: 'Start Chatting',
                                      icon: Icons.chat,
                                      onPressed: () {
                                        GoRouter.of(context).go('/chat');
                                      },
                                      width: double.infinity,
                                    ),
                                    const SizedBox(height: 16),
                                    // User actions
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        // Debug button
                                        SecondaryButton(
                                          text: 'Debug Status',
                                          icon: Icons.bug_report,
                                          onPressed: () {
                                            GoRouter.of(context).go('/debug');
                                          },
                                          fontSize: 14,
                                        ),
                                        // Logout button
                                        SecondaryButton(
                                          text: 'Logout',
                                          icon: Icons.logout,
                                          onPressed: () async {
                                            await _authService.logout();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Logged out successfully')),
                                              );
                                            }
                                          },
                                          fontSize: 14,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            });
                      } else {
                        // User is not logged in
                        return InfoCard(
                          title:
                              'Please login to access your models and settings',
                          description:
                              'Authentication is required to use this application.',
                          icon: Icons.login,
                          iconColor: CloudToLocalLLMTheme.infoColor,
                          width: 480,
                          content: Column(
                            children: [
                              // Login button
                              GradientButton(
                                text: 'Login / Create Account',
                                onPressed: () {
                                  GoRouter.of(context).go('/login');
                                },
                                width: double.infinity,
                              ),
                              const SizedBox(height: 16),
                              // Debug button
                              SecondaryButton(
                                text: 'Debug Auth Status',
                                icon: Icons.bug_report,
                                onPressed: () {
                                  GoRouter.of(context).go('/debug');
                                },
                                fontSize: 14,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
