// Required for ImageFilter if we use blur, and for ShaderMask

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/auth_service.dart'; // Assuming your AuthService is here
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloudtolocalllm/screens/login_screen.dart';
import 'package:cloudtolocalllm/screens/chat_screen.dart'; // Import the chat screen
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer; // Import for better logging

// Global instance of AuthService (consider using a service locator like GetIt or Provider)
final AuthService _authService = AuthService();

// Global flag for debugging
bool _firebaseInitialized = false;
String _firebaseErrorMessage = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    developer.log('Initializing Firebase...', name: 'firebase_init');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
    developer.log('Firebase initialized successfully', name: 'firebase_init');
    
    // Debug information
    final FirebaseApp app = Firebase.app();
    developer.log('Firebase app name: ${app.name}', name: 'firebase_init');
    developer.log('Firebase options: ${app.options.projectId}', name: 'firebase_init');
    
    // Check if auth is working
    final auth = FirebaseAuth.instance;
    developer.log('Firebase Auth instance created', name: 'firebase_init');
    
    // Debug auth state
    auth.authStateChanges().listen((User? user) {
      developer.log('Auth state changed: ${user?.uid ?? 'No user logged in'}', name: 'firebase_auth');
    });
  } catch (e) {
    _firebaseInitialized = false;
    _firebaseErrorMessage = e.toString();
    developer.log('Firebase initialization failed: $e', name: 'firebase_init', error: e);
  }
  
  // Initialize AuthService
  try {
    developer.log('Initializing AuthService...', name: 'auth_service');
    await _authService.initialize();
    developer.log('AuthService initialized successfully', name: 'auth_service');
  } catch (e) {
    developer.log('AuthService initialization failed: $e', name: 'auth_service', error: e);
  }
  
  runApp(const CloudToLocalLLMApp());
}

// 1. Define the GoRouter configuration
final GoRouter _router = GoRouter(
  initialLocation: '/', // Optional: if you want a specific initial route
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
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return LoginScreen(authService: _authService);
        }
        return ChatScreen(authService: _authService);
      },
    ),
    GoRoute(
      path: '/oauthredirect',
      builder: (BuildContext context, GoRouterState state) {
        // The full URI is available in state.uri
        // We pass the full URI to the screen
        return OAuthRedirectScreen(responseUri: state.uri);
      },
    ),
    // Add a debug route
    GoRoute(
      path: '/debug',
      builder: (BuildContext context, GoRouterState state) {
        return const DebugScreen();
      },
    ),
  ],
  // Optional: Error page (good practice)
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);

// Debug screen to show Firebase status
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get current Firebase state
    final User? currentUser = FirebaseAuth.instance.currentUser;
    
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
                      'Firebase Initialization',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Status: ${_firebaseInitialized ? 'SUCCESS' : 'FAILED'}'),
                    if (!_firebaseInitialized) Text('Error: $_firebaseErrorMessage'),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Firebase Auth State',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Logged in: ${currentUser != null ? 'YES' : 'NO'}'),
                    if (currentUser != null) ...[
                      Text('User ID: ${currentUser.uid}'),
                      Text('Email: ${currentUser.email}'),
                      Text('Anonymous: ${currentUser.isAnonymous}'),
                    ],
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: () {
                        FirebaseAuth.instance.authStateChanges().listen((User? user) {
                          developer.log('Current auth state: ${user?.uid ?? 'No user logged in'}', 
                            name: 'firebase_auth');
                        });
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Auth state logged to console')),
                        );
                      },
                      child: const Text('Check Auth State'),
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

class CloudToLocalLLMApp extends StatelessWidget {
  const CloudToLocalLLMApp({super.key}); // Removed const because _router is not const

