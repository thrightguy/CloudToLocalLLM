import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';
import '../models/license_data.dart';

/// Service to handle license verification and management
class LicenseService {
  static const String _licenseKeyStorage = 'license_key';
  static const String _licenseDataStorage = 'license_data';
  static const String _licenseLastVerifiedStorage = 'license_last_verified';

  final FlutterSecureStorage _secureStorage;
  final http.Client _httpClient;
  LicenseData? _cachedLicenseData;

  LicenseService({
    required FlutterSecureStorage secureStorage,
    required http.Client httpClient,
  })  : _secureStorage = secureStorage,
        _httpClient = httpClient;

  /// Returns current license data, from cache if available
  Future<LicenseData?> getLicenseData() async {
    if (_cachedLicenseData != null) {
      return _cachedLicenseData;
    }

    final licenseDataJson = await _secureStorage.read(key: _licenseDataStorage);
    if (licenseDataJson != null) {
      try {
        _cachedLicenseData = LicenseData.fromJson(jsonDecode(licenseDataJson));
        return _cachedLicenseData;
      } catch (e) {
        debugPrint('Error parsing license data: $e');
      }
    }

    return null;
  }

  /// Set a license key
  Future<bool> setLicenseKey(String licenseKey) async {
    await _secureStorage.write(key: _licenseKeyStorage, value: licenseKey);

    // Try to verify the new license immediately
    return await verifyLicense(forceCheck: true);
  }

  /// Get current license key
  Future<String?> getLicenseKey() async {
    return await _secureStorage.read(key: _licenseKeyStorage);
  }

  /// Check if license needs verification
  Future<bool> needsVerification() async {
    final lastVerifiedStr =
        await _secureStorage.read(key: _licenseLastVerifiedStorage);
    if (lastVerifiedStr == null) {
      return true;
    }

    final lastVerified = DateTime.parse(lastVerifiedStr);
    final now = DateTime.now();

    // Verify daily
    return now.difference(lastVerified).inDays >= 1;
  }

  /// Generate a unique device fingerprint
  Future<String> _generateDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceData = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData =
            '${androidInfo.id}_${androidInfo.device}_${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData =
            '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.systemName}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceData = '${windowsInfo.computerName}_${windowsInfo.deviceId}';
      } else if (Platform.isMacOS) {
        final macOsInfo = await deviceInfo.macOsInfo;
        deviceData = '${macOsInfo.computerName}_${macOsInfo.model}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceData = '${linuxInfo.machineId}_${linuxInfo.version}';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    // Add a salt and hash the device data
    final bytes = utf8.encode('${deviceData}_CloudToLocalLLM_Salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if cached license is valid
  Future<bool> _checkCachedLicense() async {
    final licenseData = await getLicenseData();
    if (licenseData == null) {
      return false;
    }

    // Check if license has expired
    final now = DateTime.now();
    return licenseData.expiryDate.isAfter(now);
  }

  /// Verify the digital signature of the license data
  bool _verifySignature(Map<String, dynamic> data) {
    try {
      final signature = data['signature'];
      // Remove signature field for verification
      final Map<String, dynamic> dataToVerify = Map.from(data);
      dataToVerify.remove('signature');

      // In a real app, this would use proper RSA or ECDSA signature verification
      // For this example, we'll just check if signature exists
      return signature != null && signature.isNotEmpty;
    } catch (e) {
      debugPrint('Error verifying signature: $e');
      return false;
    }
  }

  /// Collect anonymous usage metrics for license verification
  Map<String, dynamic> _collectAnonymousMetrics() {
    return {
      'lastUsed': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
    };
  }

  /// Verify license with the server
  Future<bool> verifyLicense({bool forceCheck = false}) async {
    // Skip verification if not needed and not forced
    if (!forceCheck && !(await needsVerification())) {
      return await _checkCachedLicense();
    }

    final licenseKey = await getLicenseKey();
    if (licenseKey == null || licenseKey.isEmpty) {
      return false;
    }

    final deviceId = await _generateDeviceFingerprint();
    final packageInfo = await PackageInfo.fromPlatform();

    try {
      final response = await _httpClient.post(
        Uri.parse('${AppConfig.apiBaseUrl}/license/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'licenseKey': licenseKey,
          'deviceId': deviceId,
          'appVersion': packageInfo.version,
          'usageMetrics': _collectAnonymousMetrics(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (_verifySignature(data)) {
          final licenseData = LicenseData.fromJson(data);
          _cachedLicenseData = licenseData;

          // Store the license data and verification time
          await _secureStorage.write(
            key: _licenseDataStorage,
            value: jsonEncode(data),
          );
          await _secureStorage.write(
            key: _licenseLastVerifiedStorage,
            value: DateTime.now().toIso8601String(),
          );

          return true;
        }
      }

      // License verification failed
      debugPrint('License verification failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Error during license verification: $e');

      // If offline, use cached license
      return await _checkCachedLicense();
    }
  }

  /// Check if a specific feature is allowed with current license
  Future<bool> isFeatureAllowed(String featureKey) async {
    final licenseData = await getLicenseData();
    if (licenseData == null) {
      return false;
    }

    // Check if license is valid
    if (licenseData.expiryDate.isBefore(DateTime.now())) {
      return false;
    }

    // Check if feature is included in the allowed features
    return licenseData.features.contains(featureKey);
  }

  /// Get max containers allowed by the license
  Future<int> getMaxContainers() async {
    final licenseData = await getLicenseData();
    if (licenseData == null) {
      return 1; // Default to 1 container for free/invalid licenses
    }

    return licenseData.maxContainers;
  }

  /// Get license tier (free, developer, professional, enterprise)
  Future<String> getLicenseTier() async {
    final licenseData = await getLicenseData();
    if (licenseData == null) {
      return 'free';
    }

    return licenseData.tier;
  }

  /// Clean up resources
  void dispose() {
    _httpClient.close();
  }
}
