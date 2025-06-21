import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/conversation.dart';
import '../models/message.dart';

/// Service for persisting conversations to local SQLite database
class ConversationStorageService {
  static const String _databaseName = 'cloudtolocalllm_conversations.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String _conversationsTable = 'conversations';
  static const String _messagesTable = 'messages';

  Database? _database;

  /// Initialize the storage service
  Future<void> initialize() async {
    try {
      // Initialize sqflite for desktop platforms
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      await _initializeDatabase();
      debugPrint('💾 [ConversationStorage] Service initialized successfully');
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Failed to initialize: $e');
      rethrow;
    }
  }

  /// Initialize the database
  Future<void> _initializeDatabase() async {
    final databasePath = await _getDatabasePath();

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );

    debugPrint('💾 [ConversationStorage] Database opened at: $databasePath');
  }

  /// Get the database file path
  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      // For web, use a simple path (IndexedDB will be used internally)
      return _databaseName;
    }

    // For desktop/mobile, use app documents directory
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final appDirectory = Directory(
      join(documentsDirectory.path, 'CloudToLocalLLM'),
    );

    // Create directory if it doesn't exist
    if (!await appDirectory.exists()) {
      await appDirectory.create(recursive: true);
    }

    return join(appDirectory.path, _databaseName);
  }

  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    // Create conversations table
    await db.execute('''
      CREATE TABLE $_conversationsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        model TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create messages table
    await db.execute('''
      CREATE TABLE $_messagesTable (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        model TEXT,
        status TEXT NOT NULL,
        error TEXT,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES $_conversationsTable (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX idx_messages_conversation_id ON $_messagesTable (conversation_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_conversations_updated_at ON $_conversationsTable (updated_at DESC)
    ''');

    debugPrint('💾 [ConversationStorage] Database tables created');
  }

  /// Upgrade database schema
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint(
      '💾 [ConversationStorage] Upgrading database from v$oldVersion to v$newVersion',
    );
    // Add migration logic here when needed
  }

  /// Save a list of conversations
  Future<void> saveConversations(List<Conversation> conversations) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        // Clear existing data
        await txn.delete(_messagesTable);
        await txn.delete(_conversationsTable);

        // Insert conversations and messages
        for (final conversation in conversations) {
          await _insertConversation(txn, conversation);
          await _insertMessages(txn, conversation);
        }
      });

      debugPrint(
        '💾 [ConversationStorage] Saved ${conversations.length} conversations',
      );
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error saving conversations: $e');
      rethrow;
    }
  }

  /// Load all conversations
  Future<List<Conversation>> loadConversations() async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      // Load conversations ordered by most recently updated
      final conversationRows = await _database!.query(
        _conversationsTable,
        orderBy: 'updated_at DESC',
      );

      final conversations = <Conversation>[];

      for (final row in conversationRows) {
        final conversation = await _loadConversationWithMessages(row);
        conversations.add(conversation);
      }

      debugPrint(
        '💾 [ConversationStorage] Loaded ${conversations.length} conversations',
      );
      return conversations;
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error loading conversations: $e');
      return [];
    }
  }

  /// Save a single conversation (update or insert)
  Future<void> saveConversation(Conversation conversation) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        await _insertConversation(txn, conversation);

        // Delete existing messages for this conversation
        await txn.delete(
          _messagesTable,
          where: 'conversation_id = ?',
          whereArgs: [conversation.id],
        );

        // Insert updated messages
        await _insertMessages(txn, conversation);
      });

      debugPrint(
        '💾 [ConversationStorage] Saved conversation: ${conversation.title}',
      );
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error saving conversation: $e');
      rethrow;
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        // Delete messages first (foreign key constraint)
        await txn.delete(
          _messagesTable,
          where: 'conversation_id = ?',
          whereArgs: [conversationId],
        );

        // Delete conversation
        await txn.delete(
          _conversationsTable,
          where: 'id = ?',
          whereArgs: [conversationId],
        );
      });

      debugPrint(
        '💾 [ConversationStorage] Deleted conversation: $conversationId',
      );
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    if (_database == null) {
      throw StateError('Database not initialized');
    }

    try {
      await _database!.transaction((txn) async {
        await txn.delete(_messagesTable);
        await txn.delete(_conversationsTable);
      });

      debugPrint('💾 [ConversationStorage] Cleared all conversations');
    } catch (e) {
      debugPrint('💾 [ConversationStorage] Error clearing conversations: $e');
      rethrow;
    }
  }

  /// Insert a conversation into the database
  Future<void> _insertConversation(
    DatabaseExecutor txn,
    Conversation conversation,
  ) async {
    await txn.insert(_conversationsTable, {
      'id': conversation.id,
      'title': conversation.title,
      'model': conversation.model,
      'created_at': conversation.createdAt.millisecondsSinceEpoch,
      'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert messages for a conversation
  Future<void> _insertMessages(
    DatabaseExecutor txn,
    Conversation conversation,
  ) async {
    for (final message in conversation.messages) {
      await txn.insert(_messagesTable, {
        'id': message.id,
        'conversation_id': conversation.id,
        'role': message.role.name,
        'content': message.content,
        'model': message.model,
        'status': message.status.name,
        'error': message.error,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Load a conversation with its messages
  Future<Conversation> _loadConversationWithMessages(
    Map<String, dynamic> conversationRow,
  ) async {
    final conversationId = conversationRow['id'] as String;

    // Load messages for this conversation
    final messageRows = await _database!.query(
      _messagesTable,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );

    final messages = messageRows.map((row) => _messageFromRow(row)).toList();

    return Conversation(
      id: conversationId,
      title: conversationRow['title'] as String,
      model: conversationRow['model'] as String,
      messages: messages,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        conversationRow['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        conversationRow['updated_at'] as int,
      ),
    );
  }

  /// Create a Message from database row
  Message _messageFromRow(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      role: MessageRole.values.firstWhere(
        (role) => role.name == row['role'],
        orElse: () => MessageRole.user,
      ),
      content: row['content'] as String,
      model: row['model'] as String?,
      status: MessageStatus.values.firstWhere(
        (status) => status.name == row['status'],
        orElse: () => MessageStatus.sent,
      ),
      error: row['error'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }

  /// Close the database connection
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    debugPrint('💾 [ConversationStorage] Service disposed');
  }
}
