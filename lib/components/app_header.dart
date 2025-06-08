import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Reusable app header component with consistent styling
/// Used across different screens to maintain design consistency
class AppHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? leading;

  const AppHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          // Leading widget or back button
          if (leading != null)
            leading!
          else if (showBackButton)
            IconButton(
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              tooltip: 'Back',
            ),

          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Actions
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
