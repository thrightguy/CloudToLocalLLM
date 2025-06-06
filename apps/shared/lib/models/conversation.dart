import 'package:json_annotation/json_annotation.dart';
import 'message.dart';

part 'conversation.g.dart';

/// Represents a conversation with an LLM
@JsonSerializable()
class Conversation {
  /// Unique identifier for the conversation
  final String id;
  
  /// Display title for the conversation
  final String title;
  
  /// List of messages in the conversation
  final List<Message> messages;
  
  /// Timestamp when the conversation was created
  final DateTime createdAt;
  
  /// Timestamp when the conversation was last updated
  final DateTime updatedAt;
  
  /// Model used for this conversation
  final String? model;
  
  /// Whether this conversation is archived
  final bool isArchived;
  
  /// Whether this conversation is pinned
  final bool isPinned;
  
  /// Tags associated with this conversation
  final List<String> tags;
  
  /// Metadata for the conversation
  final Map<String, dynamic> metadata;

  const Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.model,
    this.isArchived = false,
    this.isPinned = false,
    this.tags = const [],
    this.metadata = const {},
  });

  /// Create a conversation from JSON
  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);

  /// Convert conversation to JSON
  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  /// Create a new conversation with updated properties
  Conversation copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? model,
    bool? isArchived,
    bool? isPinned,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      model: model ?? this.model,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Add a message to the conversation
  Conversation addMessage(Message message) {
    return copyWith(
      messages: [...messages, message],
      updatedAt: DateTime.now(),
    );
  }

  /// Update the last message in the conversation
  Conversation updateLastMessage(Message message) {
    if (messages.isEmpty) {
      return addMessage(message);
    }

    final updatedMessages = [...messages];
    updatedMessages[updatedMessages.length - 1] = message;

    return copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
  }

  /// Get the last message in the conversation
  Message? get lastMessage {
    return messages.isNotEmpty ? messages.last : null;
  }

  /// Get the number of messages in the conversation
  int get messageCount => messages.length;

  /// Check if the conversation is empty
  bool get isEmpty => messages.isEmpty;

  /// Get a preview of the conversation (first user message or title)
  String get preview {
    final firstUserMessage = messages
        .where((m) => m.role == MessageRole.user)
        .firstOrNull;
    
    if (firstUserMessage != null) {
      return firstUserMessage.content.length > 100
          ? '${firstUserMessage.content.substring(0, 100)}...'
          : firstUserMessage.content;
    }
    
    return title;
  }

  /// Generate a title from the first user message
  static String generateTitle(String firstMessage) {
    if (firstMessage.isEmpty) return 'New Conversation';
    
    // Take first sentence or first 50 characters
    final sentences = firstMessage.split(RegExp(r'[.!?]+'));
    final firstSentence = sentences.first.trim();
    
    if (firstSentence.length <= 50) {
      return firstSentence;
    }
    
    return '${firstMessage.substring(0, 47)}...';
  }

  @override
  String toString() {
    return 'Conversation(id: $id, title: $title, messages: ${messages.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
