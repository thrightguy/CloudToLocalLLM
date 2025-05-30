import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/config/theme.dart';
import 'package:cloudtolocalllm/components/gradient_app_bar.dart';
import 'package:cloudtolocalllm/components/gradient_button.dart';
import 'package:cloudtolocalllm/components/modern_card.dart';

class HomeScreen extends StatelessWidget {
  final AuthService authService;

  const HomeScreen({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'CloudToLocalLLM',
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: authService.isAuthenticated,
            builder: (context, isAuthenticated, child) {
              if (isAuthenticated) {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await authService.logout();
                    if (context.mounted) {
                      GoRouter.of(context).go('/');
                    }
                  },
                  tooltip: 'Logout',
                );
              } else {
                return TextButton(
                  onPressed: () {
                    GoRouter.of(context).go('/login');
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
            },
          ),
        ],
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Run advanced AI models locally, managed by a cloud interface.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFe0d7ff),
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Main content card
                  ModernCard(
                    padding: EdgeInsets.all(AppTheme.spacingXL),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Content based on authentication status
                        ValueListenableBuilder<bool>(
                          valueListenable: authService.isAuthenticated,
                          builder: (context, isAuthenticated, child) {
                            if (isAuthenticated) {
                              return _buildAuthenticatedContent(context);
                            } else {
                              return _buildUnauthenticatedContent(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome to CloudToLocalLLM',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your AI models are ready to use. Start chatting with your local language models.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textColorLight,
                fontSize: 14,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          text: 'Start Chatting',
          icon: Icons.chat_bubble_outline,
          width: double.infinity,
          onPressed: () {
            GoRouter.of(context).go('/chat');
          },
        ),
      ],
    );
  }

  Widget _buildUnauthenticatedContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Please login to access your models and settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          'Authentication is required to use this application.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textColorLight,
                fontSize: 14,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          text: 'Login / Create Account',
          icon: Icons.login,
          width: double.infinity,
          onPressed: () {
            GoRouter.of(context).go('/login');
          },
        ),
      ],
    );
  }
}
