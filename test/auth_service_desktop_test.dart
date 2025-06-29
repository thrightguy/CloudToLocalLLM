import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/auth_service_desktop.dart';

void main() {
  group('AuthServiceDesktop', () {
    late AuthServiceDesktop authService;

    setUp(() {
      authService = AuthServiceDesktop();
    });

    tearDown(() {
      authService.dispose();
    });

    test('should initialize with unauthenticated state', () {
      expect(authService.isAuthenticated.value, false);
      expect(authService.isLoading.value, false);
      expect(authService.currentUser, null);
      expect(authService.accessToken, null);
    });

    test('should handle logout correctly', () async {
      await authService.logout();

      expect(authService.isAuthenticated.value, false);
      expect(authService.accessToken, null);
      expect(authService.currentUser, null);
    });

    test('should return false for handleCallback when no tokens', () async {
      final result = await authService.handleCallback();
      expect(result, false);
    });
  });
}
