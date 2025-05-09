import 'package:flutter/material.dart';
import '../models/message.dart';

class ChatMessage extends StatelessWidget {
  final Message message;

  const ChatMessage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar for assistant messages
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message content
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getMessageColor(context, isUser),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message text
                  if (message.isPending)
                    const _LoadingIndicator()
                  else if (message.isError)
                    _ErrorMessage(message: message.content)
                  else
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        color: _getTextColor(context, isUser),
                      ),
                    ),

                  // Timestamp
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getTextColor(context, isUser).withAlpha(178),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar for user messages
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Get the background color for the message bubble
  Color _getMessageColor(BuildContext context, bool isUser) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isUser) {
      return theme.colorScheme.primary.withAlpha(204);
    } else {
      return isDark ? Colors.grey[800]! : Colors.grey[200]!;
    }
  }

  // Get the text color for the message
  Color _getTextColor(BuildContext context, bool isUser) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isUser) {
      return Colors.white;
    } else {
      return isDark ? Colors.white : Colors.black;
    }
  }

  // Format the timestamp
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      // Today, show time only
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Other days, show date and time
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Loading indicator for pending messages
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Generating response...',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
      ],
    );
  }
}

// Error message display
class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}
