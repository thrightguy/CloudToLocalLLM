import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/tunnel_service.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Tunnel Service Provider
final tunnelServiceProvider = Provider<TunnelService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return TunnelService(authService);
});

// Auth State Provider
final authStateProvider = ChangeNotifierProvider<AuthService>((ref) {
  return ref.watch(authServiceProvider);
});

// Tunnel State Provider
final tunnelStateProvider = ChangeNotifierProvider<TunnelService>((ref) {
  return ref.watch(tunnelServiceProvider);
});

// Combined App State Provider
final appStateProvider = Provider<AppState>((ref) {
  final authService = ref.watch(authStateProvider);
  final tunnelService = ref.watch(tunnelStateProvider);
  
  return AppState(
    isAuthenticated: authService.isAuthenticated,
    isConnected: tunnelService.isConnected,
    authLoading: authService.isLoading,
    tunnelStatus: tunnelService.status,
    authError: authService.error,
    tunnelError: tunnelService.error,
  );
});

class AppState {
  final bool isAuthenticated;
  final bool isConnected;
  final bool authLoading;
  final TunnelStatus tunnelStatus;
  final String? authError;
  final String? tunnelError;

  const AppState({
    required this.isAuthenticated,
    required this.isConnected,
    required this.authLoading,
    required this.tunnelStatus,
    this.authError,
    this.tunnelError,
  });

  bool get hasError => authError != null || tunnelError != null;
  String? get primaryError => authError ?? tunnelError;
  
  String get statusText {
    if (authError != null) return 'Authentication Error';
    if (tunnelError != null) return 'Connection Error';
    if (!isAuthenticated) return 'Not Authenticated';
    if (authLoading) return 'Authenticating...';
    
    switch (tunnelStatus) {
      case TunnelStatus.disconnected:
        return 'Disconnected';
      case TunnelStatus.connecting:
        return 'Connecting...';
      case TunnelStatus.connected:
        return 'Connected';
      case TunnelStatus.reconnecting:
        return 'Reconnecting...';
      case TunnelStatus.error:
        return 'Connection Error';
    }
  }
  
  AppState copyWith({
    bool? isAuthenticated,
    bool? isConnected,
    bool? authLoading,
    TunnelStatus? tunnelStatus,
    String? authError,
    String? tunnelError,
  }) {
    return AppState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isConnected: isConnected ?? this.isConnected,
      authLoading: authLoading ?? this.authLoading,
      tunnelStatus: tunnelStatus ?? this.tunnelStatus,
      authError: authError ?? this.authError,
      tunnelError: tunnelError ?? this.tunnelError,
    );
  }

  @override
  String toString() {
    return 'AppState(isAuthenticated: $isAuthenticated, isConnected: $isConnected, status: $statusText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppState &&
        other.isAuthenticated == isAuthenticated &&
        other.isConnected == isConnected &&
        other.authLoading == authLoading &&
        other.tunnelStatus == tunnelStatus &&
        other.authError == authError &&
        other.tunnelError == tunnelError;
  }

  @override
  int get hashCode {
    return isAuthenticated.hashCode ^
        isConnected.hashCode ^
        authLoading.hashCode ^
        tunnelStatus.hashCode ^
        authError.hashCode ^
        tunnelError.hashCode;
  }
}
