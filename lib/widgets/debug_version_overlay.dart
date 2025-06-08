import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/version_service.dart';

/// TEMPORARY: Debug version overlay for v3.3.1 beta testing
/// 
/// This widget displays the current version number in the bottom-left corner
/// of all screens throughout the Flutter application. It's designed to help
/// verify that the correct version is deployed across all environments during
/// the v3.3.1 testing phase.
/// 
/// Features:
/// - Fixed position overlay in bottom-left corner
/// - Reads version from VersionService (assets/version.json or pubspec.yaml)
/// - Semi-transparent styling that doesn't interfere with UI
/// - Displays on all screens/routes
/// - Easy to disable with AppConfig.showDebugVersionOverlay flag
/// 
/// TODO: Remove this widget after v3.3.1 testing phase is complete
class DebugVersionOverlay extends StatefulWidget {
  /// The child widget to wrap with the version overlay
  final Widget child;

  const DebugVersionOverlay({
    super.key,
    required this.child,
  });

  @override
  State<DebugVersionOverlay> createState() => _DebugVersionOverlayState();
}

class _DebugVersionOverlayState extends State<DebugVersionOverlay> {
  String _versionText = '';
  bool _isLoading = true;

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
        
        // Version overlay in bottom-left corner
        Positioned(
          left: 8.0,
          bottom: 8.0,
          child: _buildVersionDisplay(context),
        ),
      ],
    );
  }

  /// Build the version display widget
  Widget _buildVersionDisplay(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: _isLoading
          ? _buildLoadingIndicator()
          : _buildVersionText(context),
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

  /// Build the version text display
  Widget _buildVersionText(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Version icon
        Icon(
          Icons.info_outline,
          size: 10.0,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4.0),
        
        // Version text
        Text(
          _versionText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 10.0,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
        
        // Beta indicator for v3.3.1
        if (_versionText.startsWith('v3.3.1')) ...[
          const SizedBox(width: 4.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2.0),
            ),
            child: Text(
              'BETA',
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

  const DebugVersionWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DebugVersionOverlay(child: child);
  }
}
