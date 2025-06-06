# CloudToLocalLLM - Modular Application Architecture

This directory contains the modular Flutter application architecture for CloudToLocalLLM, designed to provide better separation of concerns, code reusability, and maintainability.

## 📁 Directory Structure

```
apps/
├── README.md                 # This file - overview of modular architecture
├── chat/                     # Main chat application
│   ├── lib/
│   │   ├── main.dart        # Entry point for chat app
│   │   ├── main_chat.dart   # Alternative entry point
│   │   ├── screens/         # UI screens (home, login, settings)
│   │   ├── components/      # Reusable UI components
│   │   ├── services/        # Business logic and API services
│   │   ├── models/          # Data models specific to chat app
│   │   ├── config/          # Configuration files (theme, router, etc.)
│   │   └── utils/           # Utility functions
│   ├── pubspec.yaml         # Dependencies for chat app
│   └── assets/              # Chat app specific assets
├── shared/                   # Shared library for common functionality
│   ├── lib/
│   │   ├── cloudtolocalllm_shared.dart  # Main export file
│   │   ├── models/          # Shared data models
│   │   ├── services/        # Shared services
│   │   ├── utils/           # Shared utilities
│   │   └── config/          # Shared configuration
│   └── pubspec.yaml         # Dependencies for shared library
└── main/                     # Future: Main application (if needed)
```

## 🏗️ Architecture Overview

### Modular Design Principles

1. **Separation of Concerns**: Each app has its own specific functionality
2. **Code Reusability**: Shared components are centralized in the `shared` library
3. **Independent Development**: Apps can be developed and tested independently
4. **Scalability**: Easy to add new applications or features

### Current Applications

#### Chat Application (`apps/chat/`)
- **Purpose**: Main chat interface for interacting with local LLMs
- **Features**: 
  - Real-time chat with Ollama models
  - Conversation management
  - Model selection and configuration
  - Authentication integration
  - System tray integration (desktop)

#### Shared Library (`apps/shared/`)
- **Purpose**: Common functionality shared across all applications
- **Contains**:
  - Data models (Conversation, Message, etc.)
  - Shared services and utilities
  - Common configuration
  - Reusable components

## 🔧 Development Workflow

### Setting Up Development Environment

1. **Install Dependencies** (from each app directory):
   ```bash
   cd apps/chat && flutter pub get
   cd ../shared && flutter pub get
   ```

2. **Build Shared Library** (when models change):
   ```bash
   cd apps/shared
   flutter packages pub run build_runner build
   ```

3. **Run Chat Application**:
   ```bash
   cd apps/chat
   flutter run
   ```

### Import Path Conventions

#### Within Chat App
```dart
// Local imports (same app)
import '../models/conversation.dart';
import '../services/chat_service.dart';
import '../config/theme.dart';

// Shared library imports
import 'package:cloudtolocalllm_shared/cloudtolocalllm_shared.dart';
```

#### Within Shared Library
```dart
// Internal shared library imports
import '../models/message.dart';
import '../utils/logger.dart';
```

### Adding New Features

1. **App-Specific Features**: Add to the relevant app directory
2. **Shared Features**: Add to the shared library and export via `cloudtolocalllm_shared.dart`
3. **New Applications**: Create a new directory under `apps/`

## 📦 Dependencies

### Chat App Dependencies
- `flutter`: UI framework
- `provider`: State management
- `go_router`: Navigation
- `cloudtolocalllm_shared`: Shared library (local dependency)

### Shared Library Dependencies
- `flutter`: Base framework
- `json_annotation`: JSON serialization
- `build_runner`: Code generation
- `json_serializable`: JSON model generation

## 🚀 Build and Deployment

### Development Build
```bash
cd apps/chat
flutter build linux --debug
```

### Production Build
```bash
cd apps/chat
flutter build linux --release
```

### Testing
```bash
cd apps/chat
flutter test

cd ../shared
flutter test
```

## 📋 Migration Notes

This modular architecture was migrated from a monolithic structure to provide:

1. **Better Organization**: Clear separation between app-specific and shared code
2. **Improved Maintainability**: Easier to locate and modify specific functionality
3. **Enhanced Reusability**: Shared components can be used across multiple apps
4. **Independent Development**: Teams can work on different apps simultaneously

### Key Changes Made
- Moved app-specific code from root `lib/` to `apps/chat/lib/`
- Created shared library in `apps/shared/`
- Updated import paths throughout the codebase
- Fixed all linting issues and dependency conflicts
- Maintained backward compatibility with existing functionality

## 🔍 Troubleshooting

### Common Issues

1. **Import Errors**: Ensure shared library is built with `build_runner`
2. **Dependency Conflicts**: Run `flutter pub get` in each app directory
3. **Path Issues**: Use relative imports for local files, package imports for shared library

### Debugging Tips

1. **Check Import Paths**: Verify all imports use correct relative or package paths
2. **Rebuild Shared Library**: Run build_runner when shared models change
3. **Clean Build**: Use `flutter clean` and `flutter pub get` to reset dependencies

## 📚 Next Steps

1. **Add More Applications**: Consider creating separate apps for different use cases
2. **Enhance Shared Library**: Add more common utilities and components
3. **Improve Documentation**: Add inline code comments and API documentation
4. **Testing Strategy**: Implement comprehensive testing for both apps and shared library
