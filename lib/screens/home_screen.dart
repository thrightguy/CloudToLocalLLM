import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/llm_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/chat_message.dart';
import '../widgets/model_selector.dart';
import '../widgets/prompt_input.dart';
import 'models_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(() {
      setState(() {
        _isComposing = _promptController.text.isNotEmpty;
      });
    });
    
    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  Future<void> _initializeProviders() async {
    final llmProvider = Provider.of<LlmProvider>(context, listen: false);
    await llmProvider.initialize();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final llmProvider = Provider.of<LlmProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudToLocalLLM'),
        actions: [
          // Model selector
          ModelSelector(
            onModelSelected: (modelId) {
              // Create a new conversation with the selected model
              if (llmProvider.currentConversation == null) {
                llmProvider.createConversation('New Conversation', modelId);
              }
            },
          ),
          
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          
          // Login/Account button
          IconButton(
            icon: Icon(
              authProvider.isAuthenticated
                  ? Icons.account_circle
                  : Icons.login,
            ),
            onPressed: () {
              if (authProvider.isAuthenticated) {
                // Show account screen or logout dialog
                _showLogoutDialog();
              } else {
                // Navigate to login screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      
      // Drawer for conversation history and models
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CloudToLocalLLM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.isAuthenticated
                        ? 'Logged in as: ${authProvider.currentUser?.name ?? authProvider.currentUser?.email ?? "User"}'
                        : 'Not logged in',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tunnel: ${settingsProvider.isTunnelConnected ? "Connected" : "Disconnected"}',
                    style: TextStyle(
                      color: settingsProvider.isTunnelConnected
                          ? Colors.green[100]
                          : Colors.red[100],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Conversations section
            const ListTile(
              title: Text(
                'Conversations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            
            // List of conversations
            ...llmProvider.conversations.map((conversation) {
              return ListTile(
                title: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: llmProvider.currentConversation?.id == conversation.id,
                onTap: () {
                  llmProvider.setCurrentConversation(conversation.id);
                  Navigator.pop(context); // Close drawer
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    llmProvider.deleteConversation(conversation.id);
                  },
                ),
              );
            }).toList(),
            
            // New conversation button
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Conversation'),
              onTap: () {
                // Create a new conversation with the default model
                llmProvider.createConversation(
                  'New Conversation',
                  llmProvider.models.isNotEmpty
                      ? llmProvider.models.first.id
                      : 'tinyllama',
                );
                Navigator.pop(context); // Close drawer
              },
            ),
            
            const Divider(),
            
            // Models section
            ListTile(
              leading: const Icon(Icons.model_training),
              title: const Text('Models'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModelsScreen()),
                );
              },
            ),
            
            // Settings
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            
            // Login/Logout
            ListTile(
              leading: Icon(
                authProvider.isAuthenticated ? Icons.logout : Icons.login,
              ),
              title: Text(
                authProvider.isAuthenticated ? 'Logout' : 'Login',
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                
                if (authProvider.isAuthenticated) {
                  _showLogoutDialog();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ),
      ),
      
      // Main content - chat messages
      body: llmProvider.currentConversation == null
          ? _buildWelcomeScreen()
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    reverse: true, // Start from the bottom
                    itemCount: llmProvider.currentConversation!.messages.length,
                    itemBuilder: (context, index) {
                      // Display messages in reverse order (newest first)
                      final reversedIndex = llmProvider.currentConversation!.messages.length - 1 - index;
                      final message = llmProvider.currentConversation!.messages[reversedIndex];
                      
                      return ChatMessage(message: message);
                    },
                  ),
                ),
                
                // Input area
                PromptInput(
                  controller: _promptController,
                  onSend: _handleSubmitted,
                  isLoading: llmProvider.isLoading,
                ),
              ],
            ),
      
      // FAB for new conversation
      floatingActionButton: llmProvider.currentConversation == null
          ? FloatingActionButton(
              onPressed: () {
                // Create a new conversation with the default model
                llmProvider.createConversation(
                  'New Conversation',
                  llmProvider.models.isNotEmpty
                      ? llmProvider.models.first.id
                      : 'tinyllama',
                );
              },
              tooltip: 'New Conversation',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // Handle sending a message
  void _handleSubmitted(String text) {
    if (text.isEmpty) return;
    
    final llmProvider = Provider.of<LlmProvider>(context, listen: false);
    
    // Clear the input field
    _promptController.clear();
    
    // Send the message
    llmProvider.sendMessage(text);
  }

  // Show logout confirmation dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Welcome screen when no conversation is selected
  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome to CloudToLocalLLM',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new conversation or select an existing one',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final llmProvider = Provider.of<LlmProvider>(context, listen: false);
              llmProvider.createConversation(
                'New Conversation',
                llmProvider.models.isNotEmpty
                    ? llmProvider.models.first.id
                    : 'tinyllama',
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('New Conversation'),
          ),
        ],
      ),
    );
  }
}