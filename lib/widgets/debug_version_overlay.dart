import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/version_service.dart';
import '../services/auth_service.dart';
import '../services/tunnel_manager_service.dart';

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

    // Authentication-based visibility
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final shouldShow = _shouldShowDebugOverlay(authService);

        if (!shouldShow) {
          return widget.child;
        }

        return Stack(
          children: [
            // Main app content
            widget.child,

            // Debug overlay with responsive positioning
            Positioned(
              left: 12.0,
              bottom: 12.0,
              child: SafeArea(child: _buildDebugDisplay(context)),
            ),
          ],
        );
      },
    );
  }

  /// Determine if debug overlay should be shown based on authentication and platform
  bool _shouldShowDebugOverlay(AuthService authService) {
    if (kIsWeb) {
      // On web: show for logged-in users, hide for anonymous visitors
      return authService.isAuthenticated.value;
    } else {
      // On desktop: always show for development
      return true;
    }
  }

  /// Build the debug display widget with version information
  Widget _buildDebugDisplay(BuildContext context) {
    // Calculate responsive dimensions based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Ensure overlay doesn't exceed screen boundaries
    final maxCompactWidth = (screenWidth * 0.4).clamp(200.0, 300.0);
    final maxExpandedWidth = (screenWidth * 0.5).clamp(280.0, 400.0);
    final maxExpandedHeight = (screenHeight * 0.2).clamp(120.0, 180.0);

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        constraints: BoxConstraints(
          minWidth: 180.0,
          maxWidth: _isExpanded ? maxExpandedWidth : maxCompactWidth,
          minHeight: 36.0,
          maxHeight: _isExpanded ? maxExpandedHeight : 50.0,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
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
          width: 12.0,
          height: 12.0,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        Text(
          'Loading version...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
            letterSpacing: 0.3,
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
        // Version info icon
        Icon(
          Icons.info_outline,
          size: 14.0,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6.0),

        // Version text with flexible layout
        Flexible(
          child: Text(
            _versionText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ),

        const SizedBox(width: 8.0),

        // Connection status indicator with tooltip
        Consumer<TunnelManagerService>(
          builder: (context, tunnelService, child) {
            final isConnected = tunnelService.isConnected;
            return Tooltip(
              message: isConnected ? 'Connected' : 'Disconnected',
              child: Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build expanded debug info with detailed version and connection information
  Widget _buildExpandedDebugInfo(BuildContext context) {
    // Extract version and build number for better display
    final versionParts = _versionText.split('+');
    final version = versionParts.isNotEmpty ? versionParts[0] : _versionText;
    final buildNumber = versionParts.length > 1 ? versionParts[1] : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Version row with flexible layout
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14.0,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6.0),
            Flexible(
              child: Text(
                version,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6.0),

        // Build information with proper spacing
        Row(
          children: [
            Icon(
              Icons.build_outlined,
              size: 12.0,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6.0),
            Flexible(
              child: Text(
                'Build: $buildNumber',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10.0,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6.0),

        // Connection status with enhanced display
        Consumer<TunnelManagerService>(
          builder: (context, tunnelService, child) {
            final isConnected = tunnelService.isConnected;
            final statusText = isConnected ? 'Connected' : 'Disconnected';
            final statusColor = isConnected ? Colors.green : Colors.red;

            return Row(
              children: [
                Icon(
                  isConnected ? Icons.link : Icons.link_off,
                  size: 12.0,
                  color: statusColor,
                ),
                const SizedBox(width: 6.0),
                Flexible(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor.withValues(alpha: 0.9),
                      fontSize: 10.0,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(width: 4.0),
                Container(
                  width: 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
              ],
            );
          },
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
