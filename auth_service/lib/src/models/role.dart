import 'package:postgres/postgres.dart';

class Role {
  final String id;
  final String name;
  final List<String> permissions;
  final String description;

  Role({
    required this.id,
    required this.name,
    required this.permissions,
    required this.description,
  });

  factory Role.fromRow(ResultRow row) {
    return Role(
      id: row[0] as String,
      name: row[1] as String,
      permissions: (row[2] as List).cast<String>(),
      description: row[3] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'permissions': permissions,
      'description': description,
    };
  }

  // Predefined roles
  static Role admin() {
    return Role(
      id: 'admin',
      name: 'Administrator',
      permissions: ['*'],
      description: 'Full system access',
    );
  }

  static Role user() {
    return Role(
      id: 'user',
      name: 'User',
      permissions: ['read'],
      description: 'Basic user access',
    );
  }
}

/// Note: For postgres >=3.0.0, use ResultRow instead of PostgreSQLResultRow for query results.
/// If you see errors about undefined 'PostgreSQLResultRow', update your factory constructors to use ResultRow.
