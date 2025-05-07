import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:logging/logging.dart';
import '../services/jwt_service.dart';
import '../services/user_service.dart';

/// Create router for authentication routes
Router createAuthRoutes(UserService userService, JwtService jwtService) {
  final router = Router();
  final logger = Logger('AuthRoutes');

  // Login route
  router.post('/login', (Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);

      // Validate input
      final username = data['username'] as String?;
      final password = data['password'] as String?;

      if (username == null || password == null) {
        return Response(400,
            body: jsonEncode({
              'status': 'error',
              'message': 'Username and password are required',
            }),
            headers: {'content-type': 'application/json'});
      }

      // Authenticate user
      final user = await userService.authenticateUser(username, password);
      if (user == null) {
        return Response(401,
            body: jsonEncode({
              'status': 'error',
              'message': 'Invalid username or password',
            }),
            headers: {'content-type': 'application/json'});
      }

      // Generate JWT token
      final token = await jwtService.createToken(user);

      return Response.ok(
          jsonEncode({
            'status': 'success',
            'token': token,
            'user': {
              'id': user.id,
              'username': user.username,
              'email': user.email,
              'name': user.name,
              'roles': user.roles.map((r) => r.name).toList(),
            },
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      logger.severe('Error in login: $e');
      return Response.internalServerError(
          body: jsonEncode({
            'status': 'error',
            'message': 'Internal server error',
          }),
          headers: {'content-type': 'application/json'});
    }
  });

  // Register route
  router.post('/register', (Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);

      // Validate input
      final username = data['username'] as String?;
      final password = data['password'] as String?;
      final email = data['email'] as String?;
      final name = data['name'] as String?;

      if (username == null || password == null) {
        return Response(400,
            body: jsonEncode({
              'status': 'error',
              'message': 'Username and password are required',
            }),
            headers: {'content-type': 'application/json'});
      }

      // Register user
      final user =
          await userService.registerUser(username, password, email, name);
      if (user == null) {
        return Response(400,
            body: jsonEncode({
              'status': 'error',
              'message': 'Username or email already exists',
            }),
            headers: {'content-type': 'application/json'});
      }

      // Generate JWT token
      final token = await jwtService.createToken(user);

      return Response(201,
          body: jsonEncode({
            'status': 'success',
            'token': token,
            'user': {
              'id': user.id,
              'username': user.username,
              'email': user.email,
              'name': user.name,
              'roles': user.roles.map((r) => r.name).toList(),
            },
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      logger.severe('Error in register: $e');
      return Response.internalServerError(
          body: jsonEncode({
            'status': 'error',
            'message': 'Internal server error',
          }),
          headers: {'content-type': 'application/json'});
    }
  });

  // Verify token route
  router.get('/verify', (Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401,
            body: jsonEncode({
              'status': 'error',
              'message': 'Authorization header required',
            }),
            headers: {'content-type': 'application/json'});
      }

      final token = authHeader.substring(7);
      final claims = await jwtService.verifyToken(token);

      if (claims == null) {
        return Response(401,
            body: jsonEncode({
              'status': 'error',
              'message': 'Invalid or expired token',
            }),
            headers: {'content-type': 'application/json'});
      }

      return Response.ok(
          jsonEncode({
            'status': 'success',
            'message': 'Token is valid',
            'claims': claims,
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      logger.severe('Error in verify: $e');
      return Response.internalServerError(
          body: jsonEncode({
            'status': 'error',
            'message': 'Internal server error',
          }),
          headers: {'content-type': 'application/json'});
    }
  });

  return router;
}
