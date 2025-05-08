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

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed SSL configuration instructions.

## Prerequisites

- Flutter SDK (2.10.0 or higher)
- Dart SDK (2.16.0 or higher)
- (Optional) Ollama or LM Studio installed locally
  - Note: Ollama should only be run on desktop Linux or Docker in WSL2, not on VPS or cloud servers

## Current Project Status

### Services Status (as of latest update)

#### Running Services
- **Tunnel Service**: 
  - Successfully built and running
  - Node.js Express server running on port 8080
  - Handles remote access to local LLMs

- **Auth Service**:
  - Successfully built and running
  - Handles user authentication and authorization

#### Pending Services
- **Webapp Service**:
  - Build currently failing
  - Issue: Dart/Flutter SDK version mismatch (null safety compatibility)
  - Status: Under investigation for SDK version alignment

### Next Steps
1. Resolve webapp build issues:
   - Update Dart/Flutter SDK versions
   - Ensure null safety compatibility
   - Review and update dependencies

2. Integration Testing:
   - Test tunnel service endpoints
   - Verify auth service functionality
   - Complete webapp integration once build is fixed

### Server Information
- Production Server: 162.254.34.115
- Access: SSH available for both root and cloudllm users
- Deployment: Docker Compose based deployment

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

### Dependencies and Compatibility

The project uses specific dependency versions to ensure compatibility across all platforms:

- **win32**: ^2.7.0 (must be kept under 3.0.0 for compatibility with device_info_plus)
- **device_info_plus**: ^8.2.2 (requires win32 <3.0.0)
- **path**: >=1.8.2 <2.0.0

When updating dependencies, ensure version constraints are maintained to avoid conflicts, especially between win32 and device_info_plus packages.

### Adding a New LLM Provider

1. Create a new service in `lib/services/`
2. Implement the required methods for model management and response generation
3. Update the `SettingsProvider` to include the new provider option
4. Add UI settings for the new provider in `settings_screen.dart`

## Documentation

Refer to the `docs/` directory for detailed documentation. Key documents include:

**Core Concepts & Setup:**
- [OLLAMA_INTEGRATION.md](docs/OLLAMA_INTEGRATION.md): Ollama integration, hardware detection, model naming.
- [PREMIUM_FEATURES.md](docs/PREMIUM_FEATURES.md): Premium features and subscription details.
- [CONTAINER_ARCHITECTURE.md](docs/CONTAINER_ARCHITECTURE.md): Overview of the Docker container setup.
- [FLUTTER_APP_STRUCTURE.md](docs/flutter_app_structure.md): Details on the Flutter application structure.

**Deployment & Operations:**
- [DEPLOYMENT.md](docs/DEPLOYMENT.md): General deployment and infrastructure setup.
- [VPS_DEPLOYMENT.md](docs/VPS_DEPLOYMENT.md): Specific guide for VPS deployments.
- [DEPLOYMENT_INSTRUCTIONS.md](docs/DEPLOYMENT_INSTRUCTIONS.md): Step-by-step deployment instructions.
- [RENDER_DEPLOYMENT.md](docs/RENDER_DEPLOYMENT.md): Guide for deploying on Render.
- [MAINTENANCE_SCRIPTS.md](docs/MAINTENANCE_SCRIPTS.md): Information on available maintenance scripts.

**Release & Windows Specific:**
- [RELEASE_INSTRUCTIONS.md](docs/RELEASE_INSTRUCTIONS.md): How to prepare and manage releases.
- [WINDOWS_INSTALLER_GUIDE.md](docs/WINDOWS_INSTALLER_GUIDE.md): Guide for the Windows installer.

**Development & Strategy:**
- [AUTH0_DIRECT_LOGIN.md](docs/auth0_direct_login.md): Auth0 integration details.
- [DUAL_LICENSE_STRATEGY.md](docs/DUAL_LICENSE_STRATEGY.md): Licensing information.
- [PRICING_STRATEGY.md](docs/PRICING_STRATEGY.md): Details on pricing. *(Ensure this file is added to docs/ from root)*

**Legal & Policies:**
- [PRIVACY.md](docs/PRIVACY.md): Privacy Policy. *(Ensure this file exists in docs/ or is created)*
- [TERMS.md](docs/TERMS.md): Terms of Service. *(Ensure this file exists in docs/ or is created)*

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

## Deployment

### Dart Deployment Tool

We provide a unified Dart-based tool for deploying and managing the CloudToLocalLLM portal:

```bash
# Install dependencies
dart pub add args path

# Deploy with default configuration
dart tools/deploy.dart deploy

# Deploy with beta subdomain support
dart tools/deploy.dart deploy -b

# Deploy with monitoring
dart tools/deploy.dart deploy -m

# Deploy with custom domain
dart tools/deploy.dart deploy -d example.com

# Add monitoring to existing deployment
dart tools/deploy.dart monitor

# Verify deployment
dart tools/deploy.dart verify

# Update existing deployment
dart tools/deploy.dart update

# Show help
dart tools/deploy.dart --help
```

Using this tool eliminates the need for multiple shell scripts and provides a consistent deployment process.

## System Daemon Management

After deployment, you can manage the system using the `cloudctl` command:

```
cloudctl {start|stop|restart|status|logs|update}
```

### Available Commands

- `cloudctl start`: Start all services
- `cloudctl stop`: Stop all services
- `cloudctl restart`: Restart all services
- `cloudctl status`: Check service status
- `cloudctl logs [service]`: View logs (available services: auth, web, admin, db)
- `cloudctl update`: Pull latest changes and restart services

### Service Configuration

The system uses systemd for service management. The service files are located at:

- `/etc/systemd/system/cloudtolocalllm.service`: Main service
- `/etc/systemd/system/cloudtolocalllm-monitor.service`: Monitoring service (if enabled)

## Development

### Setting Up Development Environment

1. Install Flutter SDK
2. Clone the repository
3. Run `flutter pub get` to fetch dependencies
4. Run `flutter run` to launch the application in debug mode

### Building for Production

To build the application for production:

```
flutter build <platform>
```

Where `<platform>` is one of: `apk`, `ios`, `web`, `windows`, `macos`, `linux`

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file included in the repository.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Recent Changes (May 2025)

### Improved VPS Startup Script
- The `scripts/setup/startup_vps.sh` script now prints a clear status before each step and logs all errors both to the console and the log file (`/opt/cloudtolocalllm/startup.log`).
- If any step fails, the script prints an error and exits, making troubleshooting much easier.
- Usage remains:
  ```bash
  git pull
  bash scripts/setup/startup_vps.sh
  ```

### Flutter Color API Fixes
- All usages of `Color.withValues` in the Flutter codebase have been replaced with `Color.withAlpha`, which is compatible with Flutter 3.22.0 and Dart 3.4.x.
- This resolves build errors and ensures correct alpha blending.

### Workflow
- All changes are committed and pushed to GitHub after each major fix.
- The codebase is ready for deployment after pulling the latest changes.

---

## Deployment Steps
1. SSH into your VPS and navigate to the project directory:
   ```bash
   cd /opt/cloudtolocalllm
   git pull
   bash scripts/setup/startup_vps.sh
   ```
2. The script will show detailed status and error messages as it runs.
3. If you encounter any new errors, copy the output and seek troubleshooting help.

---

## Summary for New Developers
- The startup script now provides clear, real-time status and error logging.
- All Flutter color API usage is compatible with the latest stable SDK.
- The codebase is fully committed and pushed to GitHub, ready for production deployment.
