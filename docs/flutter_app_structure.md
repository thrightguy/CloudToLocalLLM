# Flutter App Structure

```
cloudtolocalllm/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/                      # Configuration files
│   │   ├── app_config.dart          # App settings and configs
│   │   └── theme.dart               # App theme
│   ├── models/                      # Data models
│   │   ├── llm_model.dart           # LLM model class
│   │   ├── message.dart             # Chat message class
│   │   ├── user.dart                # User profile class
│   │   └── conversation.dart        # Conversation class
│   ├── services/                    # Business logic services
│   │   ├── ollama_service.dart      # Communicates with Ollama API
│   │   ├── auth_service.dart        # Handles authentication
│   │   ├── tunnel_service.dart      # Manages tunnel for remote access
│   │   ├── cloud_service.dart       # Handles cloud communication
│   │   └── storage_service.dart     # Local data persistence
│   ├── providers/                   # State management
│   │   ├── llm_provider.dart        # LLM state management
│   │   ├── auth_provider.dart       # Authentication state
│   │   └── settings_provider.dart   # App settings state  
│   ├── screens/                     # App screens
│   │   ├── home_screen.dart         # Main screen
│   │   ├── chat_screen.dart         # LLM chat interface
│   │   ├── models_screen.dart       # Model management
│   │   ├── settings_screen.dart     # App settings
│   │   ├── login_screen.dart        # User login
│   │   └── account_screen.dart      # User account
│   ├── widgets/                     # Reusable UI components
│   │   ├── chat_message.dart        # Message bubble
│   │   ├── model_selector.dart      # LLM model dropdown
│   │   ├── prompt_input.dart        # Text input for prompts
│   │   └── response_card.dart       # Display for LLM responses
│   └── utils/                       # Utility functions
│       ├── api_helpers.dart         # API communication helpers
│       ├── logger.dart              # Logging utility
│       └── validators.dart          # Input validation
└── windows/
    └── runner/                      # Windows-specific code
        ├── ollama_installer.cpp     # Optional Ollama installation helper
        └── system_tray.cpp          # System tray integration
```