import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/version_service.dart';

/// Debug version overlay for CloudToLocalLLM
///
/// This widget displays the current version number in the bottom-left corner
/// of all screens throughout the Flutter application. It's designed to help
/// verify that the correct version is deployed across all environments.
///
/// Features:
/// - Fixed position overlay in bottom-left corner
/// - Reads version from VersionService (assets/version.json or pubspec.yaml)
/// - Semi-transparent styling that doesn't interfere with UI
/// - Displays on all screens/routes
/// - Easy to disable with AppConfig.showDebugVersionOverlay flag
///
/// TODO: Remove this widget after v3.5.1 testing phase is complete
class DebugVersionOverlay extends StatefulWidget {
  /// The child widget to wrap with the version overlay
  final Widget child;

  const DebugVersionOverlay({super.key, required this.child});

  @override
  State<DebugVersionOverlay> createState() => _DebugVersionOverlayState();
}

class _DebugVersionOverlayState extends State<DebugVersionOverlay> {
  String _versionText = '';
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  /// Load version information from VersionService
  Future<void> _loadVersionInfo() async {
    try {
      final versionService = VersionService.instance;
      final version = await versionService.getVersion();
      final buildNumber = await versionService.getBuildNumber();

      if (mounted) {
        setState(() {
          _versionText = 'v$version+$buildNumber';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DebugVersionOverlay] Failed to load version: $e');
      if (mounted) {
        setState(() {
          _versionText = 'v?.?.?';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show overlay if disabled in config
    if (!AppConfig.showDebugVersionOverlay) {
      return widget.child;
    }

    return Stack(
      children: [
        // Main app content
        widget.child,

        // Debug overlay in bottom-left corner
        Positioned(left: 8.0, bottom: 8.0, child: _buildDebugDisplay(context)),
      ],
    );
  }

  /// Build the debug display widget with version information
  Widget _buildDebugDisplay(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        constraints: BoxConstraints(
          maxWidth: _isExpanded ? 250 : 150,
          maxHeight: _isExpanded ? 100 : 40,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: _isLoading
            ? _buildLoadingIndicator()
            : _isExpanded
            ? _buildExpandedDebugInfo(context)
            : _buildCompactDebugInfo(context),
      ),
    );
  }

  /// Build loading indicator while version is being loaded
  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 8.0,
          height: 8.0,
          child: CircularProgressIndicator(
            strokeWidth: 1.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 4.0),
        Text(
          'Loading...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10.0,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// Build compact debug info (version only)
  Widget _buildCompactDebugInfo(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Version info
        Icon(
          Icons.info_outline,
          size: 12.0,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4.0),
        Text(
          _versionText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),

        // Version indicator for v3.5.2
        if (_versionText.startsWith('v3.5.2')) ...[
          const SizedBox(width: 4.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2.0),
            ),
            child: Text(
              'v3.5.2',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build expanded debug info with detailed version information
  Widget _buildExpandedDebugInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Version row
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 12.0,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4.0),
            Text(
              _versionText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
            if (_versionText.startsWith('v3.5.2')) ...[
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 3.0,
                  vertical: 1.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: Text(
                  'v3.5.2',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 6.0),

        // Build information
        Text(
          'Build: ${_versionText.split('+').length > 1 ? _versionText.split('+')[1] : 'N/A'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 9.0,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// Convenience widget for wrapping the entire app with debug version overlay
///
/// Usage:
/// ```dart
/// return DebugVersionWrapper(
///   child: MaterialApp.router(...),
/// );
/// ```
class DebugVersionWrapper extends StatelessWidget {
  final Widget child;

  const DebugVersionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DebugVersionOverlay(child: child);
  }
}
