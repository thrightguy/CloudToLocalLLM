import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Comprehensive administrative service for CloudToLocalLLM
///
/// Provides secure administrative functionality including:
/// - System monitoring and statistics
/// - User management and session control
/// - Configuration management
/// - Container and network management
/// - Real-time performance metrics
///
/// Features:
/// - Connects to dedicated admin server (port 3001)
/// - JWT authentication with admin role validation
/// - Comprehensive error handling and logging
/// - Real-time data updates and caching
/// - Platform abstraction support
class AdminService extends ChangeNotifier {
  final Dio _dio;
  final AuthService _authService;

  // Service state
  bool _isLoading = false;
  String? _error;
  bool _isAdminAuthenticated = false;

  // Cached data
  Map<String, dynamic>? _systemStats;
  Map<String, dynamic>? _realtimeData;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _containers = [];
  List<Map<String, dynamic>> _networks = [];
  Map<String, dynamic>? _configuration;
  Map<String, dynamic>? _performanceMetrics;

  // Update timestamps
  DateTime? _lastSystemStatsUpdate;
  DateTime? _lastRealtimeUpdate;
  DateTime? _lastUsersUpdate;
  DateTime? _lastContainersUpdate;

  AdminService({required AuthService authService})
    : _authService = authService,
      _dio = Dio() {
    _setupDio();
    _authService.addListener(_onAuthStateChanged);
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdminAuthenticated => _isAdminAuthenticated;
  Map<String, dynamic>? get systemStats => _systemStats;
  Map<String, dynamic>? get realtimeData => _realtimeData;
  DateTime? get lastRealtimeUpdate => _lastRealtimeUpdate;
  List<Map<String, dynamic>> get users => _users;
  List<Map<String, dynamic>> get containers => _containers;
  List<Map<String, dynamic>> get networks => _networks;
  Map<String, dynamic>? get configuration => _configuration;
  Map<String, dynamic>? get performanceMetrics => _performanceMetrics;

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.adminApiBaseUrl;
    _dio.options.connectTimeout = AppConfig.adminApiTimeout;
    _dio.options.receiveTimeout = AppConfig.adminApiTimeout;

    // Add auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getValidatedAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          debugPrint('🔧 [AdminService] API Error: ${error.message}');
          if (error.response?.statusCode == 403) {
            _isAdminAuthenticated = false;
            _setError(
              'Admin access denied. Please ensure you have admin privileges.',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  void _onAuthStateChanged() {
    if (!_authService.isAuthenticated.value) {
      _isAdminAuthenticated = false;
      _clearAllData();
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearAllData() {
    _systemStats = null;
    _realtimeData = null;
    _users.clear();
    _containers.clear();
    _networks.clear();
    _configuration = null;
    _performanceMetrics = null;
    _lastSystemStatsUpdate = null;
    _lastRealtimeUpdate = null;
    _lastUsersUpdate = null;
    _lastContainersUpdate = null;
  }

  /// Clear any previous error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if current user has admin privileges
  Future<bool> checkAdminPrivileges() async {
    try {
      debugPrint('🔧 [AdminService] Checking admin privileges');

      final response = await _dio.get('/auth/check');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _isAdminAuthenticated = true;
        debugPrint('🔧 [AdminService] Admin privileges confirmed');
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('🔧 [AdminService] Admin privilege check failed: $e');
      _isAdminAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Get system statistics
  Future<bool> getSystemStats({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _systemStats != null &&
        _lastSystemStatsUpdate != null &&
        DateTime.now().difference(_lastSystemStatsUpdate!).inSeconds <
            AppConfig.adminDashboardRefreshIntervalSeconds) {
      return true;
    }

    try {
      debugPrint('🔧 [AdminService] Fetching system statistics');
      _setLoading(true);

      final response = await _dio.get('/system/stats');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _systemStats = response.data['data'];
        _lastSystemStatsUpdate = DateTime.now();

        debugPrint('🔧 [AdminService] System statistics updated');
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to get system statistics');
      }
    } catch (e) {
      _setError('Failed to get system statistics: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting system stats: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get real-time system data
  Future<bool> getRealtimeData() async {
    try {
      debugPrint('🔧 [AdminService] Fetching real-time system data');

      final response = await _dio.get('/system/realtime');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _realtimeData = response.data['data'];
        _lastRealtimeUpdate = DateTime.now();

        debugPrint('🔧 [AdminService] Real-time data updated');
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to get real-time data');
      }
    } catch (e) {
      debugPrint('🔧 [AdminService] Error getting real-time data: $e');
      return false;
    }
  }

  /// Get user list
  Future<bool> getUsers({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _users.isNotEmpty &&
        _lastUsersUpdate != null &&
        DateTime.now().difference(_lastUsersUpdate!).inMinutes < 5) {
      return true;
    }

    try {
      debugPrint('🔧 [AdminService] Fetching user list');
      _setLoading(true);

      final response = await _dio.get('/users');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _users = List<Map<String, dynamic>>.from(
          response.data['data']['users'] ?? [],
        );
        _lastUsersUpdate = DateTime.now();

        debugPrint(
          '🔧 [AdminService] User list updated: ${_users.length} users',
        );
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to get user list');
      }
    } catch (e) {
      _setError('Failed to get user list: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting users: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get container list
  Future<bool> getContainers({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _containers.isNotEmpty &&
        _lastContainersUpdate != null &&
        DateTime.now().difference(_lastContainersUpdate!).inMinutes < 2) {
      return true;
    }

    try {
      debugPrint('🔧 [AdminService] Fetching container list');
      _setLoading(true);

      final response = await _dio.get('/containers');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _containers = List<Map<String, dynamic>>.from(
          response.data['data'] ?? [],
        );
        _lastContainersUpdate = DateTime.now();

        debugPrint(
          '🔧 [AdminService] Container list updated: ${_containers.length} containers',
        );
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to get container list');
      }
    } catch (e) {
      _setError('Failed to get container list: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting containers: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get network list
  Future<bool> getNetworks() async {
    try {
      debugPrint('🔧 [AdminService] Fetching network list');

      final response = await _dio.get('/networks');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _networks = List<Map<String, dynamic>>.from(
          response.data['data'] ?? [],
        );

        debugPrint(
          '🔧 [AdminService] Network list updated: ${_networks.length} networks',
        );
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to get network list');
      }
    } catch (e) {
      _setError('Failed to get network list: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting networks: $e');
      return false;
    }
  }

  /// Get user sessions for a specific user
  Future<Map<String, dynamic>?> getUserSessions(String userId) async {
    try {
      debugPrint('🔧 [AdminService] Fetching sessions for user: $userId');

      final response = await _dio.get('/users/$userId/sessions');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] User sessions retrieved');
        return response.data['data'];
      } else {
        throw Exception('Failed to get user sessions');
      }
    } catch (e) {
      _setError('Failed to get user sessions: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting user sessions: $e');
      return null;
    }
  }

  /// Terminate a user session
  Future<bool> terminateUserSession(String userId, String containerId) async {
    try {
      debugPrint(
        '🔧 [AdminService] Terminating session: $containerId for user: $userId',
      );
      _setLoading(true);

      final response = await _dio.post(
        '/users/$userId/sessions/$containerId/terminate',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] Session terminated successfully');

        // Refresh containers list
        await getContainers(forceRefresh: true);
        return true;
      } else {
        throw Exception('Failed to terminate session');
      }
    } catch (e) {
      _setError('Failed to terminate session: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error terminating session: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get system configuration
  Future<bool> getConfiguration() async {
    try {
      debugPrint('🔧 [AdminService] Fetching system configuration');
      _setLoading(true);

      final response = await _dio.get('/config');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _configuration = response.data['data'];

        debugPrint('🔧 [AdminService] Configuration retrieved');
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to get configuration');
      }
    } catch (e) {
      _setError('Failed to get configuration: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting configuration: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get environment variables
  Future<Map<String, dynamic>?> getEnvironmentVariables() async {
    try {
      debugPrint('🔧 [AdminService] Fetching environment variables');

      final response = await _dio.get('/config/environment');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] Environment variables retrieved');
        return response.data['data'];
      } else {
        throw Exception('Failed to get environment variables');
      }
    } catch (e) {
      _setError('Failed to get environment variables: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting environment variables: $e');
      return null;
    }
  }

  /// Get feature flags
  Future<Map<String, dynamic>?> getFeatureFlags() async {
    try {
      debugPrint('🔧 [AdminService] Fetching feature flags');

      final response = await _dio.get('/config/features');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] Feature flags retrieved');
        return response.data['data'];
      } else {
        throw Exception('Failed to get feature flags');
      }
    } catch (e) {
      _setError('Failed to get feature flags: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting feature flags: $e');
      return null;
    }
  }

  /// Get service status
  Future<Map<String, dynamic>?> getServiceStatus() async {
    try {
      debugPrint('🔧 [AdminService] Fetching service status');

      final response = await _dio.get('/config/services');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] Service status retrieved');
        return response.data['data'];
      } else {
        throw Exception('Failed to get service status');
      }
    } catch (e) {
      _setError('Failed to get service status: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting service status: $e');
      return null;
    }
  }

  /// Get container logs
  Future<Map<String, dynamic>?> getContainerLogs(
    String containerId, {
    int lines = 100,
  }) async {
    try {
      debugPrint('🔧 [AdminService] Fetching logs for container: $containerId');

      final response = await _dio.get(
        '/containers/$containerId/logs?lines=$lines',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] Container logs retrieved');
        return response.data['data'];
      } else {
        throw Exception('Failed to get container logs');
      }
    } catch (e) {
      _setError('Failed to get container logs: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting container logs: $e');
      return null;
    }
  }

  /// Get container resource stats
  Future<Map<String, dynamic>?> getContainerStats(String containerId) async {
    try {
      debugPrint(
        '🔧 [AdminService] Fetching stats for container: $containerId',
      );

      final response = await _dio.get('/containers/$containerId/stats');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] Container stats retrieved');
        return response.data['data'];
      } else {
        throw Exception('Failed to get container stats');
      }
    } catch (e) {
      _setError('Failed to get container stats: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting container stats: $e');
      return null;
    }
  }

  /// Get network topology
  Future<Map<String, dynamic>?> getNetworkTopology() async {
    try {
      debugPrint('🔧 [AdminService] Fetching network topology');

      final response = await _dio.get('/network/topology');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('🔧 [AdminService] Network topology retrieved');
        return response.data['data'];
      } else {
        throw Exception('Failed to get network topology');
      }
    } catch (e) {
      _setError('Failed to get network topology: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting network topology: $e');
      return null;
    }
  }

  /// Get performance metrics
  Future<bool> getPerformanceMetrics() async {
    try {
      debugPrint('🔧 [AdminService] Fetching performance metrics');

      final response = await _dio.get('/system/performance');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _performanceMetrics = response.data['data'];

        debugPrint('🔧 [AdminService] Performance metrics retrieved');
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to get performance metrics');
      }
    } catch (e) {
      _setError('Failed to get performance metrics: ${e.toString()}');
      debugPrint('🔧 [AdminService] Error getting performance metrics: $e');
      return false;
    }
  }

  /// Initialize admin service and check privileges
  Future<bool> initialize() async {
    debugPrint('🔧 [AdminService] Initializing admin service');

    if (!_authService.isAuthenticated.value) {
      debugPrint('🔧 [AdminService] User not authenticated');
      return false;
    }

    final hasAdminAccess = await checkAdminPrivileges();
    if (!hasAdminAccess) {
      debugPrint('🔧 [AdminService] User does not have admin privileges');
      return false;
    }

    // Load initial data
    await Future.wait([
      getSystemStats(),
      getUsers(),
      getContainers(),
      getNetworks(),
      getConfiguration(),
    ]);

    debugPrint('🔧 [AdminService] Admin service initialized successfully');
    return true;
  }

  /// Refresh all data
  Future<void> refreshAllData() async {
    debugPrint('🔧 [AdminService] Refreshing all admin data');

    await Future.wait([
      getSystemStats(forceRefresh: true),
      getRealtimeData(),
      getUsers(forceRefresh: true),
      getContainers(forceRefresh: true),
      getNetworks(),
      getPerformanceMetrics(),
    ]);

    debugPrint('🔧 [AdminService] All admin data refreshed');
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _dio.close();
    super.dispose();
  }
}
