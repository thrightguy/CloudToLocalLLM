import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../models/conversation.dart';
import '../services/auth_service.dart';
import '../services/streaming_chat_service.dart';
import '../services/tunnel_manager_service.dart';
import '../services/ollama_service.dart';
import '../components/conversation_list.dart';
import '../components/message_bubble.dart';
import '../components/message_input.dart';
import '../components/app_logo.dart';

/// Modern ChatGPT-like chat interface
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamingChatService? _streamingChatService;
  TunnelManagerService? _tunnelManagerService;
  OllamaService? _ollamaService;
  bool _isSidebarCollapsed = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize services after the first frame to access context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  /// Initialize all services with streaming support
  Future<void> _initializeServices() async {
    try {
      debugPrint('[DEBUG] HomeScreen: Initializing services...');

      final authService = Provider.of<AuthService>(context, listen: false);
      debugPrint(
        '[DEBUG] HomeScreen: AuthService obtained - isAuthenticated: ${authService.isAuthenticated.value}',
      );

      // Initialize tunnel manager service
      final tunnelManagerService = TunnelManagerService();
      await tunnelManagerService.initialize();

      // Initialize Ollama service (for fallback)
      final ollamaService = OllamaService(authService: authService);

      // Initialize streaming chat service
      final streamingChatService = StreamingChatService(tunnelManagerService);

      setState(() {
        _tunnelManagerService = tunnelManagerService;
        _ollamaService = ollamaService;
        _streamingChatService = streamingChatService;
      });

      debugPrint('[DEBUG] HomeScreen: Services initialized successfully');

      // Test connections asynchronously (non-blocking)
      _testConnectionAsync();
    } catch (e) {
      debugPrint('[DEBUG] HomeScreen: Service initialization error: $e');
      // Don't block the UI even if service initialization fails
    }
  }

  /// Test connections asynchronously without blocking the UI
  Future<void> _testConnectionAsync() async {
    try {
      debugPrint('[DEBUG] Starting async connection tests...');

      // Test tunnel manager connections
      if (_tunnelManagerService != null) {
        debugPrint('[DEBUG] Testing tunnel manager connections...');
        // Tunnel manager will handle its own connection testing
      }

      // Test Ollama service connection
      if (_ollamaService != null) {
        _ollamaService!
            .testConnection()
            .then((connected) {
              debugPrint(
                '[DEBUG] Ollama connection test completed: $connected',
              );
              if (!connected) {
                debugPrint(
                  '[DEBUG] Ollama connection failed, but UI remains functional',
                );
              } else {
                debugPrint('[DEBUG] Ollama connection successful');
              }
            })
            .catchError((error) {
              debugPrint('[DEBUG] Ollama connection test error: $error');
            });
      }

      debugPrint('[DEBUG] Connection tests started (non-blocking)');
    } catch (e) {
      debugPrint('[DEBUG] Connection test initialization error: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppConfig.mobileBreakpoint;

    // Auto-collapse sidebar on mobile
    if (isMobile && !_isSidebarCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isSidebarCollapsed = true;
        });
      });
    }

    // Show loading screen if services are not initialized yet
    if (_streamingChatService == null || _ollamaService == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundMain,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _streamingChatService),
        ChangeNotifierProvider.value(value: _ollamaService),
        if (_tunnelManagerService != null)
          ChangeNotifierProvider.value(value: _tunnelManagerService),
      ],
      child: Scaffold(
        backgroundColor: AppTheme.backgroundMain,
        body: Column(
          children: [
            // Header with gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
              ),
              child: _buildHeader(context),
            ),

            // Main chat interface
            Expanded(
              child: Row(
                children: [
                  // Conversation sidebar
                  if (!isMobile || !_isSidebarCollapsed)
                    Consumer<StreamingChatService>(
                      builder: (context, chatService, child) {
                        return ConversationList(
                          conversations: chatService.conversations,
                          selectedConversation: chatService.currentConversation,
                          onConversationSelected: (conversationId) {
                            final conversation = chatService.conversations
                                .firstWhere((c) => c.id == conversationId);
                            chatService.selectConversation(conversation);
                          },
                          onConversationDeleted: (conversationId) {
                            final conversation = chatService.conversations
                                .firstWhere((c) => c.id == conversationId);
                            chatService.deleteConversation(conversation);
                          },
                          onConversationRenamed: (conversationId, newTitle) {
                            final conversation = chatService.conversations
                                .firstWhere((c) => c.id == conversationId);
                            chatService.updateConversationTitle(
                              conversation,
                              newTitle,
                            );
                          },
                          onNewConversation: () =>
                              chatService.createConversation(),
                          isCollapsed: _isSidebarCollapsed,
                        );
                      },
                    ),

                  // Main chat area
                  Expanded(child: _buildChatArea(context)),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: isMobile && _isSidebarCollapsed
            ? Consumer<StreamingChatService>(
                builder: (context, chatService, child) {
                  return FloatingActionButton(
                    onPressed: () => chatService.createConversation(),
                    backgroundColor: AppTheme.primaryColor,
                    child: const Icon(Icons.add, color: Colors.white),
                  );
                },
              )
            : null,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          // Sidebar toggle (mobile)
          if (MediaQuery.of(context).size.width < AppConfig.mobileBreakpoint)
            IconButton(
              onPressed: () {
                setState(() {
                  _isSidebarCollapsed = !_isSidebarCollapsed;
                });
              },
              icon: Icon(
                _isSidebarCollapsed ? Icons.menu : Icons.menu_open,
                color: Colors.white,
              ),
            ),

          // Logo and app name
          const AppLogo.small(
            backgroundColor: Colors.white,
            textColor: Color(0xFF6e8efb),
            borderColor: Color(0xFFa777e3),
          ),

          SizedBox(width: AppTheme.spacingS),

          Text(
            AppConfig.appName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Model selector
          Consumer2<StreamingChatService, OllamaService>(
            builder: (context, chatService, ollamaService, child) {
              final models = ollamaService.models.map((m) => m.name).toList();
              return Container(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: chatService.selectedModel,
                    hint: Text(
                      'Select Model',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    items: models.map((model) {
                      return DropdownMenuItem(
                        value: model,
                        child: Text(
                          model,
                          style: const TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (model) {
                      if (model != null) {
                        chatService.setSelectedModel(model);
                      }
                    },
                    dropdownColor: Colors.white,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(width: AppTheme.spacingM),

          // User menu
          Consumer<AuthService>(
            builder: (context, authService, child) {
              final user = authService.currentUser;
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'settings':
                      context.go('/settings');
                      break;
                    case 'logout':
                      await authService.logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings, size: 18),
                        SizedBox(width: AppTheme.spacingS),
                        const Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 18),
                        SizedBox(width: AppTheme.spacingS),
                        const Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                ),
                color: AppTheme.backgroundCard,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                child: Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          user?.initials ?? '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      Text(
                        user?.displayName ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingS),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(BuildContext context) {
    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        final conversation = chatService.currentConversation;

        if (conversation == null) {
          return _buildEmptyState(context);
        }

        return Container(
          color: AppTheme.backgroundMain,
          child: Column(
            children: [
              // Chat messages
              Expanded(
                child: Container(
                  color: AppTheme.backgroundMain,
                  child: _buildChatMessages(conversation),
                ),
              ),

              // Message input
              Container(
                color: AppTheme.backgroundMain,
                child: MessageInput(
                  onSendMessage: (message) =>
                      _sendMessage(chatService, message),
                  isLoading: chatService.isLoading,
                  placeholder: chatService.selectedModel == null
                      ? 'Please select a model first...'
                      : 'Type your message...',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textColorLight,
          ),
          SizedBox(height: AppTheme.spacingL),
          Text(
            'Welcome to CloudToLocalLLM',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Start a new conversation to begin chatting with your local LLM',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textColorLight),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacingXL),
          Consumer<StreamingChatService>(
            builder: (context, chatService, child) {
              return ElevatedButton.icon(
                onPressed: () => chatService.createConversation(),
                icon: const Icon(Icons.add),
                label: const Text('Start New Conversation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                    vertical: AppTheme.spacingM,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build chat messages with error handling
  Widget _buildChatMessages(Conversation conversation) {
    try {
      if (conversation.messages.isEmpty) {
        return _buildEmptyConversation();
      }

      return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        itemCount: conversation.messages.length,
        itemBuilder: (context, index) {
          try {
            if (index >= conversation.messages.length) {
              // Safety check to prevent index out of bounds
              return const SizedBox.shrink();
            }

            final message = conversation.messages[index];
            return MessageBubble(
              message: message,
              showAvatar: true,
              showTimestamp:
                  index == 0 ||
                  (index > 0 &&
                      conversation.messages[index - 1].role != message.role),
              onRetry: message.hasError
                  ? () => _retryMessage(
                      Provider.of<StreamingChatService>(context, listen: false),
                      message,
                    )
                  : null,
            );
          } catch (e) {
            debugPrint('Error building message at index $index: $e');
            return Container(
              padding: EdgeInsets.all(AppTheme.spacingM),
              child: Text(
                'Error displaying message',
                style: TextStyle(color: AppTheme.dangerColor),
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Error building chat messages: $e');
      return _buildErrorState('Error loading messages');
    }
  }

  Widget _buildEmptyConversation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy, size: 48, color: AppTheme.textColorLight),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'How can I help you today?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            'Type a message below to start the conversation',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.dangerColor),
          SizedBox(height: AppTheme.spacingL),
          Text(
            'Something went wrong',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppTheme.textColor),
          ),
          SizedBox(height: AppTheme.spacingS),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _sendMessage(StreamingChatService chatService, String message) async {
    await chatService.sendMessage(message);

    // Scroll to bottom after sending message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _retryMessage(StreamingChatService chatService, message) {
    // TODO: Implement retry functionality
    // This would involve resending the last user message
  }
}
