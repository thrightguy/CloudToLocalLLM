import 'package:flutter/material.dart';
import 'package:cloudtolocalllm_shared/version.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check version compatibility
  final compatibilityReport =
      await VersionCompatibility.getCompatibilityReport();
  if (!compatibilityReport['shared_library_compatible']) {
    debugPrint('WARNING: Shared library version incompatible');
  }

  runApp(const CloudToLocalLLMMainApp());
}

class CloudToLocalLLMMainApp extends StatelessWidget {
  const CloudToLocalLLMMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudToLocalLLM',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudToLocalLLM'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat, size: 64, color: Color(0xFF6366F1)),
            const SizedBox(height: 16),
            const Text(
              'CloudToLocalLLM',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Personal AI Powerhouse',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 20,
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.only(right: 8, bottom: 2),
        child: Tooltip(
          message: VersionDisplay.getDetailedVersion(
            CloudToLocalLLMVersions.mainAppVersion,
            CloudToLocalLLMVersions.mainAppBuildNumber,
          ),
          child: Text(
            'v${CloudToLocalLLMVersions.mainAppVersion}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
