import 'package:flutter/material.dart';

void main() {
  runApp(const CloudToLocalLLMApp());
}

class CloudToLocalLLMApp extends StatelessWidget {
  const CloudToLocalLLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudToLocalLLM Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5AE0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5AE0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121829),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace this with actual authentication state
    final bool isUserLoggedIn = false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CloudToLocalLLM Portal',
          style: TextStyle(color: Colors.white70),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/CloudToLocalLLM_logo.jpg',
                width: 150,
                height: 150,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'CloudToLocalLLM',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Run powerful Large Language Models locally with cloud-based management',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            _buildFeatureCard(
              title: 'What is CloudToLocalLLM?',
              description:
                  'CloudToLocalLLM is an innovative platform that lets you run AI language models on your own computer while managing them through a simple cloud interface.',
              features: [
                'Run Models Locally',
                'Cloud Management',
                'Cost Effective'
              ],
            ),
            const SizedBox(height: 24),
            _buildFeatureCard(
              title: 'Coming Soon',
              description:
                  'We\'re currently in development. Visit beta.cloudtolocalllm.online to try our beta version.',
              showButton: isUserLoggedIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    List<String> features = const [],
    bool showButton = false,
  }) {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF252D3F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: Color(0xFF6A5AE0)),
                      const SizedBox(width: 8),
                      Text(feature),
                    ],
                  ),
                )),
          ],
          if (showButton) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A5AE0),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Download App'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
