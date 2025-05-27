import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/config/theme.dart';

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
          // Header section matching homepage design
          Container(
            decoration: const BoxDecoration(
              gradient: CloudToLocalLLMTheme.headerGradient,
              boxShadow: CloudToLocalLLMTheme.smallShadow,
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                child: Column(
                  children: [
                    // Logo matching homepage
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: CloudToLocalLLMTheme.secondaryColor,
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: CloudToLocalLLMTheme.primaryColor,
                          width: 3,
                        ),
                        boxShadow: CloudToLocalLLMTheme.smallShadow,
                      ),
                      child: const Center(
                        child: Text(
                          'LLM',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: CloudToLocalLLMTheme.fontFamily,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title matching homepage
                    const Text(
                      'CloudToLocalLLM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.white,
                        fontFamily: CloudToLocalLLMTheme.fontFamily,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Color(0x446e8efb),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle matching homepage
                    const Text(
                      'Run powerful Large Language Models locally with cloud-based management',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFe0d7ff),
                        fontFamily: CloudToLocalLLMTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content area
          Expanded(
            child: Container(
              color: CloudToLocalLLMTheme.backgroundMain,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      decoration: BoxDecoration(
                        color: CloudToLocalLLMTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(
                            CloudToLocalLLMTheme.borderRadius),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 24,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: CloudToLocalLLMTheme.secondaryColor
                              .withValues(alpha: 0.27),
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
                                color: CloudToLocalLLMTheme.primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                fontFamily: CloudToLocalLLMTheme.fontFamily,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Card description
                            Text(
                              _isLogin
                                  ? 'Sign in to access your CloudToLocalLLM dashboard'
                                  : 'Create your account to get started with CloudToLocalLLM',
                              style: const TextStyle(
                                color: CloudToLocalLLMTheme.textColorLight,
                                fontSize: 16,
                                fontFamily: CloudToLocalLLMTheme.fontFamily,
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
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Submit button with homepage styling
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: CloudToLocalLLMTheme.buttonGradient,
                                borderRadius: BorderRadius.circular(
                                    CloudToLocalLLMTheme.borderRadiusSmall),
                                boxShadow: CloudToLocalLLMTheme.smallShadow,
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        CloudToLocalLLMTheme.borderRadiusSmall),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? 'Login' : 'Create Account',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontFamily:
                                              CloudToLocalLLMTheme.fontFamily,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: CloudToLocalLLMTheme.textColorLight
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: const TextStyle(
                                      color:
                                          CloudToLocalLLMTheme.textColorLight,
                                      fontWeight: FontWeight.bold,
                                      fontFamily:
                                          CloudToLocalLLMTheme.fontFamily,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: CloudToLocalLLMTheme.textColorLight
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Google Sign-In button
                            OutlinedButton.icon(
                              onPressed:
                                  _isGoogleLoading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                  color: CloudToLocalLLMTheme.secondaryColor
                                      .withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      CloudToLocalLLMTheme.borderRadiusSmall),
                                ),
                              ),
                              icon: _isGoogleLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(
                                      Icons.login,
                                      color: CloudToLocalLLMTheme.textColor,
                                    ),
                              label: const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  color: CloudToLocalLLMTheme.textColor,
                                  fontFamily: CloudToLocalLLMTheme.fontFamily,
                                ),
                              ),
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
                                  color: CloudToLocalLLMTheme.primaryColor,
                                  fontFamily: CloudToLocalLLMTheme.fontFamily,
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
            Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((255 * 0.8).round()),
            Theme.of(context)
                .colorScheme
                .secondary
                .withAlpha((255 * 0.6).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.3).round()),
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
