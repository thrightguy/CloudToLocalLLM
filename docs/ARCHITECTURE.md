# CloudToLocalLLM - Architecture Documentation

## 🏗️ System Architecture Overview

CloudToLocalLLM follows a modular, multi-application architecture designed for scalability, maintainability, and code reusability. The system is built using Flutter and supports multiple platforms with a focus on desktop Linux deployment.

## 📊 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudToLocalLLM System                   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Chat App  │  │  Main App   │  │ Future Apps │         │
│  │             │  │  (Future)   │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                   Shared Library                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Models    │  │  Services   │  │  Utilities  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                 External Services                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Ollama    │  │    Auth0    │  │ System Tray │         │
│  │   (Local)   │  │   (Cloud)   │  │  (Desktop)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Core Design Principles

### 1. Modular Architecture
- **Separation of Concerns**: Each module has a specific responsibility
- **Loose Coupling**: Modules interact through well-defined interfaces
- **High Cohesion**: Related functionality is grouped together

### 2. Shared Library Pattern
- **Code Reusability**: Common functionality is centralized
- **Consistency**: Shared models ensure data consistency across apps
- **Maintainability**: Changes to shared code propagate to all apps

### 3. Platform-Aware Design
- **Cross-Platform**: Core logic works on web, desktop, and mobile
- **Platform-Specific**: UI and system integration adapt to platform capabilities
- **Progressive Enhancement**: Features gracefully degrade on unsupported platforms

## 📁 Detailed Module Structure

### Chat Application (`apps/chat/`)

```
apps/chat/
├── lib/
│   ├── main.dart                    # Application entry point
│   ├── main_chat.dart              # Alternative entry point
│   │
│   ├── screens/                    # UI Screens
│   │   ├── home_screen.dart        # Main chat interface
│   │   ├── login_screen.dart       # Authentication screen
│   │   ├── loading_screen.dart     # App initialization
│   │   └── settings/               # Settings screens
│   │       ├── daemon_settings_screen.dart
│   │       ├── llm_provider_settings_screen.dart
│   │       └── connection_status_screen.dart
│   │
│   ├── components/                 # Reusable UI Components
│   │   ├── conversation_list.dart  # Conversation sidebar
│   │   ├── message_bubble.dart     # Chat message display
│   │   ├── message_input.dart      # Message input field
│   │   └── model_selector.dart     # LLM model selection
│   │
│   ├── services/                   # Business Logic
│   │   ├── auth_service.dart       # Authentication management
│   │   ├── chat_service.dart       # Chat functionality
│   │   ├── ollama_service.dart     # Ollama API integration
│   │   ├── ipc_chat_service.dart   # Inter-process communication
│   │   └── simplified_connection_service.dart
│   │
│   ├── models/                     # Data Models
│   │   ├── conversation.dart       # Conversation data structure
│   │   ├── message.dart           # Message data structure
│   │   └── ollama_model.dart      # Ollama model information
│   │
│   ├── config/                     # Configuration
│   │   ├── app_config.dart        # Application configuration
│   │   ├── theme.dart             # UI theme definition
│   │   └── router.dart            # Navigation routing
│   │
│   └── utils/                      # Utilities
│       └── platform_utils.dart    # Platform detection
│
├── pubspec.yaml                    # Dependencies
└── assets/                         # Static assets
    ├── images/
    └── version.json
```

### Shared Library (`apps/shared/`)

```
apps/shared/
├── lib/
│   ├── cloudtolocalllm_shared.dart # Main export file
│   │
│   ├── models/                     # Shared Data Models
│   │   ├── conversation.dart       # Conversation model
│   │   ├── message.dart           # Message model
│   │   └── user.dart              # User model
│   │
│   ├── services/                   # Shared Services
│   │   ├── base_auth_service.dart  # Authentication base
│   │   └── api_client.dart        # HTTP client
│   │
│   ├── utils/                      # Shared Utilities
│   │   ├── logger.dart            # Logging utility
│   │   ├── constants.dart         # Application constants
│   │   └── validators.dart        # Input validation
│   │
│   └── config/                     # Shared Configuration
│       └── app_constants.dart     # Global constants
│
└── pubspec.yaml                    # Shared dependencies
```

## 🔄 Data Flow Architecture

### 1. State Management
```
User Interaction → UI Component → Service → State Update → UI Refresh
```

