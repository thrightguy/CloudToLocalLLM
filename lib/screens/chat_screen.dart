import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

class ChatScreen extends StatelessWidget {
  final AuthService authService;

  const ChatScreen({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'This is the default Chat Screen.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
