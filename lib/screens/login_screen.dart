import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/config/theme.dart';
import 'package:cloudtolocalllm/components/gradient_app_bar.dart';

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
      appBar: GradientAppBar(
        title: _isLogin ? 'Login' : 'Create Account',
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundMain,
              Color(0xFF1a1c24),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 8,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  side: BorderSide(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.27),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo matching homepage design
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                            color: AppTheme.primaryColor,
                            width: 3,
                          ),
                          boxShadow: const [AppTheme.boxShadowSmall],
                        ),
                        child: const Center(
                          child: Text(
                            'LLM',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'CloudToLocalLLM',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        _isLogin ? 'Welcome back!' : 'Create your account',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFFe0d7ff),
                              fontSize: 16,
                            ),
                      ),
                      const SizedBox(height: 32),

                      // Content
                      Text(
                        _isLogin
                            ? 'Sign in to access your CloudToLocalLLM dashboard and manage your local AI models.'
                            : 'Join CloudToLocalLLM to start running powerful AI models locally with cloud-based management.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textColorLight,
                              fontSize: 14,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 32),

                      // Auth Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppTheme.buttonGradient,
                          borderRadius:
                              BorderRadius.circular(AppTheme.borderRadiusSmall),
                          boxShadow: const [AppTheme.boxShadowSmall],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await authService.login();
                              if (context.mounted) {
                                // Navigate to home after successful login
                                GoRouter.of(context).go('/');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Login error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.borderRadiusSmall),
                            ),
                          ),
                          child: Text(
                            _isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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
    );
  }

  // Keep _isLogin for title logic, can be simplified further if not needed by router
  bool get _isLogin => !isRegistrationMode;
}
