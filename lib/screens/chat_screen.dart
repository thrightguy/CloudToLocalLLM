import 'package:flutter/material.dart';
import '../widgets/version_info_footer.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildChatContent(),
          ),
          const VersionInfoFooter(
            showBuild: true,
            isDiscrete: true,
            padding: EdgeInsets.only(bottom: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    return const Center(
      child: Text('Chat content will be implemented here'),
    );
  }
}
