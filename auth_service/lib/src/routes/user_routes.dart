import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:logging/logging.dart';
import '../services/jwt_service.dart';
import '../services/user_service.dart';

/// Create router for user management routes
Router createUserRoutes(UserService userService, JwtService jwtService) {
  final router = Router();
  final logger = Logger('UserRoutes');

  // Middleware to authorize requests
  Middleware authorize(List<String> requiredRoles) {
    return (Handler innerHandler) {
      return (Request request) async {
        // Get the authorization header
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401,
              body: jsonEncode({
                'status': 'error',
                'message': 'Authorization header required',
              }),
              headers: {'content-type': 'application/json'});
        }

        // Verify the token
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

        // Check roles if required
        if (requiredRoles.isNotEmpty) {
          final userRoles = (claims['roles'] as List<dynamic>).cast<String>();
          final hasRequiredRole = requiredRoles.any(
            (role) => userRoles.contains(role),
          );

          if (!hasRequiredRole) {
            return Response(403,
                body: jsonEncode({
                  'status': 'error',
                  'message': 'Forbidden: insufficient permissions',
                }),
                headers: {'content-type': 'application/json'});
          }
        }

        // Add user ID to request context
        final userId = claims['sub'] as String;
        final updatedRequest = request.change(context: {'userId': userId});

        // Continue with the request
        return await innerHandler(updatedRequest);
      };
    };
  }

  // Get all users (admin only)
  router.get(
      '/',
      authorize(['admin'])(
        (Request request) async {
          try {
            final users = await userService.getUsers();

            return Response.ok(
                jsonEncode({
                  'status': 'success',
                  'data': users
                      .map((user) => {
                            'id': user.id,
                            'username': user.username,
                            'email': user.email,
                            'name': user.name,
                            'roles': user.roles.map((r) => r.name).toList(),
                            'createdAt': user.createdAt.toIso8601String(),
                            'lastLogin': user.lastLogin?.toIso8601String(),
                            'isActive': user.isActive,
                          })
                      .toList(),
                }),
                headers: {'content-type': 'application/json'});
          } catch (e) {
            logger.severe('Error getting users: $e');
            return Response.internalServerError(
                body: jsonEncode({
                  'status': 'error',
                  'message': 'Internal server error',
                }),
                headers: {'content-type': 'application/json'});
          }
        } as Handler,
      ));

  // Get user by ID (admin or self)
  router.get(
      '/<id>',
      authorize([])(
        (Request request, String id) async {
          try {
            final userId = request.context['userId'] as String;
            final user = await userService.getUserById(id);

            if (user == null) {
              return Response.notFound(
                  jsonEncode({
                    'status': 'error',
                    'message': 'User not found',
                  }),
                  headers: {'content-type': 'application/json'});
            }

            // Check if user is self or admin
            final isSelf = userId == id;
            final claims = await jwtService
                .verifyToken(request.headers['authorization']!.substring(7));
            final userRoles =
                (claims!['roles'] as List<dynamic>).cast<String>();
            final isAdmin = userRoles.contains('admin');

            if (!isSelf && !isAdmin) {
              return Response(403,
                  body: jsonEncode({
                    'status': 'error',
                    'message':
                        'Forbidden: you can only access your own profile',
                  }),
                  headers: {'content-type': 'application/json'});
            }

            return Response.ok(
                jsonEncode({
                  'status': 'success',
                  'data': {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email,
                    'name': user.name,
                    'roles': user.roles.map((r) => r.name).toList(),
                    'createdAt': user.createdAt.toIso8601String(),
                    'lastLogin': user.lastLogin?.toIso8601String(),
                    'isActive': user.isActive,
                  },
                }),
                headers: {'content-type': 'application/json'});
          } catch (e) {
            logger.severe('Error getting user: $e');
            return Response.internalServerError(
                body: jsonEncode({
                  'status': 'error',
                  'message': 'Internal server error',
                }),
                headers: {'content-type': 'application/json'});
          }
        } as Handler,
      ));

  // Admin dashboard stats
  router.get(
      '/stats/dashboard',
      authorize(['admin'])(
        (Request request) async {
          try {
            final users = await userService.getUsers();

            // Calculate basic stats
            final totalUsers = users.length;
            final activeUsers = users.where((u) => u.isActive).length;
            final recentUsers = users
                .where((u) => u.createdAt
                    .isAfter(DateTime.now().subtract(const Duration(days: 30))))
                .length;

            return Response.ok(
                jsonEncode({
                  'status': 'success',
                  'data': {
                    'totalUsers': totalUsers,
                    'activeUsers': activeUsers,
                    'recentUsers': recentUsers,
                  },
                }),
                headers: {'content-type': 'application/json'});
          } catch (e) {
            logger.severe('Error getting dashboard stats: $e');
            return Response.internalServerError(
                body: jsonEncode({
                  'status': 'error',
                  'message': 'Internal server error',
                }),
                headers: {'content-type': 'application/json'});
          }
        } as Handler,
      ));

  return router;
}
