import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../services/ollama_service.dart';

/// LLM Provider Settings Screen
/// 
/// Allows users to configure their LLM provider settings including
/// Ollama connection details and model preferences.
class LLMProviderSettingsScreen extends StatefulWidget {
  const LLMProviderSettingsScreen({super.key});

  @override
  State<LLMProviderSettingsScreen> createState() => _LLMProviderSettingsScreenState();
}

class _LLMProviderSettingsScreenState extends State<LLMProviderSettingsScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  bool _isLoading = false;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _loadAvailableModels();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    _hostController.text = AppConfig.defaultOllamaHost;
    _portController.text = AppConfig.defaultOllamaPort.toString();
  }

  Future<void> _loadAvailableModels() async {
    setState(() => _isLoading = true);
    
    try {
      final ollamaService = context.read<OllamaService>();
      final models = await ollamaService.getAvailableModels();
      setState(() {
        _availableModels = models;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _availableModels = [];
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load models: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    
    try {
      final ollamaService = context.read<OllamaService>();
      final isConnected = await ollamaService.testConnection();
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConnected 
                ? 'Connection successful!' 
                : 'Connection failed. Please check your settings.',
            ),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }
      
      if (isConnected) {
        await _loadAvailableModels();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM Provider Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionSection(),
            const SizedBox(height: 24),
            _buildModelsSection(),
            const SizedBox(height: 24),
            _buildActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ollama Connection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: 'localhost',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '11434',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testConnection,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Test Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Models',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_availableModels.isEmpty)
              const Text(
                'No models available. Please test your connection first.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableModels.length,
                itemBuilder: (context, index) {
                  final model = _availableModels[index];
                  return ListTile(
                    title: Text(model),
                    leading: const Icon(Icons.smart_toy),
                    dense: true,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadAvailableModels,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Models'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _hostController.text = AppConfig.defaultOllamaHost;
                  _portController.text = AppConfig.defaultOllamaPort.toString();
                },
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Defaults'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
