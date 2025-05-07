import 'package:postgres/postgres.dart';
import 'role.dart';

class User {
  final String id;
  final String username;
  final String? email;
  final String passwordHash;
  final String? name;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;
  final List<Role> roles;

  User({
    required this.id,
    required this.username,
    this.email,
    required this.passwordHash,
    this.name,
    required this.createdAt,
    this.lastLogin,
    required this.isActive,
    required this.roles,
  });

  /// Creates a User instance from a PostgreSQL row
  ///
  /// [row] should contain the following columns in order:
  /// - id (String)
  /// - username (String)
  /// - email (String?)
  /// - password_hash (String)
  /// - name (String?)
  /// - created_at (DateTime)
  /// - last_login (DateTime?)
  /// - is_active (bool)
  ///
  /// [roles] is a list of Role objects associated with the user
  factory User.fromRow(PostgreSQLResultRow row, {List<Role> roles = const []}) {
    return User(
      id: row[0] as String,
      username: row[1] as String,
      email: row[2] as String?,
      passwordHash: row[3] as String,
      name: row[4] as String?,
      createdAt: row[5] as DateTime,
      lastLogin: row[6] as DateTime?,
      isActive: row[7] as bool,
      roles: roles,
    );
  }

  /// Converts the user to a map for database operations
  /// Does not include roles as they are handled separately
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// Creates a copy of the user with updated fields
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    String? name,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
    List<Role>? roles,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      roles: roles ?? this.roles,
    );
  }

  // Methods to check permissions
  bool hasRole(String roleName) {
    return roles.any((role) => role.name == roleName);
  }

  bool hasPermission(String permission) {
    return roles.any((role) =>
        role.permissions.contains('*') ||
        role.permissions.contains(permission));
  }

  bool get isAdmin => hasRole('Administrator');
}
