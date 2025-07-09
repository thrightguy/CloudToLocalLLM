import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../screens/loading_screen.dart';

/// Auth0 callback screen that processes authentication results
class CallbackScreen extends StatefulWidget {
  const CallbackScreen({super.key});

  @override
  State<CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends State<CallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processCallback();
    });
  }

  Future<void> _processCallback() async {
    try {
      final authService = context.read<AuthService>();
      final success = await authService.handleCallback();

      if (mounted) {
        if (success) {
          // Wait for authentication state to be properly set and propagated
          // This prevents race conditions with the router redirect logic
          await Future.delayed(const Duration(milliseconds: 100));

          // Double-check authentication state after delay and ensure context is still mounted
          if (mounted) {
            if (authService.isAuthenticated.value) {
              debugPrint(
                '🔐 [Callback] Authentication successful, redirecting to home',
              );
              context.go('/');
            } else {
              debugPrint(
                '🔐 [Callback] Authentication state not set after success, redirecting to login',
              );
              context.go('/login');
            }
          }
        } else {
          debugPrint(
            '🔐 [Callback] Authentication failed, redirecting to login',
          );
          // Redirect to login page on failure
          context.go('/login');
        }
      }
    } catch (e) {
      debugPrint('🔐 [Callback] Processing error: $e');
      if (mounted) {
        // Show error and redirect to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const LoadingScreen(message: 'Processing authentication...');
  }
}
