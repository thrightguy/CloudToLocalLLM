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
        if (success && authService.isAuthenticated.value) {
          // Redirect to home page on successful authentication
          context.go('/');
        } else {
          // Redirect to login page on failure
          context.go('/login');
        }
      }
    } catch (e) {
      debugPrint('Callback processing error: $e');
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
    return const LoadingScreen(
      message: 'Processing authentication...',
    );
  }
}
