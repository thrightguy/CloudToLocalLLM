import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'encrypted_tunnel_service.dart';
import 'encrypted_tunnel_protocol.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

/// Desktop encrypted tunnel client
///
/// Handles the desktop side of the encrypted tunnel:
/// - Connects to cloud WebSocket bridge
/// - Receives encrypted HTTP requests from containers
/// - Forwards requests to local Ollama (localhost:11434)
/// - Encrypts responses and sends back through tunnel
class EncryptedTunnelClient extends ChangeNotifier {
  final EncryptedTunnelService _encryptionService;
  final AuthService _authService;

  // WebSocket connection to cloud bridge
  WebSocketChannel? _webSocket;
  StreamSubscription? _webSocketSubscription;

  // HTTP client for local Ollama requests
  final http.Client _httpClient = http.Client();

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _lastError;

  // Pending HTTP requests (correlation ID -> completer)
  final Map<String, Completer<HttpResponseMessage>> _pendingRequests = {};

  // Health monitoring
  Timer? _pingTimer;

  EncryptedTunnelClient({
    required EncryptedTunnelService encryptionService,
    required AuthService authService,
  }) : _encryptionService = encryptionService,
       _authService = authService;

  /// Whether the tunnel is connected
  bool get isConnected => _isConnected;

  /// Whether the tunnel is connecting
  bool get isConnecting => _isConnecting;

  /// Last error message
  String? get lastError => _lastError;

  /// Connect to the encrypted tunnel bridge
  Future<void> connect() async {
    if (_isConnecting || _isConnected) {
      return;
    }

    try {
      _isConnecting = true;
      _lastError = null;
      notifyListeners();

      debugPrint('🔐 [TunnelClient] Connecting to encrypted tunnel bridge...');

      // Ensure encryption service is initialized
      if (!_encryptionService.isInitialized) {
        await _encryptionService.initialize();
      }

      // Get authentication token
      final accessToken = _authService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No authentication token available');
      }

      // Connect to WebSocket bridge
      final wsUrl =
          '${AppConfig.apiBaseUrl.replaceFirst('https://', 'wss://')}/ws/encrypted-tunnel';
      final uri = Uri.parse(
        wsUrl,
      ).replace(queryParameters: {'token': accessToken});

      _webSocket = WebSocketChannel.connect(uri);

      // Set up message handling
      _webSocketSubscription = _webSocket!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClosed,
      );

      // Send key exchange message
      await _sendKeyExchange();

      // Start health monitoring
      _startHealthMonitoring();

      _isConnected = true;
      _isConnecting = false;

