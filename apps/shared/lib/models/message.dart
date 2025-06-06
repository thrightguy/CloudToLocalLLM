import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

/// Represents a message in a conversation
@JsonSerializable()
class Message {
  /// Unique identifier for the message
  final String id;
  
  /// Role of the message sender
  final MessageRole role;
  
  /// Content of the message
  final String content;
  
  /// Timestamp when the message was created
  final DateTime timestamp;
  
  /// Whether the message is currently being streamed
  final bool isStreaming;
  
  /// Whether the message has an error
  final bool hasError;
  
  /// Error message if any
  final String? error;
  
  /// Metadata for the message
  final Map<String, dynamic> metadata;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.hasError = false,
    this.error,
    this.metadata = const {},
  });

  /// Create a message from JSON
  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  /// Convert message to JSON
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Create a new message with updated properties
  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create a user message
  factory Message.user({
    required String content,
    String? id,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? _generateId(),
      role: MessageRole.user,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata ?? {},
    );
  }

  /// Create an assistant message
  factory Message.assistant({
    required String content,
    String? id,
    DateTime? timestamp,
    bool isStreaming = false,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? _generateId(),
      role: MessageRole.assistant,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      isStreaming: isStreaming,
      metadata: metadata ?? {},
    );
  }

  /// Create a system message
  factory Message.system({
    required String content,
    String? id,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? _generateId(),
      role: MessageRole.system,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata ?? {},
    );
  }

  /// Create an error message
  factory Message.error({
    required String error,
    String? id,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? _generateId(),
      role: MessageRole.assistant,
      content: 'Error: $error',
      timestamp: timestamp ?? DateTime.now(),
      hasError: true,
      error: error,
      metadata: metadata ?? {},
    );
  }

  /// Mark message as streaming
  Message startStreaming() {
    return copyWith(isStreaming: true);
  }

  /// Mark message as finished streaming
  Message finishStreaming() {
    return copyWith(isStreaming: false);
  }

  /// Add content to the message (for streaming)
  Message appendContent(String additionalContent) {
    return copyWith(content: content + additionalContent);
  }

  /// Mark message as having an error
  Message markAsError(String errorMessage) {
    return copyWith(
      hasError: true,
      error: errorMessage,
      isStreaming: false,
    );
  }

  /// Generate a unique ID for the message
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Check if the message is from the user
  bool get isUser => role == MessageRole.user;

  /// Check if the message is from the assistant
  bool get isAssistant => role == MessageRole.assistant;

  /// Check if the message is a system message
  bool get isSystem => role == MessageRole.system;

  /// Get the display name for the message role
  String get roleDisplayName {
    switch (role) {
      case MessageRole.user:
        return 'You';
      case MessageRole.assistant:
        return 'Assistant';
      case MessageRole.system:
        return 'System';
    }
  }

  @override
  String toString() {
    return 'Message(id: $id, role: $role, content: ${content.length} chars)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Enum representing the role of a message sender
@JsonEnum()
enum MessageRole {
  @JsonValue('user')
  user,
  
  @JsonValue('assistant')
  assistant,
  
  @JsonValue('system')
  system,
}

/// Extension to add utility methods to MessageRole
extension MessageRoleExtension on MessageRole {
  /// Get the string representation of the role
  String get value {
    switch (this) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.system:
        return 'system';
    }
  }

  /// Create MessageRole from string
  static MessageRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        throw ArgumentError('Invalid message role: $value');
    }
  }
}
