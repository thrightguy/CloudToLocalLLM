import 'package:flutter/foundation.dart';

/// Enhanced error classification for Ollama connection failures
///
/// Provides detailed error types to enable better user feedback and
/// appropriate retry strategies for different failure scenarios.
enum OllamaConnectionErrorType {
  /// Ollama service is not running (connection refused)
  serviceNotRunning,

  /// Ollama is not installed or not in PATH
  serviceNotInstalled,

  /// Network connectivity issues
  networkError,

  /// Authentication/authorization failures
  authenticationError,

  /// Ollama service is running but responding with errors
  serviceError,

  /// Request timeout
  timeout,

  /// Unknown or unclassified error
  unknown,
}

/// Enhanced connection error with classification and user guidance
@immutable
class OllamaConnectionError {
  final OllamaConnectionErrorType type;
  final String message;
  final String? technicalDetails;
  final String userFriendlyMessage;
  final String actionableGuidance;
  final bool isRetryable;
  final Duration? suggestedRetryDelay;

  const OllamaConnectionError({
    required this.type,
    required this.message,
    this.technicalDetails,
    required this.userFriendlyMessage,
    required this.actionableGuidance,
    required this.isRetryable,
    this.suggestedRetryDelay,
  });

  /// Create error from exception with automatic classification
  factory OllamaConnectionError.fromException(dynamic exception) {
    final errorMessage = exception.toString().toLowerCase();

    if (errorMessage.contains('connection refused') ||
        errorMessage.contains('errno = 111')) {
      return const OllamaConnectionError(
        type: OllamaConnectionErrorType.serviceNotRunning,
        message: 'Connection refused',
        userFriendlyMessage: 'Ollama service is not running',
        actionableGuidance:
            'Start Ollama service or install Ollama if not installed',
        isRetryable: true,
        suggestedRetryDelay: Duration(seconds: 30),
      );
    }

    if (errorMessage.contains('timeout') ||
        errorMessage.contains('timed out')) {
      return const OllamaConnectionError(
        type: OllamaConnectionErrorType.timeout,
        message: 'Connection timeout',
        userFriendlyMessage: 'Connection timed out',
        actionableGuidance:
            'Check network connection and Ollama service status',
        isRetryable: true,
        suggestedRetryDelay: Duration(seconds: 15),
      );
    }

    if (errorMessage.contains('host not found') ||
        errorMessage.contains('name resolution failed')) {
      return const OllamaConnectionError(
        type: OllamaConnectionErrorType.networkError,
        message: 'Network error',
        userFriendlyMessage: 'Cannot reach Ollama service',
        actionableGuidance:
            'Check network connection and Ollama URL configuration',
        isRetryable: true,
        suggestedRetryDelay: Duration(seconds: 20),
      );
    }

    if (errorMessage.contains('401') ||
        errorMessage.contains('403') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('forbidden')) {
      return const OllamaConnectionError(
        type: OllamaConnectionErrorType.authenticationError,
        message: 'Authentication failed',
        userFriendlyMessage: 'Authentication failed',
        actionableGuidance: 'Check authentication credentials and permissions',
        isRetryable: false,
      );
    }

    if (errorMessage.contains('500') ||
        errorMessage.contains('502') ||
        errorMessage.contains('503') ||
        errorMessage.contains('504')) {
      return const OllamaConnectionError(
        type: OllamaConnectionErrorType.serviceError,
        message: 'Service error',
        userFriendlyMessage: 'Ollama service error',
        actionableGuidance:
            'Ollama service is having issues, try restarting it',
        isRetryable: true,
        suggestedRetryDelay: Duration(seconds: 60),
      );
    }

    // Default to unknown error
    return OllamaConnectionError(
      type: OllamaConnectionErrorType.unknown,
      message: exception.toString(),
      technicalDetails: exception.toString(),
      userFriendlyMessage: 'Connection failed',
      actionableGuidance: 'Check Ollama installation and service status',
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 30),
    );
  }

  /// Get setup instructions based on error type
  String getSetupInstructions() {
    switch (type) {
      case OllamaConnectionErrorType.serviceNotRunning:
      case OllamaConnectionErrorType.serviceNotInstalled:
        return '''
To set up Ollama:

1. Install Ollama from https://ollama.ai
2. Start Ollama service:
   • Linux/macOS: Run 'ollama serve' in terminal
   • Windows: Ollama should start automatically
3. Test with: 'ollama list' to verify installation
4. Try connecting again from CloudToLocalLLM
        ''';

      case OllamaConnectionErrorType.networkError:
        return '''
Network troubleshooting:

1. Check if Ollama is running on the correct port (default: 11434)
2. Verify the Ollama URL in settings
3. Check firewall settings
4. Try accessing http://localhost:11434 in your browser
        ''';

      case OllamaConnectionErrorType.timeout:
        return '''
Connection timeout troubleshooting:

1. Increase connection timeout in Advanced Settings
2. Check system resources (CPU/Memory)
3. Restart Ollama service
4. Check for network connectivity issues
        ''';

      default:
        return '''
General troubleshooting:

1. Ensure Ollama is installed and running
2. Check the Ollama URL configuration
3. Verify network connectivity
4. Restart both Ollama and CloudToLocalLLM
        ''';
    }
  }

  /// Get icon for error type
  String getErrorIcon() {
    switch (type) {
      case OllamaConnectionErrorType.serviceNotRunning:
      case OllamaConnectionErrorType.serviceNotInstalled:
        return '🚫';
      case OllamaConnectionErrorType.networkError:
        return '🌐';
      case OllamaConnectionErrorType.timeout:
        return '⏱️';
      case OllamaConnectionErrorType.authenticationError:
        return '🔒';
      case OllamaConnectionErrorType.serviceError:
        return '⚠️';
      default:
        return '❌';
    }
  }

  @override
  String toString() {
    return 'OllamaConnectionError(type: $type, message: $message, '
        'userFriendlyMessage: $userFriendlyMessage, isRetryable: $isRetryable)';
  }
}

