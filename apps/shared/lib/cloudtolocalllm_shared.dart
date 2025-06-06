/// CloudToLocalLLM Shared Components
///
/// This library provides shared models, utilities, and IPC communication
/// components for the CloudToLocalLLM modular architecture.
///
/// Architecture Overview:
/// - Provides common data models (Conversation, Message, etc.)
/// - Shared IPC communication components
/// - Consistent interfaces across applications
/// - Code reusability and maintainability
///
/// Usage:
/// ```dart
/// import 'package:cloudtolocalllm_shared/cloudtolocalllm_shared.dart';
/// ```
///
/// This import gives access to all exported shared functionality.
library;

// Models
export 'models/conversation.dart';
export 'models/message.dart';
export 'models/ipc_message.dart';

// IPC Communication
export 'ipc/ipc_client.dart';
export 'ipc/ipc_server.dart';

// Utilities
export 'utils/version.dart';

// Utilities
export 'utils/logger.dart';
export 'utils/config.dart';
