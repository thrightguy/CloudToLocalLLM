import 'package:flutter/material.dart';

/// Stub implementation of AuthDebugPanel for non-web platforms
/// This widget does nothing and is invisible on non-web platforms
class AuthDebugPanel extends StatelessWidget {
  const AuthDebugPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
