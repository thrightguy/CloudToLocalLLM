import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

/// Service for managing application version information
/// Provides unified access to version data across the application
class VersionService {
  static VersionService? _instance;
  static VersionService get instance => _instance ??= VersionService._();

  VersionService._();

  // Cached version information
  String? _version;
  String? _buildNumber;
  String? _fullVersion;
  DateTime? _buildDate;

  /// Get the semantic version (MAJOR.MINOR.PATCH)
  Future<String> getVersion() async {
    if (_version != null) return _version!;

    await _loadVersionInfo();
    return _version ?? 'Unknown';
  }

  /// Get the build number
  Future<String> getBuildNumber() async {
    if (_buildNumber != null) return _buildNumber!;

    await _loadVersionInfo();
    return _buildNumber ?? 'Unknown';
  }

  /// Get the full version string (MAJOR.MINOR.PATCH+BUILD)
  Future<String> getFullVersion() async {
    if (_fullVersion != null) return _fullVersion!;

    await _loadVersionInfo();
    return _fullVersion ?? 'Unknown';
  }

  /// Get the build date (parsed from build number if timestamp format)
  Future<DateTime?> getBuildDate() async {
    if (_buildDate != null) return _buildDate;

    await _loadVersionInfo();
    return _buildDate;
  }

  /// Get formatted version string for display
  Future<String> getDisplayVersion() async {
    final version = await getVersion();
    final buildNumber = await getBuildNumber();
    return 'v$version (Build $buildNumber)';
  }

  /// Get version information for support/debugging
  Future<Map<String, String>> getVersionInfo() async {
    final version = await getVersion();
    final buildNumber = await getBuildNumber();
    final fullVersion = await getFullVersion();
    final buildDate = await getBuildDate();

    return {
      'version': version,
      'buildNumber': buildNumber,
      'fullVersion': fullVersion,
      'buildDate': buildDate?.toIso8601String() ?? 'Unknown',
      'platform': defaultTargetPlatform.name,
      'debugMode': kDebugMode.toString(),
    };
  }

  /// Load version information from multiple sources
  Future<void> _loadVersionInfo() async {
    try {
      // Try to load from package_info_plus first (most reliable)
      await _loadFromPackageInfo();
    } catch (e) {
      debugPrint('[VersionService] Could not load from package_info: $e');
      try {
        // Try to load from version.json asset (generated during build)
        await _loadFromAsset();
      } catch (e2) {
        debugPrint('[VersionService] Could not load from asset: $e2');
        // Fallback to pubspec.yaml parsing (development mode)
        await _loadFromPubspec();
      }
    }
  }

  /// Load version from package_info_plus (most reliable method)
  Future<void> _loadFromPackageInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber.isNotEmpty
          ? packageInfo.buildNumber
          : 'Unknown';

      if (_version != null && _buildNumber != null) {
        _fullVersion = '$_version+$_buildNumber';
        _buildDate = _parseBuildDate(_buildNumber!);

        debugPrint(
            '[VersionService] Loaded version from package_info: $_fullVersion');
        return;
      }
    } catch (e) {
      debugPrint('[VersionService] Failed to load from package_info: $e');
      rethrow;
    }
  }

  /// Load version from version.json asset (production builds)
  Future<void> _loadFromAsset() async {
    try {
      final String versionJson =
          await rootBundle.loadString('assets/version.json');
      final Map<String, dynamic> versionData = json.decode(versionJson);

      _version = versionData['version']?.toString();
      _buildNumber = versionData['build_number']?.toString();

      if (_version != null && _buildNumber != null) {
        _fullVersion = '$_version+$_buildNumber';
        _buildDate = _parseBuildDate(_buildNumber!);

        debugPrint('[VersionService] Loaded version from asset: $_fullVersion');
        return;
      }
    } catch (e) {
      debugPrint('[VersionService] Failed to load from asset: $e');
      rethrow;
    }
  }

  /// Load version from pubspec.yaml (development mode)
  Future<void> _loadFromPubspec() async {
    try {
      // In development, we can't easily read pubspec.yaml from Flutter
      // So we'll use compile-time constants or fallback values

      // These should be updated by the build process
      const String compiledVersion =
          '2.0.0'; // Will be replaced by build script
      const String compiledBuildNumber =
          '202506011'; // Will be replaced by build script

      _version = compiledVersion;
      _buildNumber = compiledBuildNumber;
      _fullVersion = '$_version+$_buildNumber';
      _buildDate = _parseBuildDate(_buildNumber!);

      debugPrint('[VersionService] Using compiled version: $_fullVersion');
    } catch (e) {
      debugPrint('[VersionService] Failed to load version info: $e');

      // Ultimate fallback
      _version = 'Unknown';
      _buildNumber = 'Unknown';
      _fullVersion = 'Unknown';
      _buildDate = null;
    }
  }

  /// Parse build date from build number if it's in timestamp format
  DateTime? _parseBuildDate(String buildNumber) {
    try {
      // Check if build number is in format YYYYMMDDHHMM
      if (buildNumber.length == 12 &&
          RegExp(r'^\d{12}$').hasMatch(buildNumber)) {
        final year = int.parse(buildNumber.substring(0, 4));
        final month = int.parse(buildNumber.substring(4, 6));
        final day = int.parse(buildNumber.substring(6, 8));
        final hour = int.parse(buildNumber.substring(8, 10));
        final minute = int.parse(buildNumber.substring(10, 12));

        return DateTime(year, month, day, hour, minute);
      }
    } catch (e) {
      debugPrint('[VersionService] Could not parse build date: $e');
    }

    return null;
  }

  /// Clear cached version information (for testing)
  void clearCache() {
    _version = null;
    _buildNumber = null;
    _fullVersion = null;
    _buildDate = null;
  }

  /// Check if this is a development build
  Future<bool> isDevelopmentBuild() async {
    final buildNumber = await getBuildNumber();
    return buildNumber == 'Unknown' || kDebugMode;
  }

  /// Get user-friendly version string for about dialogs
  Future<String> getAboutVersion() async {
    final version = await getVersion();
    final buildDate = await getBuildDate();

    if (buildDate != null) {
      final formattedDate =
          '${buildDate.day}/${buildDate.month}/${buildDate.year}';
      return 'Version $version\nBuilt on $formattedDate';
    } else {
      final buildNumber = await getBuildNumber();
      return 'Version $version\nBuild $buildNumber';
    }
  }

  /// Format version for package managers (semantic version only)
  Future<String> getPackageVersion() async {
    return await getVersion();
  }

  /// Format version for file names (with build number)
  Future<String> getFileVersion() async {
    final version = await getVersion();
    final buildNumber = await getBuildNumber();
    return '$version-$buildNumber';
  }
}

/// Extension methods for easy version access
extension VersionServiceExtension on VersionService {
  /// Quick access to display version
  Future<String> get displayVersion => getDisplayVersion();

  /// Quick access to package version
  Future<String> get packageVersion => getPackageVersion();

  /// Quick access to file version
  Future<String> get fileVersion => getFileVersion();
}
