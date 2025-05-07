import 'package:postgres/postgres.dart';
import 'role.dart';

class User {
  final String id;
  final String email;
  final String passwordHash;
  final String name;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.name,
    required this.role,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  factory User.fromRow(PostgreSQLResultRow row) {
    return User(
      id: row[0] as String,
      email: row[1] as String,
      passwordHash: row[2] as String,
      name: row[3] as String,
      role: row[4] as String,
      createdAt: row[5] as DateTime,
      lastLogin: row[6] as DateTime?,
      isActive: row[7] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'name': name,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive,
    };
  }

  // Methods to check permissions
  bool hasRole(String roleName) {
    return role == roleName;
  }

  bool hasPermission(String permission) {
    // Implementation needed
    throw UnimplementedError();
  }

  bool get isAdmin => hasRole('admin');
}
