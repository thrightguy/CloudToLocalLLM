import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/ollama_service.dart';
import '../services/auth_service.dart';

class OllamaTestScreen extends StatefulWidget {
  const OllamaTestScreen({super.key});

  @override
  State<OllamaTestScreen> createState() => _OllamaTestScreenState();
}

class _OllamaTestScreenState extends State<OllamaTestScreen> {
  late OllamaService _ollamaService;
  final TextEditingController _messageController = TextEditingController();
  String? _selectedModel;
  String? _chatResponse;

  @override
  void initState() {
    super.initState();
    _ollamaService = OllamaService();
    _testConnection();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _ollamaService.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final connected = await _ollamaService.testConnection();
    if (connected) {
      await _ollamaService.getModels();
      if (_ollamaService.models.isNotEmpty) {
        setState(() {
          _selectedModel = _ollamaService.models.first.name;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _selectedModel == null) return;

    final response = await _ollamaService.chat(
      model: _selectedModel!,
      message: _messageController.text,
    );

    setState(() {
      _chatResponse = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ollama Test'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Explicit back navigation
            if (context.canPop()) {
              context.pop();
            } else {
              // Fallback to home if no navigation stack
              context.go('/');
            }
          },
        ),
        actions: [
          // Back to Home button
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home),
            label: const Text('Home'),
          ),
          const SizedBox(width: 8),
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return TextButton.icon(
                onPressed: () async {
                  await authService.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(authService.currentUser?.name ?? 'Logout'),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Authentication Status
            Consumer<AuthService>(
              builder: (context, authService, child) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Authentication Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              authService.isAuthenticated.value
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: authService.isAuthenticated.value
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              authService.isAuthenticated.value
                                  ? 'Authenticated as ${authService.currentUser?.email ?? "Unknown"}'
                                  : 'Not authenticated',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Ollama Connection Status
            ListenableBuilder(
              listenable: _ollamaService,
              builder: (context, child) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ollama Connection',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _ollamaService.isConnected
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _ollamaService.isConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _ollamaService.isConnected
                                  ? 'Connected (v${_ollamaService.version})'
                                  : 'Not connected',
                            ),
                          ],
                        ),
                        if (_ollamaService.error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${_ollamaService.error}',
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _ollamaService.isLoading
                              ? null
                              : _testConnection,
                          child: _ollamaService.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Test Connection'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Models List
            ListenableBuilder(
              listenable: _ollamaService,
              builder: (context, child) {
                if (_ollamaService.models.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No models available. Make sure Ollama is running and has models installed.',
                      ),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Models (${_ollamaService.models.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: _selectedModel,
                          isExpanded: true,
                          items: _ollamaService.models.map((model) {
                            return DropdownMenuItem(
                              value: model.name,
                              child: Text(
                                '${model.displayName} (${model.sizeFormatted})',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedModel = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Chat Test
            if (_selectedModel != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Chat',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Enter a message to test the model...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _ollamaService.isLoading
                            ? null
                            : _sendMessage,
                        child: _ollamaService.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Send Message'),
                      ),
                      if (_chatResponse != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Response:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_chatResponse!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Explicit navigation back to home
          context.go('/');
        },
        icon: const Icon(Icons.home),
        label: const Text('Back to Home'),
        tooltip: 'Return to main application',
      ),
    );
  }
}
