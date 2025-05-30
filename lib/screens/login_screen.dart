import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  final AuthService authService;
  final bool isRegistrationMode;

  const LoginScreen({
    super.key,
    required this.authService,
    this.isRegistrationMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Create Account'), // Basic title
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _isLogin
                ? 'This is the default Login Screen.'
                : 'This is the default Registration Screen.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Keep _isLogin for title logic, can be simplified further if not needed by router
  bool get _isLogin => !isRegistrationMode;
}
