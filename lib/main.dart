// Required for ImageFilter if we use blur, and for ShaderMask

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/auth_service.dart'; // Assuming your AuthService is here

// Global instance of AuthService (consider using a service locator like GetIt or Provider)
final AuthService _authService = AuthService();

void main() {
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
      path: '/oauthredirect',
      builder: (BuildContext context, GoRouterState state) {
        // The full URI is available in state.uri
        // We pass the full URI to the screen
        return OAuthRedirectScreen(responseUri: state.uri);
      },
    ),
  ],
  // Optional: Error page (good practice)
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);

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
    // final bool isUserLoggedIn = false; // We can get this from AuthService now
    // For simplicity, let's add a login button that calls _authService.login()
    // You would typically integrate this into your UI more cleanly.

    // final screenWidth = MediaQuery.of(context).size.width; // Removed unused screenWidth
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CloudToLocalLLM',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Example Login/Logout Button
          FutureBuilder<bool>(
            future: _authService.isLoggedIn(), // Check login status
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                );
              }
              final bool isLoggedIn = snapshot.data ?? false;
              return TextButton(
                onPressed: () async {
                  if (isLoggedIn) {
                    await _authService.logout();
                    if (!context.mounted) return; // Added mounted check
                    // GoRouter.of(context).refresh(); // Refresh to update UI if needed
                    // Forcing a reload of the current route to reflect logout state.
                    // This is a simple way, a more robust solution would use a state management library.
                    GoRouter.of(context).go('/', extra: {'refresh': DateTime.now().millisecondsSinceEpoch });
                  } else {
                    await _authService.login();
                    // After calling login, browser will redirect. No need to navigate here.
                  }
                },
                child: Text(
                  isLoggedIn ? 'Logout' : 'Login',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      scaffoldBackgroundColor
                          .withAlpha(0), // Transparent at edge
                      scaffoldBackgroundColor
                          .withAlpha(0), // Transparent for a bit
                      Colors.white, // Opaque center for the image to show
                      Colors.white, // Opaque center
                      scaffoldBackgroundColor
                          .withAlpha(0), // Transparent for a bit
                      scaffoldBackgroundColor
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

          // Foreground content layer
          Center(
            child: SingleChildScrollView(
              // Make content scrollable if it overflows
              padding: const EdgeInsets.all(
                  16.0), // Add some padding around the content
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularLlmLogo(size: 150), // Use the new circular logo
                  const SizedBox(height: 24),
                  const Text(
                    'CloudToLocalLLM',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color:
                          Colors.white, // Ensure text is white for dark theme
                      shadows: [
                        Shadow(
                          blurRadius: 2.0,
                          color: Colors.black54,
                          offset: Offset(1.0, 1.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Run powerful Large Language Models locally with cloud-based management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      shadows: [
                        // Optional: add subtle shadow to subtitle too
                        Shadow(
                          blurRadius: 1.0,
                          color: Colors.black38,
                          offset: Offset(0.5, 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildFeatureCard(
                    title: 'What is CloudToLocalLLM?',
                    description:
                        'CloudToLocalLLM is an innovative platform that lets you run AI language models on your own computer while managing them through a simple cloud interface.',
                    features: [
                      'Run Models Locally',
                      'Cloud Management',
                      'Cost Effective'
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureCard(
                    title: 'Coming Soon',
                    description:
                        "We're currently in development. Login will be available soon.",
                    // showButton: isUserLoggedIn, // Login button is now in AppBar
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    List<String> features = const [],
    // bool showButton = false, // Login button is now in AppBar
  }) {
    return Container(
      width: 500, // Max width for cards
      constraints: const BoxConstraints(
          maxWidth: 500), // Ensure it doesn\'t get too wide on large screens
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF252D3F)
            .withAlpha((255 * 0.85).round()), // Slightly transparent to show background hint. Fixed withAlpha
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 0.5), // Subtle border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: Color(0xFF6A5AE0)),
                      const SizedBox(width: 8),
                      Text(feature,
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                )),
          ],
          // if (showButton) ...[
          //   const SizedBox(height: 16),
          //   Align(
          //     alignment: Alignment.center,
          //     child: ElevatedButton(
          //       onPressed: () {},
          //       style: ElevatedButton.styleFrom(
          //         backgroundColor: const Color(0xFF6A5AE0),
          //         foregroundColor: Colors.white,
          //         padding:
          //             const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          //       ),
          //       child: const Text('Download App'),
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }
}
