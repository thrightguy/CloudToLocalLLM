import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/version_service.dart';
import '../services/tunnel_manager_service.dart';

/// BETA: Debug version overlay for v3.5.1 beta testing
///
/// This widget displays the current version number and tunnel status in the bottom-left corner
/// of all screens throughout the Flutter application. It's designed to help
/// verify that the correct version is deployed and tunnel functionality is working
/// across all environments during the v3.5.1 testing phase.
///
/// Features:
/// - Fixed position overlay in bottom-left corner
/// - Reads version from VersionService (assets/version.json or pubspec.yaml)
/// - Shows real-time tunnel connection status (Ollama/Cloud)
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
        Positioned(
          left: 8.0,
          bottom: 8.0,
          child: Consumer<TunnelManagerService>(
            builder: (context, tunnelManager, child) {
              return _buildDebugDisplay(context, tunnelManager);
            },
          ),
        ),
      ],
    );
  }

  /// Build the enhanced debug display widget with tunnel status
  Widget _buildDebugDisplay(
    BuildContext context,
    TunnelManagerService tunnelManager,
  ) {
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
          maxWidth: _isExpanded ? 300 : 200,
          maxHeight: _isExpanded ? 150 : 50,
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
            ? _buildExpandedDebugInfo(context, tunnelManager)
            : _buildCompactDebugInfo(context, tunnelManager),
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

  /// Build compact debug info (version + basic status)
  Widget _buildCompactDebugInfo(
    BuildContext context,
    TunnelManagerService tunnelManager,
  ) {
    final ollamaStatus = tunnelManager.connectionStatus['ollama'];
    final cloudStatus = tunnelManager.connectionStatus['cloud'];

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

        // Beta indicator for v3.5.1
        if (_versionText.startsWith('v3.5.1')) ...[
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

        // Connection status indicators
        const SizedBox(width: 8.0),
        _buildConnectionIndicator('O', ollamaStatus?.isConnected ?? false),
        const SizedBox(width: 2.0),
        _buildConnectionIndicator('C', cloudStatus?.isConnected ?? false),
      ],
    );
  }

  /// Build expanded debug info with detailed tunnel status
  Widget _buildExpandedDebugInfo(
    BuildContext context,
    TunnelManagerService tunnelManager,
  ) {
    final ollamaStatus = tunnelManager.connectionStatus['ollama'];
    final cloudStatus = tunnelManager.connectionStatus['cloud'];

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
            if (_versionText.startsWith('v3.5.1')) ...[
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 3.0,
                  vertical: 1.0,
                ),
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
        ),

        const SizedBox(height: 6.0),

        // Tunnel status
        _buildTunnelStatusRow('Ollama', ollamaStatus),
        const SizedBox(height: 2.0),
        _buildTunnelStatusRow('Cloud', cloudStatus),

        if (tunnelManager.error != null) ...[
          const SizedBox(height: 4.0),
          Text(
            'Error: ${tunnelManager.error}',
            style: TextStyle(
              color: Colors.red.withValues(alpha: 0.9),
              fontSize: 8.0,
              fontFamily: 'monospace',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// Build connection indicator dot
  Widget _buildConnectionIndicator(String label, bool isConnected) {
    return Container(
      width: 12.0,
      height: 12.0,
      decoration: BoxDecoration(
        color: isConnected ? Colors.green : Colors.red,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 6.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Build tunnel status row for expanded view
  Widget _buildTunnelStatusRow(String name, ConnectionStatus? status) {
    return Row(
      children: [
        _buildConnectionIndicator(name[0], status?.isConnected ?? false),
        const SizedBox(width: 4.0),
        Text(
          '$name: ${status?.isConnected == true ? 'OK' : 'ERR'}',
          style: TextStyle(
            color: status?.isConnected == true
                ? Colors.green.withValues(alpha: 0.9)
                : Colors.red.withValues(alpha: 0.9),
            fontSize: 9.0,
            fontFamily: 'monospace',
          ),
        ),
        if (status?.latency != null && status!.latency > 0) ...[
          const SizedBox(width: 4.0),
          Text(
            '${status.latency.toInt()}ms',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 8.0,
              fontFamily: 'monospace',
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

  const DebugVersionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DebugVersionOverlay(child: child);
  }
}
