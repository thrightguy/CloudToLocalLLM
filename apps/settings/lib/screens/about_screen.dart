import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// About screen showing app information
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App info
            _buildAppInfo(),
            const SizedBox(height: 24),

            // Description
            _buildDescription(),
            const SizedBox(height: 24),

            // Features
            _buildFeatures(),
            const SizedBox(height: 24),

            // Links
            _buildLinks(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.settings, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'CloudToLocalLLM Settings',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_packageInfo != null) ...[
              Text(
                'Version ${_packageInfo!.version}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Build ${_packageInfo!.buildNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text(
              'CloudToLocalLLM Settings is a configuration and testing application for the CloudToLocalLLM system. '
              'It provides an easy-to-use interface for managing connections to local Ollama servers, '
              'testing model functionality, and configuring system preferences.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Features', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const _FeatureItem(
              icon: Icons.wifi,
              title: 'Connection Management',
              description: 'Configure and test Ollama server connections',
            ),
            const _FeatureItem(
              icon: Icons.science,
              title: 'Model Testing',
              description: 'Test local LLM models with custom prompts',
            ),
            const _FeatureItem(
              icon: Icons.settings_system_daydream,
              title: 'System Integration',
              description: 'Communicate with system tray service',
            ),
            const _FeatureItem(
              icon: Icons.monitor_heart,
              title: 'Health Monitoring',
              description: 'Monitor connection health and status',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Links', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Website'),
              subtitle: const Text('cloudtolocalllm.online'),
              onTap: () {
                // TODO: Launch URL
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Source Code'),
              subtitle: const Text('github.com/imrightguy/CloudToLocalLLM'),
              onTap: () {
                // TODO: Launch URL
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Report Issues'),
              subtitle: const Text('GitHub Issues'),
              onTap: () {
                // TODO: Launch URL
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