      debugPrint('🔐 [TunnelClient] Connected to encrypted tunnel bridge');
      notifyListeners();
    } catch (e) {
      _lastError = 'Connection failed: $e';
      _isConnecting = false;
      debugPrint('🔐 [TunnelClient] Connection failed: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Disconnect from the tunnel bridge
  Future<void> disconnect() async {
    debugPrint('🔐 [TunnelClient] Disconnecting from tunnel bridge...');

    _pingTimer?.cancel();
    _webSocketSubscription?.cancel();
    await _webSocket?.sink.close();

    _webSocket = null;
    _webSocketSubscription = null;
    _isConnected = false;
    _isConnecting = false;

    // Complete any pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Tunnel disconnected');
      }
    }
    _pendingRequests.clear();

    debugPrint('🔐 [TunnelClient] Disconnected from tunnel bridge');
    notifyListeners();
  }

  /// Send key exchange message to establish encrypted session
  Future<void> _sendKeyExchange() async {
    final publicKey = await _encryptionService.getDevicePublicKeyBase64();
    final userId = _authService.currentUser?.id ?? 'unknown';

    final keyExchange = KeyExchangeMessage(
      id: MessageIdGenerator.generate(),
      publicKey: publicKey,
      userId: userId,
    );

    await _sendMessage(keyExchange);
    debugPrint('🔐 [TunnelClient] Key exchange sent');
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic data) {
    try {
      final json = jsonDecode(data);

      // Check if this is an encrypted tunnel message
      if (json.containsKey('encryptedData')) {
        _handleEncryptedMessage(EncryptedTunnelMessage.fromJson(json));
      } else {
        // Handle unencrypted control messages
        final message = TunnelMessage.fromJson(json);
        _handleControlMessage(message);
      }
    } catch (e) {
      debugPrint('🔐 [TunnelClient] Error parsing message: $e');
    }
  }

  /// Handle encrypted tunnel messages
  Future<void> _handleEncryptedMessage(
    EncryptedTunnelMessage encryptedMsg,
  ) async {
    try {
      // Decrypt the message
      final decryptedData = await _encryptionService.decryptData(
        encryptedMsg.encryptedData,
      );
      final json = jsonDecode(decryptedData);
      final message = TunnelMessage.fromJson(json);

      switch (message.type) {
        case TunnelMessageType.httpRequest:
          await _handleHttpRequest(message as HttpRequestMessage);
          break;
        case TunnelMessageType.ping:
          await _handlePing(message as PingMessage);
          break;
        default:
          debugPrint(
            '🔐 [TunnelClient] Unexpected encrypted message type: ${message.type}',
          );
      }
    } catch (e) {
      debugPrint('🔐 [TunnelClient] Error handling encrypted message: $e');
    }
  }

  /// Handle unencrypted control messages
  Future<void> _handleControlMessage(TunnelMessage message) async {
    switch (message.type) {
      case TunnelMessageType.sessionEstablished:
        final sessionMsg = message as SessionEstablishedMessage;
        await _handleSessionEstablished(sessionMsg);
        break;
      case TunnelMessageType.error:
        final errorMsg = message as ErrorMessage;
        _handleError(errorMsg);
        break;
      case TunnelMessageType.pong:
        final pongMsg = message as PongMessage;
        _handlePong(pongMsg);
        break;
      default:
        debugPrint(
          '🔐 [TunnelClient] Unexpected control message type: ${message.type}',
        );
    }
  }

  /// Handle session established message
  Future<void> _handleSessionEstablished(
    SessionEstablishedMessage message,
  ) async {
    try {
      // Establish encrypted session with remote public key
      await _encryptionService.establishSession(message.publicKey);
      debugPrint(
        '🔐 [TunnelClient] Encrypted session established: ${message.sessionId}',
      );
    } catch (e) {
      debugPrint('🔐 [TunnelClient] Failed to establish session: $e');
    }
  }

  /// Handle HTTP request from container
  Future<void> _handleHttpRequest(HttpRequestMessage request) async {
    try {
      debugPrint(
        '🔐 [TunnelClient] Handling HTTP request: ${request.method} ${request.path}',
      );

      // Forward request to local Ollama
      final response = await _forwardToLocalOllama(request);

      // Send encrypted response back
      await _sendEncryptedMessage(response);
    } catch (e) {
      debugPrint('🔐 [TunnelClient] Error handling HTTP request: $e');

      // Send error response
      final errorResponse = HttpResponseMessage(
        id: MessageIdGenerator.generate(),
        statusCode: 500,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'error': 'Internal server error: $e'}),
        correlationId: request.id,
      );

      await _sendEncryptedMessage(errorResponse);
    }
  }

  /// Forward HTTP request to local Ollama
  Future<HttpResponseMessage> _forwardToLocalOllama(
    HttpRequestMessage request,
  ) async {
    final url = 'http://localhost:11434${request.path}';
    final uri = Uri.parse(url);

    late http.Response response;

    switch (request.method.toUpperCase()) {
      case 'GET':
        response = await _httpClient.get(uri, headers: request.headers);
        break;
      case 'POST':
        response = await _httpClient.post(
          uri,
          headers: request.headers,
          body: request.body,
        );
        break;
      case 'PUT':
        response = await _httpClient.put(
          uri,
          headers: request.headers,
          body: request.body,
        );
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: request.headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: ${request.method}');
    }

    return HttpResponseMessage(
      id: MessageIdGenerator.generate(),
      statusCode: response.statusCode,
      headers: response.headers.map((key, value) => MapEntry(key, value)),
      body: response.body,
      correlationId: request.id,
    );
  }

  /// Handle ping message
  Future<void> _handlePing(PingMessage ping) async {
    final pong = PongMessage(
      id: MessageIdGenerator.generate(),
      pingId: ping.id,
    );

    await _sendEncryptedMessage(pong);
  }

  /// Handle pong message
  void _handlePong(PongMessage pong) {
    debugPrint('🔐 [TunnelClient] Pong received');
  }

  /// Handle error message
  void _handleError(ErrorMessage error) {
    _lastError = error.error;
    debugPrint('🔐 [TunnelClient] Error received: ${error.error}');
    notifyListeners();
  }

  /// Send unencrypted message
  Future<void> _sendMessage(TunnelMessage message) async {
    if (_webSocket == null) {
      throw Exception('Not connected');
    }

    final json = jsonEncode(message.toJson());
    _webSocket!.sink.add(json);
  }

  /// Send encrypted message
  Future<void> _sendEncryptedMessage(TunnelMessage message) async {
    if (_webSocket == null) {
      throw Exception('Not connected');
    }

    if (_encryptionService.sessionId == null) {
      throw Exception('No encrypted session');
    }

    // Encrypt message
    final messageJson = jsonEncode(message.toJson());
    final encryptedData = await _encryptionService.encryptData(messageJson);

    // Create encrypted tunnel message
    final encryptedMsg = EncryptedTunnelMessage(
      encryptedData: encryptedData,
      sessionId: _encryptionService.sessionId!,
    );

    final json = jsonEncode(encryptedMsg.toJson());
    _webSocket!.sink.add(json);
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPing();
    });
  }

  /// Send ping message
  Future<void> _sendPing() async {
    try {
      final ping = PingMessage(id: MessageIdGenerator.generate());
      await _sendEncryptedMessage(ping);
    } catch (e) {
      debugPrint('🔐 [TunnelClient] Failed to send ping: $e');
    }
  }

  /// Handle WebSocket error
  void _handleWebSocketError(Object error) {
    _lastError = 'WebSocket error: $error';
    debugPrint('🔐 [TunnelClient] WebSocket error: $error');
    notifyListeners();
  }

  /// Handle WebSocket closed
  void _handleWebSocketClosed() {
    debugPrint('🔐 [TunnelClient] WebSocket connection closed');
    disconnect();
  }

  @override
  void dispose() {
    disconnect();
    _httpClient.close();
    super.dispose();
  }
}
