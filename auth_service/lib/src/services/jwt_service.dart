import 'dart:convert';
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import '../config/environment.dart';
import '../models/user.dart';

/// Custom exception for JWT-related errors
class JwtException implements Exception {
  final String message;
  final dynamic originalError;

  JwtException(this.message, [this.originalError]);

  @override
  String toString() =>
      'JwtException: $message${originalError != null ? ' ($originalError)' : ''}';
}

class JwtService {
  final Logger _logger = Logger('JwtService');
  final String _secret;
  final Duration _expiresIn;

  JwtService({
    String? secret,
    Duration? expiresIn,
  })  : _secret = secret ?? Environment.jwtSecret,
        _expiresIn = expiresIn ?? const Duration(hours: 24) {
    if (_secret.isEmpty) {
      throw JwtException('JWT secret cannot be empty');
    }
  }

  /// Create a JWT token for the user
  Future<String> createToken(User user) async {
    try {
      if (user.id.isEmpty || user.username.isEmpty) {
        throw JwtException('Invalid user data: ID and username are required');
      }

      final jwk = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': base64Url.encode(utf8.encode(_secret)),
      });

      final now = DateTime.now();
      final exp = now.add(_expiresIn);

      final builder = JsonWebSignatureBuilder()
        ..jsonContent = {
          'sub': user.id,
          'username': user.username,
          'email': user.email,
          'roles': user.roles.map((r) => r.name).toList(),
          'permissions':
              user.roles.expand((r) => r.permissions).toSet().toList(),
          'exp': exp.millisecondsSinceEpoch ~/ 1000,
          'iat': now.millisecondsSinceEpoch ~/ 1000,
          'nbf': now.millisecondsSinceEpoch ~/ 1000,
        }
        ..addRecipient(jwk, algorithm: 'HS256');

      return builder.build().toCompactSerialization();
    } catch (e) {
      final error =
          e is JwtException ? e : JwtException('Error creating JWT token', e);
      _logger.severe(error);
      throw error;
    }
  }

  /// Verify a JWT token and return the payload if valid
  Future<Map<String, dynamic>?> verifyToken(String token) async {
    try {
      if (token.isEmpty) {
        throw JwtException('Token cannot be empty');
      }

      final parts = token.split('.');
      if (parts.length != 3) {
        throw JwtException('Invalid token format');
      }

      final jwk = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': base64Url.encode(utf8.encode(_secret)),
      });

      final jws = JsonWebSignature.fromCompactSerialization(token);

      // Verify the signature
      final keyStore = JsonWebKeyStore()..addKey(jwk);
      final isVerified = await jws.verify(keyStore);

      if (!isVerified) {
        throw JwtException('Invalid token signature');
      }

      // Decode the payload
      final payload = jws.unverifiedPayload.toString();
      final Map<String, dynamic> claims = jsonDecode(payload);

      // Validate required claims
      if (!claims.containsKey('sub') || !claims.containsKey('exp')) {
        throw JwtException('Missing required claims');
      }

      // Check token expiration
      final expiry = claims['exp'] as int;
      final expiryDateTime = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);

      if (expiryDateTime.isBefore(DateTime.now())) {
        throw JwtException('Token has expired');
      }

      // Check not before time if present
      final nbf = claims['nbf'] as int?;
      if (nbf != null) {
        final notBefore = DateTime.fromMillisecondsSinceEpoch(nbf * 1000);
        if (notBefore.isAfter(DateTime.now())) {
          throw JwtException('Token not yet valid');
        }
      }

      return claims;
    } catch (e) {
      final error =
          e is JwtException ? e : JwtException('Error verifying JWT token', e);
      _logger.warning(error);
      return null;
    }
  }

  /// Extract user ID from token without full verification
  /// This method is intended for quick ID extraction and should not be used for authentication
  @visibleForTesting
  String? extractUserId(String token) {
    try {
      if (token.isEmpty) return null;

      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> claims = jsonDecode(decoded);

      final sub = claims['sub'];
      if (sub is! String || sub.isEmpty) return null;

      return sub;
    } catch (e) {
      _logger.fine('Error extracting user ID from token: $e');
      return null;
    }
  }

  /// Refresh a token if it's about to expire
  Future<String?> refreshTokenIfNeeded(String token, User user) async {
    try {
      final claims = await verifyToken(token);
      if (claims == null) return null;

      final exp = claims['exp'] as int;
      final expiryDateTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      // If token expires in less than 25% of its total lifetime, refresh it
      final shouldRefresh = expiryDateTime.difference(now) < _expiresIn * 0.25;

      if (shouldRefresh) {
        return await createToken(user);
      }

      return token;
    } catch (e) {
      _logger.warning('Error refreshing token: $e');
      return null;
    }
  }
}