/// Retry state for connection attempts
@immutable
class ConnectionRetryState {
  final int attemptCount;
  final DateTime? lastAttempt;
  final DateTime? nextAttempt;
  final Duration currentDelay;
  final bool isBackedOff;
  final bool hasReachedMaxAttempts;

  const ConnectionRetryState({
    this.attemptCount = 0,
    this.lastAttempt,
    this.nextAttempt,
    this.currentDelay = const Duration(seconds: 1),
    this.isBackedOff = false,
    this.hasReachedMaxAttempts = false,
  });

  /// Create initial retry state
  factory ConnectionRetryState.initial() {
    return const ConnectionRetryState();
  }

  /// Create next retry state with exponential backoff
  ConnectionRetryState nextRetryAttempt({
    required int maxAttempts,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(minutes: 5),
  }) {
    final newAttemptCount = attemptCount + 1;
    final hasReachedMax = newAttemptCount >= maxAttempts;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, up to maxDelay
    final exponentialDelay = Duration(
      milliseconds: (baseDelay.inMilliseconds * (1 << (newAttemptCount - 1)))
          .clamp(baseDelay.inMilliseconds, maxDelay.inMilliseconds),
    );

    final now = DateTime.now();
    final nextAttemptTime = hasReachedMax ? null : now.add(exponentialDelay);

    return ConnectionRetryState(
      attemptCount: newAttemptCount,
      lastAttempt: now,
      nextAttempt: nextAttemptTime,
      currentDelay: exponentialDelay,
      isBackedOff: exponentialDelay > baseDelay,
      hasReachedMaxAttempts: hasReachedMax,
    );
  }

  /// Reset retry state
  ConnectionRetryState reset() {
    return ConnectionRetryState.initial();
  }

  /// Check if ready for next attempt
  bool get canRetry {
    if (hasReachedMaxAttempts) return false;
    if (nextAttempt == null) return true;
    return DateTime.now().isAfter(nextAttempt!);
  }

  /// Time until next retry attempt
  Duration? get timeUntilNextRetry {
    if (nextAttempt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(nextAttempt!)) return Duration.zero;
    return nextAttempt!.difference(now);
  }

  @override
  String toString() {
    return 'ConnectionRetryState(attempts: $attemptCount, '
        'canRetry: $canRetry, delay: $currentDelay)';
  }
}
