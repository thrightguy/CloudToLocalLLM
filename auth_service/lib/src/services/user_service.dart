import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:postgresql2/postgresql.dart';
import 'package:postgres/postgres.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../config/environment.dart';

class UserService {
  final Logger _logger = Logger('UserService');
  final PostgreSQLConnection _db;

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
        description TEXT
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
    final adminRoleExists = await _db.query(
        'SELECT COUNT(*) FROM roles WHERE id = @id',
        {'id': 'admin'}).then((result) => result.first[0] > 0);

    if (!adminRoleExists) {
      final adminRole = Role.admin();
      await _db.execute(
          'INSERT INTO roles (id, name, permissions, description) VALUES (@id, @name, @permissions, @description)',
          {
            'id': adminRole.id,
            'name': adminRole.name,
            'permissions': adminRole.permissions,
            'description': adminRole.description,
          });

      final userRole = Role.user();
      await _db.execute(
          'INSERT INTO roles (id, name, permissions, description) VALUES (@id, @name, @permissions, @description)',
          {
            'id': userRole.id,
            'name': userRole.name,
            'permissions': userRole.permissions,
            'description': userRole.description,
          });
    }

    // Check if any users exist
    final userCount = await _db
        .query('SELECT COUNT(*) FROM users')
        .then((result) => result.first[0] as int);

