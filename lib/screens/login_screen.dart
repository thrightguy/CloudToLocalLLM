import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../components/gradient_button.dart';
import '../components/modern_card.dart';
import '../widgets/auth_debug_panel.dart';

/// Modern login screen with Auth0 integration
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.login();

      if (mounted && authService.isAuthenticated.value) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: AppTheme.dangerColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > AppConfig.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.headerGradient,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 400 : double.infinity,
                    ),
                    child: ModernCard(
                      padding: EdgeInsets.all(AppTheme.spacingXL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo/Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppTheme.buttonGradient,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.borderRadiusM),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.cloud_download_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),

                          SizedBox(height: AppTheme.spacingXL),

                          // Welcome text
                          Text(
                            'Welcome to',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppTheme.textColorLight,
                                  fontSize: 18,
                                ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: AppTheme.spacingS),

                          Text(
                            AppConfig.appName,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: AppTheme.spacingM),

                          Text(
                            AppConfig.appDescription,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.textColorLight,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: AppTheme.spacingXXL),

                          // Login button
                          GradientButton(
                            text: 'Sign In with Auth0',
                            icon: Icons.login,
                            width: double.infinity,
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                          ),

                          SizedBox(height: AppTheme.spacingL),

                          // Additional info
                          Text(
                            'Secure authentication powered by Auth0',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textColorLight,
                                      fontSize: 12,
                                    ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: AppTheme.spacingM),

                          // Links
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  // Open homepage in new tab
                                },
                                child: Text(
                                  'Learn More',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  color: AppTheme.textColorLight,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Open GitHub in new tab
                                },
                                child: Text(
                                  'GitHub',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Debug panel (only visible in debug mode)
          const AuthDebugPanel(),
        ],
      ),
    );
  }
}
