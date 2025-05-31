import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../components/gradient_button.dart';
import '../components/modern_card.dart';

/// Modern home screen with clean design
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > AppConfig.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.headerGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                _buildHeader(context),

                // Main content
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop
                          ? AppConfig.maxContentWidth
                          : double.infinity,
                    ),
                    child: Column(
                      children: [
                        // Welcome card
                        _buildWelcomeCard(context),

                        SizedBox(height: AppTheme.spacingXL),

                        // Feature cards
                        if (isDesktop)
                          _buildDesktopFeatures(context)
                        else
                          _buildMobileFeatures(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
            ),
            child: const Icon(
              Icons.cloud_download_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),

          SizedBox(width: AppTheme.spacingM),

          // App name
          Text(
            AppConfig.appName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const Spacer(),

          // User menu
          Consumer<AuthService>(
            builder: (context, authService, child) {
              final user = authService.currentUser;
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    await authService.logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 18),
                        SizedBox(width: AppTheme.spacingS),
                        const Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          user?.initials ?? '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return ModernCard(
      padding: EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          Text(
            'Welcome to CloudToLocalLLM',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Manage and run powerful Large Language Models locally, orchestrated via a cloud interface.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textColorLight,
                  fontSize: 18,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacingXL),
          GradientButton(
            text: 'Test Ollama Connection',
            icon: Icons.computer,
            onPressed: () {
              context.go('/ollama-test');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFeatures(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildFeatureCard1(context)),
        SizedBox(width: AppTheme.spacingL),
        Expanded(child: _buildFeatureCard2(context)),
        SizedBox(width: AppTheme.spacingL),
        Expanded(child: _buildFeatureCard3(context)),
      ],
    );
  }

  Widget _buildMobileFeatures(BuildContext context) {
    return Column(
      children: [
        _buildFeatureCard1(context),
        SizedBox(height: AppTheme.spacingL),
        _buildFeatureCard2(context),
        SizedBox(height: AppTheme.spacingL),
        _buildFeatureCard3(context),
      ],
    );
  }

  Widget _buildFeatureCard1(BuildContext context) {
    return InfoCard(
      title: 'Local Models',
      description:
          'Run powerful LLMs directly on your hardware for maximum privacy and control.',
      icon: Icons.computer,
      iconColor: AppTheme.primaryColor,
      features: const [
        'Complete data privacy',
        'No internet required',
        'Custom model support',
      ],
    );
  }

  Widget _buildFeatureCard2(BuildContext context) {
    return InfoCard(
      title: 'Cloud Interface',
      description:
          'Manage your local models through an intuitive web interface.',
      icon: Icons.cloud,
      iconColor: AppTheme.secondaryColor,
      features: const [
        'Remote management',
        'Real-time monitoring',
        'Easy configuration',
      ],
    );
  }

  Widget _buildFeatureCard3(BuildContext context) {
    return InfoCard(
      title: 'High Performance',
      description:
          'Optimized for speed and efficiency across different hardware configurations.',
      icon: Icons.speed,
      iconColor: AppTheme.accentColor,
      features: const [
        'GPU acceleration',
        'Memory optimization',
        'Scalable architecture',
      ],
    );
  }
}
