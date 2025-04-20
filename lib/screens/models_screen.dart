import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/llm_model.dart';
import '../providers/llm_provider.dart';
import '../providers/settings_provider.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({Key? key}) : super(key: key);

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  final TextEditingController _modelNameController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Refresh models when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshModels();
    });
  }

  @override
  void dispose() {
    _modelNameController.dispose();
    super.dispose();
  }

  // Refresh models list
  Future<void> _refreshModels() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await Provider.of<LlmProvider>(context, listen: false).refreshModels();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final llmProvider = Provider.of<LlmProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final models = llmProvider.models;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM Models'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshModels,
          ),
        ],
      ),
      body: _isRefreshing
          ? const Center(child: CircularProgressIndicator())
          : models.isEmpty
              ? _buildEmptyState()
              : _buildModelsList(models, llmProvider, settingsProvider),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddModelDialog(context),
        tooltip: 'Add Model',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Empty state when no models are available
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.model_training,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Models Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make sure Ollama or LM Studio is running',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshModels,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // List of models
  Widget _buildModelsList(
    List<LlmModel> models,
    LlmProvider llmProvider,
    SettingsProvider settingsProvider,
  ) {
    // Group models by provider
    final ollamaModels = models.where((m) => m.provider == 'ollama').toList();
    final lmStudioModels = models.where((m) => m.provider == 'lmstudio').toList();
    final otherModels = models.where((m) => m.provider != 'ollama' && m.provider != 'lmstudio').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Provider selection
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LLM Provider',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: settingsProvider.llmProvider,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ollama',
                      child: Text('Ollama'),
                    ),
                    DropdownMenuItem(
                      value: 'lmstudio',
                      child: Text('LM Studio'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settingsProvider.setLlmProvider(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Ollama models
        if (ollamaModels.isNotEmpty) ...[
          const Text(
            'Ollama Models',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...ollamaModels.map((model) => _buildModelCard(model, llmProvider)),
          const SizedBox(height: 16),
        ],

        // LM Studio models
        if (lmStudioModels.isNotEmpty) ...[
          const Text(
            'LM Studio Models',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...lmStudioModels.map((model) => _buildModelCard(model, llmProvider)),
          const SizedBox(height: 16),
        ],

        // Other models
        if (otherModels.isNotEmpty) ...[
          const Text(
            'Other Models',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...otherModels.map((model) => _buildModelCard(model, llmProvider)),
        ],
      ],
    );
  }

  // Model card
  Widget _buildModelCard(LlmModel model, LlmProvider llmProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (model.isDownloading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (model.isInstalled)
                  const Icon(Icons.check_circle, color: Colors.green)
                else
                  const Icon(Icons.cloud_download, color: Colors.blue),
              ],
            ),
            if (model.description != null) ...[
              const SizedBox(height: 8),
              Text(
                model.description!,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            if (model.size != null) ...[
              const SizedBox(height: 4),
              Text(
                'Size: ${(model.size! / 1024).toStringAsFixed(1)} GB',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            if (model.lastUsed != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last used: ${_formatDate(model.lastUsed!)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Download button
                if (!model.isInstalled && !model.isDownloading)
                  ElevatedButton.icon(
                    onPressed: () => _downloadModel(model.id),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                
                // Progress indicator
                if (model.isDownloading && model.downloadProgress != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: model.downloadProgress,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Downloading: ${(model.downloadProgress! * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                
                // Delete button
                if (model.isInstalled && !model.isDownloading)
                  TextButton.icon(
                    onPressed: () => _deleteModel(model.id, model.name),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                
                // Use button
                if (model.isInstalled && !model.isDownloading)
                  const SizedBox(width: 8),
                if (model.isInstalled && !model.isDownloading)
                  ElevatedButton.icon(
                    onPressed: () => _useModel(model.id),
                    icon: const Icon(Icons.chat),
                    label: const Text('Use'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Download model
  Future<void> _downloadModel(String modelId) async {
    final llmProvider = Provider.of<LlmProvider>(context, listen: false);
    
    try {
      await llmProvider.pullModel(
        modelId,
        onProgress: (progress) {
          // Progress is handled by the provider
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading model: $e')),
        );
      }
    }
  }

  // Delete model
  Future<void> _deleteModel(String modelId, String modelName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete $modelName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final llmProvider = Provider.of<LlmProvider>(context, listen: false);
      
      try {
        await llmProvider.deleteModel(modelId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting model: $e')),
          );
        }
      }
    }
  }

  // Use model
  void _useModel(String modelId) {
    final llmProvider = Provider.of<LlmProvider>(context, listen: false);
    
    // Create a new conversation with this model
    llmProvider.createConversation('New Conversation', modelId);
    
    // Navigate back to home screen
    Navigator.pop(context);
  }

  // Show dialog to add a new model
  Future<void> _showAddModelDialog(BuildContext context) async {
    _modelNameController.clear();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _modelNameController,
              decoration: const InputDecoration(
                labelText: 'Model Name',
                hintText: 'e.g., llama2, mistral, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_modelNameController.text.isNotEmpty) {
                _downloadModel(_modelNameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}