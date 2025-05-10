# Flutter App Structure

This document outlines the general structure of the Flutter application's `lib` directory, which contains the core Dart code for the CloudToLocalLLM client application.

```
cloudtolocalllm/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/                      # Configuration files
│   │   ├── app_config.dart          # App settings, feature flags, API keys, etc.
│   │   └── theme.dart               # App theme, colors, and styles.
│   ├── models/                      # Data models/classes (e.g., for conversations, messages, users).
│   │   ├── llm_model.dart           # Represents an LLM model.
│   │   ├── message.dart             # Represents a single chat message.
│   │   ├── user.dart                # Represents a user profile.
│   │   └── conversation.dart        # Represents a chat conversation.
│   ├── services/                    # Business logic and communication with external services/APIs.
│   │   ├── ollama_service.dart      # Interacts with a local Ollama instance.
│   │   ├── auth_service.dart        # Handles user authentication (e.g., with FusionAuth).
│   │   ├── tunnel_service.dart      # Manages a tunnel for remote access (if feature is enabled).
│   │   ├── cloud_service.dart       # Communicates with backend cloud services for synchronization, etc.
│   │   └── storage_service.dart     # Handles local data persistence (e.g., using shared_preferences or sqflite).
│   ├── providers/                   # State management (e.g., using Riverpod or Provider).
│   │   ├── llm_provider.dart        # Manages LLM-related state (selected models, ongoing generation).
│   │   ├── auth_provider.dart       # Manages authentication state (current user, login status).
│   │   └── settings_provider.dart   # Manages application settings state.
│   ├── screens/                     # UI screens/pages of the application.
│   │   ├── home_screen.dart         # Main screen after login, possibly showing conversations.
│   │   ├── chat_screen.dart         # Screen for interacting with an LLM.
│   │   ├── models_screen.dart       # Screen for managing/downloading LLM models.
│   │   ├── settings_screen.dart     # Screen for application settings.
│   │   ├── login_screen.dart        # Screen for user login/registration.
│   │   └── account_screen.dart      # Screen for managing user account details.
│   ├── widgets/                     # Reusable UI components used across multiple screens.
│   │   ├── chat_message_bubble.dart # Widget for displaying a single chat message.
│   │   ├── model_selector_dropdown.dart # Dropdown for selecting an LLM model.
│   │   ├── prompt_input_field.dart  # Text input field for user prompts.
│   │   └── response_display_card.dart # Widget for displaying LLM responses.
│   └── utils/                       # Utility functions and helper classes.
│       ├── api_client.dart          # Helper for making HTTP API calls.
│       ├── logger.dart              # Logging utility for the app.
│       └── form_validators.dart     # Input validation functions for forms.
└── windows/                         # Windows-specific platform code.
    └── runner/
        ├── ollama_installer.cpp     # (Implementation Detail) Optional helper for Ollama installation on Windows.
        └── system_tray.cpp          # (Implementation Detail) Code for Windows system tray integration.
```

Note: The file names above are illustrative. Actual names and organization may vary slightly. This structure aims to follow common Flutter best practices for separation of concerns.