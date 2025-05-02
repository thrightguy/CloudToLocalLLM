import 'package:flutter/foundation.dart';

enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isError;
  final bool isPending;

  Message({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isError = false,
    this.isPending = false,
  }) : timestamp = timestamp ?? DateTime.now();

  // Create a copy of this message with updated fields
  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isError,
    bool? isPending,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      isPending: isPending ?? this.isPending,
    );
  }

  // Convert message to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.toString().split('.').last,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
      'isPending': isPending,
    };
  }

  // Create message from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: _roleFromString(json['role']),
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isError: json['isError'] ?? false,
      isPending: json['isPending'] ?? false,
    );
  }

  // Helper method to convert string to MessageRole enum
  static MessageRole _roleFromString(String roleStr) {
    switch (roleStr) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.user;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.role == role &&
        other.content == content &&
        other.timestamp == timestamp &&
        other.isError == isError &&
        other.isPending == isPending;
  }

  @override
  int get hashCode => Object.hash(
        id,
        role,
        content,
        timestamp,
        isError,
        isPending,
      );
}