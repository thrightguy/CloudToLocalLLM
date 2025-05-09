import 'message.dart';

class Conversation {
  final String id;
  final String title;
  final List<Message> messages;
  final String modelId;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final Map<String, dynamic>? metadata;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.modelId,
    DateTime? createdAt,
    DateTime? lastUpdated,
    this.metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  // Create a copy of this conversation with updated fields
  Conversation copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    String? modelId,
    DateTime? createdAt,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }

  // Add a message to the conversation
  Conversation addMessage(Message message) {
    final updatedMessages = List<Message>.from(messages)..add(message);
    return copyWith(
      messages: updatedMessages,
      lastUpdated: DateTime.now(),
    );
  }

  // Update a message in the conversation
  Conversation updateMessage(String messageId, Message updatedMessage) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return this;

    final updatedMessages = List<Message>.from(messages);
    updatedMessages[index] = updatedMessage;

    return copyWith(
      messages: updatedMessages,
      lastUpdated: DateTime.now(),
    );
  }

  // Remove a message from the conversation
  Conversation removeMessage(String messageId) {
    final updatedMessages = messages.where((m) => m.id != messageId).toList();
    return copyWith(
      messages: updatedMessages,
      lastUpdated: DateTime.now(),
    );
  }

  // Convert conversation to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'modelId': modelId,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Create conversation from JSON
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
      modelId: json['modelId'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      metadata: json['metadata'],
    );
  }

  // Create a new empty conversation
  factory Conversation.create({
    required String id,
    required String title,
    required String modelId,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id,
      title: title,
      messages: [],
      modelId: modelId,
      metadata: metadata,
    );
  }
}