import 'package:flutter/material.dart';

class PromptInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final bool isLoading;

  const PromptInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> {
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateComposingState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateComposingState);
    super.dispose();
  }

  void _updateComposingState() {
    final isComposing = widget.controller.text.isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }
  }

  void _handleSubmitted() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    // Controller will be cleared by the parent
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(128),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            // Prompt input field
            Expanded(
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  suffixIcon: widget.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        )
                      : _isComposing
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                widget.controller.clear();
                              },
                            )
                          : null,
                ),
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.multiline,
                maxLines: 5,
                minLines: 1,
                onSubmitted: (_) => _handleSubmitted(),
                enabled: !widget.isLoading,
              ),
            ),

            // Send button
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: _isComposing && !widget.isLoading ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.white,
                  onPressed: (_isComposing && !widget.isLoading)
                      ? _handleSubmitted
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
