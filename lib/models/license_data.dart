/// Model representing license data from the server
class LicenseData {
  /// Unique ID for this license
  final String id;

  /// Customer ID associated with this license
  final String customerId;

  /// License key (hashed)
  final String licenseKeyHash;

  /// License tier (free, developer, professional, enterprise)
  final String tier;

  /// License status (active, expired, revoked)
  final String status;

  /// License expiration date
  final DateTime expiryDate;

  /// Features allowed by this license
  final List<String> features;

  /// Maximum number of containers allowed
  final int maxContainers;

  /// Maximum number of devices allowed
  final int maxDevices;

  /// License creation date
  final DateTime createdAt;

  LicenseData({
    required this.id,
    required this.customerId,
    required this.licenseKeyHash,
    required this.tier,
    required this.status,
    required this.expiryDate,
    required this.features,
    required this.maxContainers,
    required this.maxDevices,
    required this.createdAt,
  });

  /// Create a LicenseData from JSON
  factory LicenseData.fromJson(Map<String, dynamic> json) {
    return LicenseData(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      licenseKeyHash: json['licenseKeyHash'] as String,
      tier: json['tier'] as String,
      status: json['status'] as String,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      features: List<String>.from(json['features'] as List),
      maxContainers: json['maxContainers'] as int,
      maxDevices: json['maxDevices'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'licenseKeyHash': licenseKeyHash,
      'tier': tier,
      'status': status,
      'expiryDate': expiryDate.toIso8601String(),
      'features': features,
      'maxContainers': maxContainers,
      'maxDevices': maxDevices,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Check if the license is active
  bool get isActive => status == 'active' && expiryDate.isAfter(DateTime.now());

  /// Check if a feature is allowed
  bool hasFeature(String featureKey) => features.contains(featureKey);
}
