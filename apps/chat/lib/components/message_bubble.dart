import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/message.dart';

/// A chat message bubble component similar to ChatGPT
class MessageBubble extends StatefulWidget {
  final Message message;
  final bool showAvatar;
  final bool showTimestamp;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.showTimestamp = false,
    this.onRetry,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: EdgeInsets.symmetric(
            vertical: AppTheme.spacingXS,
            horizontal: AppTheme.spacingM,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              if (widget.showAvatar) ...[
                _buildAvatar(),
                SizedBox(width: AppTheme.spacingM),
              ],

              // Message content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message header
                    if (widget.message.isAssistant || widget.showTimestamp)
                      _buildMessageHeader(),

                    // Message bubble
                    _buildMessageContent(),

                    // Message actions
                    if (_isHovered && !widget.message.isLoading)
                      _buildMessageActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.message.isUser) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 18,
        ),
      );
    } else {
      return CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.secondaryColor,
        child: const Icon(
          Icons.smart_toy,
          color: Colors.white,
          size: 18,
        ),
      );
    }
  }

  Widget _buildMessageHeader() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.spacingXS),
      child: Row(
        children: [
          Text(
            widget.message.isUser
                ? 'You'
                : (widget.message.model ?? 'Assistant'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textColorLight,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (widget.showTimestamp) ...[
            SizedBox(width: AppTheme.spacingS),
            Text(
              widget.message.formattedTime,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    if (widget.message.isLoading) {
      return _buildLoadingContent();
    }

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: widget.message.isUser
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(
          color: widget.message.isUser
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.secondaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.hasError) _buildErrorHeader(),
          SelectableText(
            widget.message.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textColor,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          SizedBox(width: AppTheme.spacingS),
          Text(
            'Thinking...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textColorLight,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorHeader() {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: AppTheme.dangerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.dangerColor,
            size: 16,
          ),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              'Error: ${widget.message.error ?? 'Unknown error'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.dangerColor,
                  ),
            ),
          ),
          if (widget.onRetry != null)
            IconButton(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              iconSize: 16,
              color: AppTheme.dangerColor,
              tooltip: 'Retry',
            ),
        ],
      ),
    );
  }

  Widget _buildMessageActions() {
    return Padding(
      padding: EdgeInsets.only(top: AppTheme.spacingXS),
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.copy,
            tooltip: 'Copy message',
            onPressed: () => _copyMessage(),
          ),
          if (widget.message.hasError && widget.onRetry != null)
            _buildActionButton(
              icon: Icons.refresh,
              tooltip: 'Retry',
              onPressed: widget.onRetry!,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: AppTheme.spacingS),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 16,
        color: AppTheme.textColorLight,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
          ),
          padding: EdgeInsets.all(AppTheme.spacingXS),
          minimumSize: const Size(28, 28),
        ),
      ),
    );
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
