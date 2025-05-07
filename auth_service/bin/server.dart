import 'dart:io';
import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

final _logger = Logger('AuthServer');

// In-memory user store
final _users = <String, Map<String, dynamic>>{};

// JWT secret (use environment variable in production)
final jwtSecret =
    Platform.environment['JWT_SECRET'] ?? 'your-secret-key-change-this';

String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

void _handleHealthCheck(HttpRequest request) {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
    }))
    ..close();
}

Future<void> _handleRegister(HttpRequest request) async {
  try {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body);

    final username = data['username'] as String?;
    final password = data['password'] as String?;

    if (username == null || password == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Username and password are required')
        ..close();
      return;
    }

    if (_users.containsKey(username)) {
      request.response
        ..statusCode = HttpStatus.conflict
        ..write('Username already exists')
        ..close();
      return;
    }

    final hashedPassword = _hashPassword(password);
    final userId = 'user_${_users.length + 1}';

    _users[username] = {
      'id': userId,
      'username': username,
      'password': hashedPassword,
      'createdAt': DateTime.now().toIso8601String(),
    };

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'id': userId,
        'username': username,
        'createdAt': _users[username]!['createdAt'],
      }))
      ..close();
  } catch (e) {
    _logger.severe('Error in register endpoint', e);
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('Internal server error')
      ..close();
  }
}

Future<void> _handleLogin(HttpRequest request) async {
  try {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body);

    final username = data['username'] as String?;
    final password = data['password'] as String?;

    if (username == null || password == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Username and password are required')
        ..close();
      return;
    }

    final user = _users[username];
    if (user == null) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..write('Invalid credentials')
        ..close();
      return;
    }

    final hashedPassword = _hashPassword(password);
    if (hashedPassword != user['password']) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..write('Invalid credentials')
        ..close();
      return;
    }

    // Generate JWT token
    final jwt = JWT({
      'id': user['id'],
      'username': username,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });

    final token = jwt.sign(SecretKey(jwtSecret));

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'token': token,
        'user': {
          'id': user['id'],
          'username': username,
          'createdAt': user['createdAt'],
        },
      }))
      ..close();
  } catch (e) {
    _logger.severe('Error in login endpoint', e);
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('Internal server error')
      ..close();
  }
}

void _handleVerify(HttpRequest request) {
  try {
    final authHeader = request.headers.value('authorization');
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..write('No token provided')
        ..close();
      return;
    }

    final token = authHeader.substring(7);
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'valid': true,
          'payload': jwt.payload,
        }))
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..write('Invalid token')
        ..close();
    }
  } catch (e) {
    _logger.severe('Error in verify endpoint', e);
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('Internal server error')
      ..close();
  }
}

void _handleOptions(HttpRequest request) {
  request.response
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..headers.add(
        'Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization')
    ..statusCode = HttpStatus.ok
    ..close();
}

void _addCorsHeaders(HttpResponse response) {
  response.headers.add('Access-Control-Allow-Origin', '*');
  response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.headers.add(
      'Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization');
}

void main() async {
  // Initialize logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final server = await HttpServer.bind(ip, port);
  _logger.info('Server listening on port ${server.port}');

  await for (final request in server) {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      _handleOptions(request);
      continue;
    }

    switch ('${request.method} ${request.uri.path}') {
      case 'GET /health':
        _handleHealthCheck(request);
        break;
      case 'POST /register':
        await _handleRegister(request);
        break;
      case 'POST /login':
        await _handleLogin(request);
        break;
      case 'GET /verify':
        _handleVerify(request);
        break;
      default:
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found')
          ..close();
    }
  }
}