    // Create default admin if no users exist
    if (userCount == 0) {
      final adminUser = {
        'id': 'admin',
        'username': 'admin',
        'email': 'admin@example.com',
        'password_hash': _hashPassword('admin'), // Change in production!
        'name': 'Administrator',
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      };

      await _db.execute('''
        INSERT INTO users (id, username, email, password_hash, name, created_at, is_active) 
        VALUES (@id, @username, @email, @password_hash, @name, @created_at::timestamp, @is_active)
      ''', adminUser);

      await _db.execute(
          'INSERT INTO user_roles (user_id, role_id) VALUES (@user_id, @role_id)',
          {'user_id': 'admin', 'role_id': 'admin'});

      _logger.info('Created default admin user');
    }
  }

  /// Register a new user
  Future<User?> registerUser(
      String username, String password, String? email, String? name) async {
    try {
      // Check if username or email already exists
      final existingUser = await _db.query(
          'SELECT COUNT(*) FROM users WHERE username = @username OR (email = @email AND @email IS NOT NULL)',
          {
            'username': username,
            'email': email
          }).then((result) => result.first[0] > 0);

      if (existingUser) {
        _logger.warning('Username or email already exists: $username, $email');
        return null;
      }

      // Create new user
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final user = {
        'id': userId,
        'username': username,
        'email': email,
        'password_hash': _hashPassword(password),
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      };

      await _db.execute('''
        INSERT INTO users (id, username, email, password_hash, name, created_at, is_active) 
        VALUES (@id, @username, @email, @password_hash, @name, @created_at::timestamp, @is_active)
      ''', user);

      // Assign default user role
      await _db.execute(
          'INSERT INTO user_roles (user_id, role_id) VALUES (@user_id, @role_id)',
          {'user_id': userId, 'role_id': 'user'});

      // Return the created user
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
      // Find user by username or email
      final result = await _db.query(
          'SELECT id, password_hash FROM users WHERE (username = @login OR email = @login) AND is_active = true',
          {'login': usernameOrEmail});

      if (result.isEmpty) {
        _logger.info('User not found or inactive: $usernameOrEmail');
        return null;
      }

      final userId = result.first[0] as String;
      final storedHash = result.first[1] as String;

      // Verify password
      if (_verifyPassword(password, storedHash)) {
        // Update last login time
        await _db.execute(
            'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = @id',
            {'id': userId});

        // Return the authenticated user
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
      // Get user data
      final userResult =
          await _db.query('SELECT * FROM users WHERE id = @id', {'id': userId});

      if (userResult.isEmpty) {
        return null;
      }

      final userData = userResult.first;

      // Get user roles
      final rolesResult = await _db.query('''
        SELECT r.* FROM roles r
        JOIN user_roles ur ON r.id = ur.role_id
        WHERE ur.user_id = @user_id
      ''', {'user_id': userId});

      final roles = rolesResult
          .map((roleRow) => Role(
                id: roleRow[0] as String,
                name: roleRow[1] as String,
                permissions: (roleRow[2] as List).cast<String>(),
                description: roleRow[3] as String?,
              ))
          .toList();

      return User(
        id: userData[0] as String,
        username: userData[1] as String,
        email: userData[2] as String?,
        passwordHash: userData[3] as String,
        name: userData[4] as String?,
        createdAt: userData[5] as DateTime,
        lastLogin: userData[6] as DateTime?,
        isActive: userData[7] as bool,
        roles: roles,
      );
    } catch (e) {
      _logger.severe('Error getting user by ID: $e');
      return null;
    }
  }

  /// Get all users (with pagination)
  Future<List<User>> getUsers({int limit = 50, int offset = 0}) async {
    try {
      // Get users with pagination
      final userResult = await _db.query(
          'SELECT * FROM users ORDER BY created_at DESC LIMIT @limit OFFSET @offset',
          {'limit': limit, 'offset': offset});

      final users = <User>[];

      for (final userData in userResult) {
        // Get user roles
        final userId = userData[0] as String;
        final rolesResult = await _db.query('''
          SELECT r.* FROM roles r
          JOIN user_roles ur ON r.id = ur.role_id
          WHERE ur.user_id = @user_id
        ''', {'user_id': userId});

        final roles = rolesResult
            .map((roleRow) => Role(
                  id: roleRow[0] as String,
                  name: roleRow[1] as String,
                  permissions: (roleRow[2] as List).cast<String>(),
                  description: roleRow[3] as String?,
                ))
            .toList();

        users.add(User(
          id: userData[0] as String,
          username: userData[1] as String,
          email: userData[2] as String?,
          passwordHash: userData[3] as String,
          name: userData[4] as String?,
          createdAt: userData[5] as DateTime,
          lastLogin: userData[6] as DateTime?,
          isActive: userData[7] as bool,
          roles: roles,
        ));
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
    final result = await _db.query('SELECT * FROM users WHERE id = @id',
        substitutionValues: {'id': id});
    if (result.isEmpty) return null;
    return User.fromRow(result.first);
  }

  Future<User?> findUserByEmail(String email) async {
    final results = await _db.query('SELECT * FROM users WHERE email = @email',
        substitutionValues: {'email': email});
    if (results.isEmpty) return null;
    return User.fromRow(results.first);
  }

  Future<List<User>> getAllUsers() async {
    final results = await _db.query('SELECT * FROM users');
    return results.map((row) => User.fromRow(row)).toList();
  }

  Future<User> createUser(User user) async {
    final result = await _db.query(
        'INSERT INTO users (email, password_hash, name, role) VALUES (@email, @password, @name, @role) RETURNING *',
        substitutionValues: {
          'email': user.email,
          'password': user.passwordHash,
          'name': user.name,
          'role': user.role.toString()
        });
    return User.fromRow(result.first);
  }

  Future<User?> updateUser(String id, Map<String, dynamic> updates) async {
    if (updates.isEmpty) return null;

    final setClause = updates.keys.map((key) => '$key = @$key').join(', ');
    final query = 'UPDATE users SET $setClause WHERE id = @id RETURNING *';

    final values = {...updates, 'id': id};
    final result = await _db.query(query, substitutionValues: values);

    if (result.isEmpty) return null;
    return User.fromRow(result.first);
  }

  Future<bool> deleteUser(String id) async {
    final result = await _db.execute('DELETE FROM users WHERE id = @id',
        substitutionValues: {'id': id});
    return result == 1;
  }

  Future<List<Role>> getUserRoles(String userId) async {
    final results = await _db.query(
        'SELECT r.* FROM roles r INNER JOIN user_roles ur ON r.id = ur.role_id WHERE ur.user_id = @userId',
        substitutionValues: {'userId': userId});
    return results.map((row) => Role.fromRow(row)).toList();
  }
}
