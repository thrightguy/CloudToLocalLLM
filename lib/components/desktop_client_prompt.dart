import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/desktop_client_detection_service.dart';

/// Prominent banner component that appears when no desktop client is connected
///
/// This component monitors the desktop client detection service and displays
/// a helpful prompt to guide users to download the desktop client when needed.
class DesktopClientPrompt extends StatelessWidget {
  final bool showCompact;
  final VoidCallback? onDismiss;

  const DesktopClientPrompt({
    super.key,
    this.showCompact = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return Consumer<DesktopClientDetectionService>(
      builder: (context, clientDetection, child) {
        // Don't show if clients are connected or if there's an error
        if (clientDetection.hasConnectedClients ||
            clientDetection.error != null) {
          return const SizedBox.shrink();
        }

        // Show different UI based on compact mode
        if (showCompact) {
          return _buildCompactPrompt(context, clientDetection);
        } else {
          return _buildFullPrompt(context, clientDetection);
        }
      },
    );
  }

  Widget _buildFullPrompt(
    BuildContext context,
    DesktopClientDetectionService clientDetection,
  ) {
    return Container(
      margin: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.secondaryColor.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            // Header with icon and title
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                  ),
                  child: Icon(
                    Icons.desktop_windows,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Desktop Client Detected',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingXS),
                      Text(
                        'Connect your local Ollama instance to this web interface',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    color: AppTheme.textColorLight,
                    tooltip: 'Dismiss',
                  ),
              ],
            ),
            SizedBox(height: AppTheme.spacingM),

            // Description
            Container(
              padding: EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'To use your local Ollama models with this web interface, you need to install and run the CloudToLocalLLM desktop client. It creates a secure tunnel between your local Ollama instance and this web app.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppTheme.spacingM),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.go('/settings/downloads');
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download Desktop Client'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.all(AppTheme.spacingM),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/settings');
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('View Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: EdgeInsets.all(AppTheme.spacingM),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPrompt(
    BuildContext context,
    DesktopClientDetectionService clientDetection,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Icon(Icons.desktop_windows, color: AppTheme.primaryColor, size: 24),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No Desktop Client Connected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Download the desktop client to connect your local Ollama',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textColor),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppTheme.spacingM),
            ElevatedButton(
              onPressed: () {
                context.go('/settings/downloads');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                ),
              ),
              child: const Text('Download'),
            ),
            if (onDismiss != null) ...[
              SizedBox(width: AppTheme.spacingS),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                color: AppTheme.textColorLight,
                iconSize: 20,
                tooltip: 'Dismiss',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A dismissible version of the desktop client prompt
///
/// This wrapper adds dismiss functionality with local state management.
class DismissibleDesktopClientPrompt extends StatefulWidget {
  final bool showCompact;

  const DismissibleDesktopClientPrompt({super.key, this.showCompact = false});

  @override
  State<DismissibleDesktopClientPrompt> createState() =>
      _DismissibleDesktopClientPromptState();
}

class _DismissibleDesktopClientPromptState
    extends State<DismissibleDesktopClientPrompt> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    return DesktopClientPrompt(
      showCompact: widget.showCompact,
      onDismiss: () {
        setState(() {
          _isDismissed = true;
        });
      },
    );
  }
}
