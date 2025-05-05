# CloudToLocalLLM

> **Note:** The `cloud` folder is now deprecated. All development, documentation, and deployment for the cloud and local apps is now managed from the main project root. The main application is a Flutter/Dart project. For any cloud-related code or deployment, refer to the main project and this README.

A Flutter application that allows you to run LLMs locally and sync your conversations with the cloud.

## Features

- Run LLMs locally using Ollama (desktop Linux or WSL2 only) or LM Studio
- Hardware detection for optimal model recommendations
- Support for latest models (Llama 3, Gemma 3, Phi-3, Mistral, etc.)
- Optional cloud synchronization of conversations (premium feature)
- Remote access to your local LLM
- Modern, responsive UI
- Cross-platform support

## Hardware Detection & Model Recommendations

CloudToLocalLLM automatically detects your hardware capabilities and recommends appropriate models:

- **System RAM Detection**: Identifies available system memory
- **GPU Detection**: Detects NVIDIA, AMD, and Intel GPUs when available
- **VRAM Analysis**: Measures available VRAM for optimal model selection
- **Smart Recommendations**: Suggests models based on your specific hardware profile

> For detailed information about hardware detection and model recommendations, see [OLLAMA_INTEGRATION.md](docs/OLLAMA_INTEGRATION.md)

## Data Storage and Privacy

### Local Storage (Default)
- All conversations and data are stored locally by default
- No data is sent to the cloud unless explicitly enabled
- Full control over your data and privacy

### Cloud Storage (Premium)
> **Important Security Warning**: Cloud storage is a premium feature that requires careful consideration:
> - Your data is encrypted but stored on our servers
> - If you lose your access code, we CANNOT recover your data
> - We recommend keeping a secure backup of your access code
> - Cloud storage is subject to our [Privacy Policy](PRIVACY.md) and [Terms of Service](TERMS.md)

## Window and System Tray Behavior

The application implements a user-friendly window management system:

- **Startup**: The main window is always visible when the application starts
- **System Tray**: A persistent system tray icon provides quick access to:
  - Show/Hide main window
  - Check LLM status
  - Manage tunnel connection
  - Exit application
- **Window Controls**:
  - Close button (X) minimizes to system tray
  - Minimize button minimizes to system tray
  - System tray icon restores the window when clicked

## Premium Features (Currently Free During Testing)

During development, all premium features are available for free to facilitate testing:

- **Cloud LLM Access**: OpenAI (GPT-4o, GPT-4 Turbo) and Anthropic (Claude 3) models
- **Cloud Synchronization**: Sync conversations across devices
- **Remote Access**: Access your local LLM from anywhere
- **Advanced Model Management**: Tools for optimizing model performance

> For more details about premium features, see [PREMIUM_FEATURES.md](docs/PREMIUM_FEATURES.md)

## SSL Configuration

The CloudToLocalLLM deployment supports two SSL certificate options:

1. **Let's Encrypt (Default)**: Automatically configured free certificates
   - Requires renewal every 90 days (automatic)
   - Each subdomain must be explicitly specified
   
2. **Wildcard SSL Certificate**: Recommended for production with multiple user subdomains
   - Covers all subdomains (*.cloudtolocalllm.online)
   - Ideal for dynamic user environments
   - Simplified maintenance
   - Available from providers like Namecheap
   - Use `wildcard_ssl_setup.ps1` for easy installation

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed SSL configuration instructions.

## Prerequisites

- Flutter SDK (2.10.0 or higher)
- Dart SDK (2.16.0 or higher)
- (Optional) Ollama or LM Studio installed locally
  - Note: Ollama should only be run on desktop Linux or Docker in WSL2, not on VPS or cloud servers

## Getting Started

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/your-username/CloudToLocalLLM.git
   ```

2. Navigate to the project directory:
   ```
   cd CloudToLocalLLM
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Run the application:
   ```
   flutter run
   ```

## Usage

### Connecting to Local LLM

1. Open the app and navigate to Settings
2. Select your LLM provider (Ollama or LM Studio)
3. Configure the IP address and port if different from default
4. Create a new conversation and start chatting!

### Model Management

CloudToLocalLLM provides comprehensive model management features:

1. **Browse Models**: View available models for your selected provider
2. **Download Models**: Pull models directly from within the app
3. **Auto-Recommendations**: Get model suggestions based on your hardware
4. **Model Information**: View model details, including size and capabilities

### Cloud Synchronization (Premium)

> **Note**: Cloud synchronization is a premium feature (free during testing) that requires:
> - A valid subscription (waived during testing)
> - Explicit opt-in
> - Secure access code setup
> - Understanding of data security implications

1. Create an account or log in
2. Enable cloud synchronization in Settings
3. Set up your secure access code
4. Your conversations will sync when you're online

### Remote Access

1. Log in to your account
2. Enable tunnel in Settings
3. Your local LLM will be accessible via the provided URL

## Project Structure

- `lib/`: Main application code
  - `config/`: Application configuration
  - `models/`: Data models
  - `providers/`: State management providers
  - `screens/`: UI screens
  - `services/`: Business logic services
  - `utils/`: Utility classes
  - `widgets/`: Reusable UI components

- `cloud/`: Cloud service components
  - Similar structure to `lib/`

## Development

### Architecture

The application follows a provider-based state management approach with a clear separation of concerns:

- **Models**: Data structures
- **Providers**: State management and business logic coordination
- **Services**: Core business logic and API interactions
- **Screens**: UI components

### Adding a New LLM Provider

1. Create a new service in `lib/services/`
2. Implement the required methods for model management and response generation
3. Update the `SettingsProvider` to include the new provider option
4. Add UI settings for the new provider in `settings_screen.dart`

## Documentation

- [OLLAMA_INTEGRATION.md](docs/OLLAMA_INTEGRATION.md): Details about Ollama integration, hardware detection, and model naming conventions
- [PREMIUM_FEATURES.md](docs/PREMIUM_FEATURES.md): Information about premium features and subscription implementation
- [DEPLOYMENT.md](DEPLOYMENT.md): Deployment and infrastructure setup instructions
- [PRIVACY.md](PRIVACY.md): Privacy policy
- [TERMS.md](TERMS.md): Terms of service

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [Ollama](https://ollama.ai/)
- [LM Studio](https://lmstudio.ai/)

## Updating Live Site Files (Nginx Container)

All live HTML, CSS, and static files for your site are served from:

```
/opt/cloudtolocalllm/portal/
```
**on the host**. This directory is bind-mounted into the running `nginx-proxy` container at `/usr/share/nginx/html`.

**To update your site:**
1. Edit your HTML or CSS files locally.
2. Upload them to `/opt/cloudtolocalllm/portal/` on the host server.

**Example commands:**

```
scp -i ~/.ssh/id_rsa index.html root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/index.html
scp -i ~/.ssh/id_rsa login.html root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/login.html
scp -i ~/.ssh/id_rsa css/theme.css root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/css/theme.css
```

> ⚠️ **Do NOT copy files directly into the container.**
> Any files placed in `/usr/share/nginx/html` inside the container will be overwritten by the contents of `/opt/cloudtolocalllm/portal/` on the host.

No container restart is needed for static file changes.
