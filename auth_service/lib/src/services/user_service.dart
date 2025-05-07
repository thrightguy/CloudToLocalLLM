import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import '../models/user.dart';
import '../models/role.dart';

class UserService {
  final Logger _logger = Logger('UserService');
  final Connection _db;

  UserService(this._db);

  /// Initialize database connection
  Future<void> initialize() async {
    try {
      await _createTablesIfNotExist();
      await _createDefaultAdmin();
      _logger.info('User service initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize user service: $e');
      rethrow;
    }
  }

  /// Create database tables if they don't exist
  Future<void> _createTablesIfNotExist() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        permissions TEXT[] NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        email TEXT UNIQUE,
        password_hash TEXT NOT NULL,
        name TEXT,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_login TIMESTAMP,
        is_active BOOLEAN NOT NULL DEFAULT TRUE
      )
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS user_roles (
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role_id TEXT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
        PRIMARY KEY (user_id, role_id)
      )
    ''');
  }

  /// Create default admin user if no users exist
  Future<void> _createDefaultAdmin() async {
    // Create default roles if they don't exist
    final adminRoleResult = await _db.execute(
      Sql.named('SELECT COUNT(*) FROM roles WHERE id = @id'),
      parameters: {'id': 'admin'},
    );
    final adminRoleExists = (adminRoleResult.first[0] as int) > 0;

    if (!adminRoleExists) {
      final adminRole = Role.admin();
      await _db.execute(
        Sql.named(
            'INSERT INTO roles (id, name, permissions, description) VALUES (@id, @name, @permissions, @description)'),
        parameters: {
          'id': adminRole.id,
          'name': adminRole.name,
          'permissions': adminRole.permissions,
          'description': adminRole.description,
        },
      );

      final userRole = Role.user();
      await _db.execute(
        Sql.named(
            'INSERT INTO roles (id, name, permissions, description) VALUES (@id, @name, @permissions, @description)'),
        parameters: {
          'id': userRole.id,
          'name': userRole.name,
          'permissions': userRole.permissions,
          'description': userRole.description,
        },
      );
    }

    // Check if any users exist
    final userCountResult = await _db.execute('SELECT COUNT(*) FROM users');
    final userCount = userCountResult.first[0] as int;

    // Create default admin if no users exist
    if (userCount == 0) {
      final userId = 'admin';
      await _db.execute(
        Sql.named(
            'INSERT INTO users (id, username, email, password_hash, name, created_at, is_active) VALUES (@id, @username, @email, @password_hash, @name, @created_at::timestamp, @is_active)'),
        parameters: {
          'id': userId,
          'username': 'admin',
          'email': 'admin@example.com',
          'password_hash': _hashPassword('admin'), // Change in production!
          'name': 'Administrator',
          'created_at': DateTime.now().toIso8601String(),
          'is_active': true,
        },
      );

      await _db.execute(
        Sql.named(
            'INSERT INTO user_roles (user_id, role_id) VALUES (@user_id, @role_id)'),
        parameters: {'user_id': userId, 'role_id': 'admin'},
      );

      _logger.info('Created default admin user');
    }
  }

  /// Register a new user
  Future<User?> registerUser(
      String username, String password, String? email, String? name) async {
    try {
      final existingUserResult = await _db.execute(
        Sql.named(
            'SELECT COUNT(*) FROM users WHERE username = @username OR (email = @email AND @email IS NOT NULL)'),
        parameters: {'username': username, 'email': email},
      );
      final existingUser = (existingUserResult.first[0] as int) > 0;

      if (existingUser) {
        _logger.warning('Username or email already exists: $username, $email');
        return null;
      }

      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      await _db.execute(
        Sql.named(
            'INSERT INTO users (id, username, email, password_hash, name, created_at, is_active) VALUES (@id, @username, @email, @password_hash, @name, @created_at::timestamp, @is_active)'),
        parameters: {
          'id': userId,
          'username': username,
          'email': email,
          'password_hash': _hashPassword(password),
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
          'is_active': true,
        },
      );

      await _db.execute(
        Sql.named(
            'INSERT INTO user_roles (user_id, role_id) VALUES (@user_id, @role_id)'),
        parameters: {'user_id': userId, 'role_id': 'user'},
      );

      return await getUserById(userId);
    } catch (e) {
      _logger.severe('Error registering user: $e');
      return null;
    }
  }

  /// Authenticate user with username/email and password
  Future<User?> authenticateUser(
      String usernameOrEmail, String password) async {
    try {
      final result = await _db.execute(
        Sql.named(
            'SELECT id, password_hash FROM users WHERE (username = @login OR email = @login) AND is_active = true'),
        parameters: {'login': usernameOrEmail},
      );

      if (result.isEmpty) {
        _logger.info('User not found or inactive: $usernameOrEmail');
        return null;
      }

      final userId = result.first[0] as String;
      final storedHash = result.first[1] as String;

      if (_verifyPassword(password, storedHash)) {
        await _db.execute(
          Sql.named(
              'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = @id'),
          parameters: {'id': userId},
        );

        return await getUserById(userId);
      }

      _logger.info('Invalid password for user: $usernameOrEmail');
      return null;
    } catch (e) {
      _logger.severe('Error authenticating user: $e');
      return null;
    }
  }

  /// Get user by ID with roles
  Future<User?> getUserById(String userId) async {
    try {
      final userResult = await _db.execute(
        Sql.named('SELECT * FROM users WHERE id = @id'),
        parameters: {'id': userId},
      );

      if (userResult.isEmpty) return null;

      final rolesResult = await _db.execute(
        Sql.named(
            'SELECT r.* FROM roles r JOIN user_roles ur ON r.id = ur.role_id WHERE ur.user_id = @user_id'),
        parameters: {'user_id': userId},
      );

      final roles = rolesResult.map((row) => Role.fromRow(row)).toList();
      return User.fromRow(userResult.first, roles: roles);
    } catch (e) {
      _logger.severe('Error getting user by ID: $e');
      return null;
    }
  }

  /// Get all users with their roles
  Future<List<User>> getUsers({int limit = 50, int offset = 0}) async {
    try {
      final userResult = await _db.execute(
          'SELECT * FROM users ORDER BY created_at DESC LIMIT @limit OFFSET @offset',
          parameters: {'limit': limit, 'offset': offset});

      final users = <User>[];
      for (final row in userResult) {
        final userId = row[0] as String;
        final rolesResult = await _db.execute('''
          SELECT r.* FROM roles r
          JOIN user_roles ur ON r.id = ur.role_id
          WHERE ur.user_id = @user_id
          ''', parameters: {'user_id': userId});

        final roles =
            rolesResult.map((roleRow) => Role.fromRow(roleRow)).toList();
        users.add(User.fromRow(row, roles: roles));
      }

      return users;
    } catch (e) {
      _logger.severe('Error getting users: $e');
      return [];
    }
  }

  /// Hash a password
  String _hashPassword(String password) {
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final saltedPassword = password + salt;
    final bytes = utf8.encode(saltedPassword);
    final hash = sha256.convert(bytes).toString();
    return '$hash:$salt';
  }

  /// Verify a password against a hash
  bool _verifyPassword(String password, String hash) {
    final parts = hash.split(':');
    if (parts.length != 2) return false;

    final storedHash = parts[0];
    final salt = parts[1];

    final saltedPassword = password + salt;
    final bytes = utf8.encode(saltedPassword);
    final computedHash = sha256.convert(bytes).toString();

    return storedHash == computedHash;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _db.close();
  }

  Future<User?> findUserById(String id) async {
    final result = await _db.execute(
      Sql.named('SELECT * FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return User.fromRow(result.first);
  }

  Future<User?> findUserByEmail(String email) async {
    final results = await _db.execute(
      Sql.named('SELECT * FROM users WHERE email = @email'),
      parameters: {'email': email},
    );
    if (results.isEmpty) return null;
    return User.fromRow(results.first);
  }

  Future<List<User>> getAllUsers() async {
    try {
      final results = await _db.execute('SELECT * FROM users');
      final users = <User>[];

      for (final row in results) {
        final userId = row[0] as String;
        final roles = await getUserRoles(userId);
        users.add(User.fromRow(row, roles: roles));
      }

      return users;
    } catch (e) {
      _logger.severe('Error getting all users: $e');
      return [];
    }
  }

  Future<User?> createUser(User user) async {
    try {
      // Start a transaction
      await _db.execute('BEGIN');

      // Insert user
      final result = await _db.execute(
        Sql.named(
            'INSERT INTO users (id, username, email, password_hash, name, created_at, is_active) VALUES (@id, @username, @email, @password_hash, @name, @created_at, @is_active) RETURNING *'),
        parameters: {
          'id': user.id,
          'username': user.username,
          'email': user.email,
          'password_hash': user.passwordHash,
          'name': user.name,
          'created_at': user.createdAt.toIso8601String(),
          'is_active': user.isActive,
        },
      );

      if (result.isEmpty) {
        await _db.execute('ROLLBACK');
        return null;
      }

      // Insert user roles
      for (final role in user.roles) {
        await _db.execute(
          Sql.named(
              'INSERT INTO user_roles (user_id, role_id) VALUES (@user_id, @role_id)'),
          parameters: {
            'user_id': user.id,
            'role_id': role.id,
          },
        );
      }

      // Commit transaction
      await _db.execute('COMMIT');

      // Return user with roles
      return User.fromRow(result.first, roles: user.roles);
    } catch (e) {
      await _db.execute('ROLLBACK');
      _logger.severe('Error creating user: $e');
      return null;
    }
  }

  Future<User?> updateUser(String id, Map<String, dynamic> updates) async {
    try {
      await _db.execute('BEGIN');

      // Handle role updates separately
      final List<Role>? newRoles = updates.remove('roles') as List<Role>?;

      if (updates.isNotEmpty) {
        final setClause = updates.keys.map((key) => '$key = @$key').join(', ');
        final query = 'UPDATE users SET $setClause WHERE id = @id RETURNING *';

        final values = {...updates, 'id': id};
        final result = await _db.execute(
          Sql.named(query),
          parameters: values,
        );

        if (result.isEmpty) {
          await _db.execute('ROLLBACK');
          return null;
        }
      }

      // Update roles if provided
      if (newRoles != null) {
        // Remove existing roles
        await _db.execute(
          Sql.named('DELETE FROM user_roles WHERE user_id = @user_id'),
          parameters: {'user_id': id},
        );

        // Add new roles
        for (final role in newRoles) {
          await _db.execute(
            Sql.named(
                'INSERT INTO user_roles (user_id, role_id) VALUES (@user_id, @role_id)'),
            parameters: {
              'user_id': id,
              'role_id': role.id,
            },
          );
        }
      }

      await _db.execute('COMMIT');

      // Get updated user with roles
      return await getUserById(id);
    } catch (e) {
      await _db.execute('ROLLBACK');
      _logger.severe('Error updating user: $e');
      return null;
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      final result = await _db.execute(
        Sql.named('DELETE FROM users WHERE id = @id'),
        parameters: {'id': id},
      );
      return result.affectedRows > 0;
    } catch (e) {
      _logger.severe('Error deleting user: $e');
      return false;
    }
  }

  Future<List<Role>> getUserRoles(String userId) async {
    try {
      final results = await _db.execute(
        Sql.named(
            'SELECT r.* FROM roles r INNER JOIN user_roles ur ON r.id = ur.role_id WHERE ur.user_id = @userId'),
        parameters: {'userId': userId},
      );

      return results.map((row) => Role.fromRow(row)).toList();
    } catch (e) {
      _logger.severe('Error getting user roles: $e');
      return [];
    }
  }

  Future<bool> addUserRole(String userId, String roleId) async {
    try {
      await _db.execute(
        Sql.named(
            'INSERT INTO user_roles (user_id, role_id) VALUES (@user_id, @role_id)'),
        parameters: {
          'user_id': userId,
          'role_id': roleId,
        },
      );
      return true;
    } catch (e) {
      _logger.severe('Error adding user role: $e');
      return false;
    }
  }

  Future<bool> removeUserRole(String userId, String roleId) async {
    try {
      final result = await _db.execute(
        Sql.named(
            'DELETE FROM user_roles WHERE user_id = @user_id AND role_id = @role_id'),
        parameters: {
          'user_id': userId,
          'role_id': roleId,
        },
      );
      return result.affectedRows > 0;
    } catch (e) {
      _logger.severe('Error removing user role: $e');
      return false;
    }
  }
}
