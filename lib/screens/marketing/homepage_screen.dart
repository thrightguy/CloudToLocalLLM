import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Marketing homepage screen - web-only
/// Replicates the static site design with Material Design 3
class HomepageScreen extends StatelessWidget {
  const HomepageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(child: Text('This page is only available on web')),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildMainContent(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6e8efb), Color(0xFFa777e3)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          // Logo
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF6e8efb),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: const Color(0xFFa777e3), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'LLM',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFa777e3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'CloudToLocalLLM',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 40,
              letterSpacing: 1,
              shadows: [
                Shadow(
                  color: const Color(0xFF6e8efb).withValues(alpha: 0.27),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Run powerful Large Language Models locally with cloud-based management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFFe0d7ff),
              fontWeight: FontWeight.w500,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Container(
      color: const Color(0xFF181a20),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          _buildInfoCard(context),
          const SizedBox(height: 40),
          _buildDownloadCard(context),
          const SizedBox(height: 40),
          _buildWebAppCard(context),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return _buildCard(
      context,
      title: 'What is CloudToLocalLLM?',
      description:
          'CloudToLocalLLM is an innovative platform that lets you run AI language models on your own computer while managing them through a simple cloud interface.',
      features: ['Run Models Locally', 'Cloud Management', 'Cost Effective'],
    );
  }

  Widget _buildDownloadCard(BuildContext context) {
    return _buildCard(
      context,
      title: 'Download CloudToLocalLLM',
      description:
          'Get the desktop application for Linux with multiple installation options',
      child: Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: ElevatedButton(
              onPressed: () => context.go('/download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6e8efb),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 28,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Download Options',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'AppImage • Debian Package • AUR • Pre-built Binary',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFb0b0b0),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebAppCard(BuildContext context) {
    return _buildCard(
      context,
      title: 'Web Application',
      description:
          'Access CloudToLocalLLM through your web browser with cloud streaming',
      child: Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: ElevatedButton(
              onPressed: () => context.go('/chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6e8efb),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 28,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Launch Web App',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String description,
    List<String>? features,
    Widget? child,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: const Color(0xFF23243a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6e8efb).withValues(alpha: 0.27),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFFa777e3),
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFb0b0b0),
              fontSize: 16,
            ),
          ),
          if (features != null) ...[
            const SizedBox(height: 20),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: Color(0xFFf1f1f1)),
                    ),
                    Text(
                      feature,
                      style: const TextStyle(
                        color: Color(0xFFf1f1f1),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: const Color(0xFF181a20),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: const SizedBox.shrink(),
    );
  }
}
