import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/config/theme.dart';
import 'package:cloudtolocalllm/components/gradient_button.dart';
import 'package:cloudtolocalllm/components/gradient_app_bar.dart';
import 'package:cloudtolocalllm/main.dart' show CircularLlmLogo;

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final bool isRegistrationMode;

  const LoginScreen({
    super.key,
    required this.authService,
    this.isRegistrationMode = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isLogin; // Toggle between login and register
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.isRegistrationMode; // Initialize based on prop
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        if (_isLogin) {
          // Login
          await widget.authService.signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );

          if (mounted) {
            // Login successful, navigate to chat screen
            GoRouter.of(context).go('/chat');
          }
        } else {
          // Register
          await widget.authService.createUserWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );

          if (mounted) {
            // Registration successful, navigate to chat screen
            GoRouter.of(context).go('/chat');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'An error occurred: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = '';
    });

    try {
      await widget.authService.signInWithGoogle();

      if (mounted) {
        // Google Sign-In successful, navigate to chat screen
        GoRouter.of(context).go('/chat');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header section using HeroHeader component
          HeroHeader(
            title: 'CloudToLocalLLM',
            subtitle: 'Run powerful Large Language Models locally with cloud-based management',
            logo: const CircularLlmLogo(size: 70),
          ),

          // Main content area
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 24,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.27),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card title matching homepage
                            Text(
                              _isLogin ? 'Login' : 'Create Account',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Card description
                            Text(
                              _isLogin
                                  ? 'Sign in to access your CloudToLocalLLM dashboard'
                                  : 'Create your account to get started with CloudToLocalLLM',
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (!_isLogin && value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            // Error message
                            if (_errorMessage.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Submit button using GradientButton component
                            GradientButton(
                              text: _isLogin ? 'Login' : 'Create Account',
                              onPressed: _isLoading ? null : _submitForm,
                              isLoading: _isLoading,
                              width: double.infinity,
                              height: 48,
                            ),

                            const SizedBox(height: 16),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey,
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey,
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Google Sign-In button using SecondaryButton component
                            SecondaryButton(
                              text: 'Continue with Google',
                              onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                              isLoading: _isGoogleLoading,
                              icon: Icons.login,
                              width: double.infinity,
                              height: 48,
                            ),

                            const SizedBox(height: 24),

                            // Toggle button
                            TextButton(
                              onPressed: _isLoading || _isGoogleLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isLogin = !_isLogin;
                                        _errorMessage = '';
                                      });
                                    },
                              child: Text(
                                _isLogin
                                    ? 'Need an account? Sign Up'
                                    : 'Already have an account? Login',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