  @override
  Widget build(BuildContext context) {
    // 2. Use MaterialApp.router
    return MaterialApp.router(
      routerConfig: _router,
      title: 'CloudToLocalLLM Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5AE0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5AE0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121829),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      // home: const HomeScreen(), // home is replaced by routerConfig
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
      final user = await _authService.handleRedirectAndLogin(widget.responseUri);
      if (!mounted) return; // Check mounted after await
      if (user != null) {
        // Successfully logged in, navigate to home or a dashboard
        GoRouter.of(context).go('/'); // Navigate to home page
      } else {
        // Login failed
        // Optionally, show an error message or navigate to a login error page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Please try again.')),
        );
        GoRouter.of(context).go('/'); // Go back to home or login page
      }
    } catch (e) {
      // print('Error during redirect handling: $e'); // Removed print
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
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withAlpha((255 * 0.8).round()), // Fixed withAlpha
            Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.6).round()), // Fixed withAlpha
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.3).round()), // Fixed withAlpha
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'LLM',
          style: TextStyle(
            fontSize: size * 0.35, // Adjust text size relative to logo size
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
    // final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CloudToLocalLLM',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Debug button - visible in all cases
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () {
              GoRouter.of(context).go('/debug');
            },
          ),
          // Firebase Login/Logout Button
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // Add debug log to monitor stream status
              developer.log(
                'StreamBuilder: connection=${snapshot.connectionState}, hasData=${snapshot.hasData}, '
                'hasError=${snapshot.hasError}${snapshot.hasError ? ', error=${snapshot.error}' : ''}',
                name: 'auth_button',
              );
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                );
              }
              
              // Debug - show status
              final bool isLoggedIn = snapshot.data != null;
              developer.log('User logged in: $isLoggedIn', name: 'auth_button');
              
              // Return a more visible button for testing
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    developer.log('Login/logout button pressed', name: 'auth_button');
                    if (isLoggedIn) {
                      await _authService.logout();
                      if (!context.mounted) return;
                      GoRouter.of(context).go('/');
                    } else {
                      GoRouter.of(context).go('/login');
                    }
                  },
                  child: Text(
                    isLoggedIn ? 'Logout' : 'Login',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ],
        elevation: 8.0,
        shadowColor: Colors.black.withAlpha((255 * 0.5).round()), // Fixed withAlpha
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4A3B8A),
                const Color(0xFF6A5AE0).withAlpha((255 * 0.85).round()), // Fixed withAlpha
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
                      Theme.of(context).scaffoldBackgroundColor
                          .withAlpha(0), // Transparent at edge
                      Theme.of(context).scaffoldBackgroundColor
                          .withAlpha(0), // Transparent for a bit
                      Colors.white, // Opaque center for the image to show
                      Colors.white, // Opaque center
                      Theme.of(context).scaffoldBackgroundColor
                          .withAlpha(0), // Transparent for a bit
                      Theme.of(context).scaffoldBackgroundColor
                          .withAlpha(0), // Transparent at edge
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
                  
                  // User profile section - Only show when logged in
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snapshot) {
                      // Debug the stream builder state
                      developer.log(
                        'Profile StreamBuilder: connection=${snapshot.connectionState}, ' +
                        'hasData=${snapshot.hasData}, hasError=${snapshot.hasError}',
                        name: 'profile_card',
                      );
                      
                      // Show loading indicator while waiting
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Card(
                          elevation: 4,
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading authentication status...'),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      
                      final user = snapshot.data;
                      developer.log('User in profile card: ${user?.email ?? 'Not logged in'}', name: 'profile_card');
                      
                      if (user == null) {
                        // Not logged in - show login card with enhanced visibility
                        return Card(
                          elevation: 8, // Higher elevation for better visibility
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.9), // More opaque background
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0), // More padding
                            child: Column(
                              children: [
                                const Icon(Icons.login, size: 48, color: Colors.blue),
                                const SizedBox(height: 16),
                                const Text(
                                  'Please login to access your models and settings',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Firebase authentication is required to use this application.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 24),
                                // Larger, more visible login button
                                ElevatedButton(
                                  onPressed: () {
                                    developer.log('Login button in card pressed', name: 'profile_card');
                                    GoRouter.of(context).go('/login');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  child: const Text('Login / Create Account'),
                                ),
                                const SizedBox(height: 16),
                                // Debugging button for quick access
                                TextButton.icon(
                                  icon: const Icon(Icons.bug_report, size: 16),
                                  label: const Text('Debug Auth Status'),
                                  onPressed: () {
                                    GoRouter.of(context).go('/debug');
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Logged in - show user info
                      return Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'Welcome!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Logged in as: ${user.email}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  GoRouter.of(context).go('/chat');
                                },
                                child: const Text('Go to Chat'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  await _authService.logout();
                                },
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        ),
                      );
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
