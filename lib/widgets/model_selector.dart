import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/llm_model.dart';
import '../providers/llm_provider.dart';

class ModelSelector extends StatelessWidget {
  final Function(String)? onModelSelected;

  const ModelSelector({
    super.key,
    this.onModelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final llmProvider = Provider.of<LlmProvider>(context);
    final models = llmProvider.models;

    // If no models are available, show a refresh button
    if (models.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh Models',
        onPressed: () async {
          await llmProvider.refreshModels();
        },
      );
    }

    // Get the current model ID from the current conversation or use the first model
    final currentModelId = llmProvider.currentConversation?.modelId ??
        (models.isNotEmpty ? models.first.id : '');

    // Find the current model
    final currentModel = models.firstWhere(
      (model) => model.id == currentModelId,
      orElse: () => models.isNotEmpty
          ? models.first
          : LlmModel(
              id: 'unknown',
              name: 'Unknown',
              provider: 'unknown',
            ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Select Model',
      onSelected: (modelId) {
        if (onModelSelected != null) {
          onModelSelected!(modelId);
        }
      },
      itemBuilder: (context) {
        return [
          // Header
          const PopupMenuItem<String>(
            enabled: false,
            child: Text(
              'Select Model',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const PopupMenuDivider(),

          // Models
          ...models.where((model) => model.isInstalled).map((model) {
            return PopupMenuItem<String>(
              value: model.id,
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    color: Colors.transparent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(model.name),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getProviderColor(model.provider),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      model.provider,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Divider before actions
          if (models.where((model) => model.isInstalled).isNotEmpty)
            const PopupMenuDivider(),

          // Manage models action
          PopupMenuItem<String>(
            value: 'manage_models',
            child: const Row(
              children: [
                Icon(Icons.settings),
                SizedBox(width: 8),
                Text('Manage Models'),
              ],
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentModel.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  // Get color for provider badge
  Color _getProviderColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'ollama':
        return Colors.blue;
      case 'lmstudio':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
