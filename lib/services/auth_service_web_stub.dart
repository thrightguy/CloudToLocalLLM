import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Stub implementation of AuthServiceWeb for non-web platforms
/// This service throws UnsupportedError when used on non-web platforms
class AuthServiceWeb extends ChangeNotifier {
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);

  // Getters
  ValueNotifier<bool> get isAuthenticated => _isAuthenticated;
  ValueNotifier<bool> get isLoading => _isLoading;
  UserModel? get currentUser => null;
  String? get accessToken => null;
  String? get idToken => null;

  AuthServiceWeb() {
    debugPrint('⚠️ AuthServiceWeb stub created - web service not available on this platform');
  }

  /// Login using Auth0 redirect flow
  Future<void> login() async {
    throw UnsupportedError('Web authentication service is only supported on web platform');
  }

  /// Logout and clear all stored tokens
  Future<void> logout() async {
    throw UnsupportedError('Web authentication service is only supported on web platform');
  }

  /// Handle Auth0 callback
  Future<bool> handleCallback() async {
    throw UnsupportedError('Web authentication service is only supported on web platform');
  }

  @override
  void dispose() {
    _isAuthenticated.dispose();
    _isLoading.dispose();
    super.dispose();
  }
}
