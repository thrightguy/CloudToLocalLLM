/// User model for the application
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? picture;
  final String? nickname;
  final DateTime? emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.picture,
    this.nickname,
    this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create UserModel from Auth0 profile
  factory UserModel.fromAuth0Profile(dynamic profile) {
    // Handle both UserProfile object and Map<String, dynamic>
    final Map<String, dynamic> profileData;
    if (profile is Map<String, dynamic>) {
      profileData = profile;
    } else {
      // Convert UserProfile object to map
      profileData = {
        'sub': profile.sub,
        'email': profile.email,
        'name': profile.name,
        'picture': profile.picture,
        'nickname': profile.nickname,
        'email_verified': profile.emailVerified,
        'created_at': profile.createdAt?.toIso8601String(),
        'updated_at': profile.updatedAt?.toIso8601String(),
      };
    }

    return UserModel(
      id: profileData['sub'] ?? '',
      email: profileData['email'] ?? '',
      name: profileData['name'],
      picture: profileData['picture'],
      nickname: profileData['nickname'],
      emailVerified: profileData['email_verified'] == true
          ? DateTime.tryParse(profileData['updated_at'] ?? '')
          : null,
      createdAt:
          DateTime.tryParse(profileData['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(profileData['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'],
      picture: json['picture'],
      nickname: json['nickname'],
      emailVerified: json['emailVerified'] != null
          ? DateTime.tryParse(json['emailVerified'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'picture': picture,
      'nickname': nickname,
      'emailVerified': emailVerified?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get display name (prioritize name, then nickname, then email)
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    return email;
  }

  /// Get initials for avatar
  String get initials {
    final displayNameValue = displayName;
    if (displayNameValue.isEmpty) return '?';

    final parts = displayNameValue.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayNameValue[0].toUpperCase();
  }

  /// Check if email is verified
  bool get isEmailVerified => emailVerified != null;

  /// Copy with method for immutable updates
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? picture,
    String? nickname,
    DateTime? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      nickname: nickname ?? this.nickname,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, nickname: $nickname)';
  }
}