**Example: Sending a Message**
1. User types message in `MessageInput`
2. `MessageInput` calls `ChatService.sendMessage()`
3. `ChatService` updates conversation state
4. `Provider` notifies listening widgets
5. UI rebuilds with new message

### 2. Service Layer Architecture
```
UI Layer → Service Layer → External APIs → Data Storage
```

**Service Responsibilities:**
- **AuthService**: User authentication and session management
- **ChatService**: Conversation and message management
- **OllamaService**: LLM model interaction
- **IPCChatService**: Inter-process communication

### 3. Model Layer
```
JSON Data ↔ Dart Models ↔ UI Components
```

**Model Features:**
- JSON serialization/deserialization
- Immutable data structures
- Copy-with methods for updates
- Validation and error handling

## 🔌 Integration Points

### External Service Integration

#### 1. Ollama Integration
```dart
// Platform-aware connection
if (kIsWeb) {
  // Use streaming proxy for web
  await _connectViaProxy();
} else {
  // Direct connection for desktop
  await _connectDirect('localhost:11434');
}
```

#### 2. Auth0 Integration
```dart
// Configuration
const auth0Config = {
  'domain': 'dev-xafu7oedkd5wlrbo.us.auth0.com',
  'clientId': 'H10eY1pG9e2g6MvFKPDFbJ3ASIhxDgNu',
  'audience': 'https://api.cloudtolocalllm.online',
};
```

#### 3. System Tray Integration
```dart
// Desktop-only feature with graceful degradation
if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
  await _initializeSystemTray();
}
```

## 🚀 Deployment Architecture

### Development Environment
```
Local Development → Flutter Hot Reload → Local Testing
```

### Production Deployment
```
Source Code → Flutter Build → Package Creation → Distribution
```

**Build Targets:**
- **Linux Desktop**: AppImage, DEB package, AUR package
- **Web**: Static files for nginx deployment
- **Future**: Windows, macOS support

### Container Architecture (VPS Deployment)
```
nginx (Reverse Proxy) → Flutter Web App → API Backend
```

## 🔒 Security Architecture

### Authentication Flow
```
User Login → Auth0 → JWT Token → API Requests → Token Validation
```

### Data Security
- **Local Storage**: Encrypted conversation data
- **Network**: HTTPS/WSS for all communications
- **API**: JWT-based authentication
- **Desktop**: Non-root container execution

## 📈 Scalability Considerations

### Horizontal Scaling
- **Stateless Services**: Services can be replicated
- **Shared Library**: Consistent behavior across instances
- **Modular Apps**: Independent scaling of different features

### Performance Optimization
- **Lazy Loading**: Components loaded on demand
- **State Management**: Efficient state updates with Provider
- **Platform Optimization**: Platform-specific optimizations

## 🔧 Development Guidelines

### Code Organization
1. **Feature-Based Structure**: Group related functionality
2. **Layer Separation**: Clear boundaries between UI, business logic, and data
3. **Dependency Injection**: Use Provider for service injection

### Import Conventions
```dart
// External packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Shared library
import 'package:cloudtolocalllm_shared/cloudtolocalllm_shared.dart';

// Local imports (relative paths)
import '../models/conversation.dart';
import '../services/chat_service.dart';
```

### Error Handling Strategy
```dart
try {
  await service.performOperation();
} catch (e) {
  logger.error('Operation failed', e);
  _showErrorToUser(e.toString());
}
```

## 🧪 Testing Strategy

### Unit Testing
- **Models**: Data validation and serialization
- **Services**: Business logic and API integration
- **Utilities**: Helper functions and validators

### Integration Testing
- **Service Integration**: Multiple services working together
- **UI Integration**: User workflows and navigation

### Platform Testing
- **Desktop**: Linux AppImage testing
- **Web**: Browser compatibility testing
- **Mobile**: Future mobile platform testing

## 📚 Future Architecture Enhancements

### Planned Improvements
1. **Microservices**: Split large services into smaller, focused services
2. **Event-Driven Architecture**: Implement event bus for loose coupling
3. **Plugin System**: Allow third-party extensions
4. **Multi-Tenant Support**: Support multiple user accounts
5. **Offline Support**: Local data synchronization

### Technology Roadmap
- **State Management**: Consider Riverpod for advanced state management
- **Database**: Add local database for conversation persistence
- **Real-time**: WebSocket integration for real-time features
- **AI Integration**: Support for multiple LLM providers
