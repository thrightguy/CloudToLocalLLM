class User {
  final String id;
  final String email;
  final String? name;
  final String? pictureUrl;
  final bool isAuthenticated;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    this.name,
    this.pictureUrl,
    this.isAuthenticated = false,
    this.metadata,
    DateTime? createdAt,
    this.lastLogin,
  }) : createdAt = createdAt ?? DateTime.now();

  // Create a copy of this user with updated fields
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? pictureUrl,
    bool? isAuthenticated,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  // Convert user to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'pictureUrl': pictureUrl,
      'isAuthenticated': isAuthenticated,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  // Create user from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      pictureUrl: json['pictureUrl'],
      isAuthenticated: json['isAuthenticated'] ?? false,
      metadata: json['metadata'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
    );
  }

  // Create an anonymous user
  factory User.anonymous() {
    return User(
      id: 'anonymous',
      email: 'anonymous@local',
      name: 'Anonymous User',
      isAuthenticated: false,
    );
  }

  // Check if user is anonymous
  bool get isAnonymous => id == 'anonymous';
}