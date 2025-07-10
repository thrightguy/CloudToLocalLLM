import 'message.dart';

/// Represents a chat conversation containing multiple messages
class Conversation {
  final String id;
  final String title;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? model; // Default model for this conversation
  final Map<String, dynamic> metadata; // Additional conversation data

  const Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.model,
    this.metadata = const {},
  });

  /// Create a new conversation
  factory Conversation.create({String? title, String? model, String? id}) {
    final now = DateTime.now();
    return Conversation(
      id: id ?? _generateId(),
      title: title ?? 'New Conversation',
      messages: [],
      createdAt: now,
      updatedAt: now,
      model: model,
    );
  }

  /// Create conversation from JSON
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Conversation',
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((m) => Message.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      model: json['model'],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert conversation to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'model': model,
      'metadata': metadata,
    };
  }

  /// Copy with method for immutable updates
  Conversation copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? model,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      model: model ?? this.model,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Add a message to the conversation
  Conversation addMessage(Message message) {
    final updatedMessages = List<Message>.from(messages)..add(message);
    return copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
      title: _shouldUpdateTitle() ? _generateTitleFromMessage(message) : title,
    );
  }

  /// Update a message in the conversation
  Conversation updateMessage(String messageId, Message updatedMessage) {
    final updatedMessages = messages
        .map((m) => m.id == messageId ? updatedMessage : m)
        .toList();
    return copyWith(messages: updatedMessages, updatedAt: DateTime.now());
  }

  /// Remove a message from the conversation
  Conversation removeMessage(String messageId) {
    final updatedMessages = messages.where((m) => m.id != messageId).toList();
    return copyWith(messages: updatedMessages, updatedAt: DateTime.now());
  }

  /// Update conversation title
  Conversation updateTitle(String newTitle) {
    return copyWith(title: newTitle, updatedAt: DateTime.now());
  }

  /// Update default model
  Conversation updateModel(String newModel) {
    return copyWith(model: newModel, updatedAt: DateTime.now());
  }

  /// Get the last message in the conversation
  Message? get lastMessage {
    return messages.isNotEmpty ? messages.last : null;
  }

  /// Get the last user message
  Message? get lastUserMessage {
    try {
      return messages.lastWhere((m) => m.isUser);
    } catch (e) {
      return null; // Return null instead of throwing error
    }
  }

  /// Get the last assistant message
  Message? get lastAssistantMessage {
    try {
      return messages.lastWhere((m) => m.isAssistant);
    } catch (e) {
      return null;
    }
  }

  /// Get conversation preview (first few words of the first user message)
  String get preview {
    try {
      final firstUserMessage = messages.firstWhere((m) => m.isUser);
      final content = firstUserMessage.content.trim();
      if (content.length <= 50) return content;
      return '${content.substring(0, 50)}...';
    } catch (e) {
      // Return default preview when no user messages exist
      return 'New conversation';
    }
  }

  /// Check if conversation is empty
  bool get isEmpty => messages.isEmpty;

  /// Check if conversation has any user messages
  bool get hasUserMessages => messages.any((m) => m.isUser);

  /// Get message count
  int get messageCount => messages.length;

  /// Get user message count
  int get userMessageCount => messages.where((m) => m.isUser).length;

  /// Get assistant message count
  int get assistantMessageCount => messages.where((m) => m.isAssistant).length;

  /// Check if the conversation is currently waiting for a response
  bool get isWaitingForResponse {
    if (messages.isEmpty) return false;
    final lastMessage = messages.last;
    return lastMessage.isUser || lastMessage.isLoading;
  }

  /// Get formatted creation date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if title should be auto-updated
  bool _shouldUpdateTitle() {
    return title == 'New Conversation' && messages.length == 1;
  }

  /// Generate title from the first user message
  String _generateTitleFromMessage(Message message) {
    if (!message.isUser) return title;

    final content = message.content.trim();
    if (content.isEmpty) return title;

    // Take first 30 characters and add ellipsis if needed
    if (content.length <= 30) return content;
    return '${content.substring(0, 30)}...';
  }

  /// Generate a unique ID for the conversation
  static String _generateId() {
    return 'conv_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Conversation(id: $id, title: $title, messages: ${messages.length})';
  }
}
