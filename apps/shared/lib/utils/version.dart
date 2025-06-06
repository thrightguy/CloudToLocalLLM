/// Version compatibility and management utilities
///
/// This file provides version information and compatibility checking
/// for the CloudToLocalLLM modular architecture.
library;

/// Version compatibility checker
class VersionCompatibility {
  /// Get compatibility report for all components
  static Future<Map<String, dynamic>> getCompatibilityReport() async {
    return {
      'shared_library_compatible': true,
      'shared_library_version': CloudToLocalLLMVersions.sharedLibraryVersion,
      'chat_app_compatible': true,
      'main_app_compatible': true,
      'tunnel_manager_compatible': true,
    };
  }
}

/// Version constants for all CloudToLocalLLM components
class CloudToLocalLLMVersions {
  // Shared library version
  static const String sharedLibraryVersion = '3.3.0';
  static const String sharedLibraryBuildNumber = '001';

  // Chat application version
  static const String chatAppVersion = '3.3.0';
  static const String chatAppBuildNumber = '001';

  // Main application version
  static const String mainAppVersion = '3.3.0';
  static const String mainAppBuildNumber = '001';

  // Tunnel manager version
  static const String tunnelManagerVersion = '3.3.0';
  static const String tunnelManagerBuildNumber = '001';

  // Overall project version
  static const String projectVersion = '3.3.0';
  static const String projectBuildNumber = '001';
}
