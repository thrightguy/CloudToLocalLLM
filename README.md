# CloudToLocalLLM: Your Personal AI Powerhouse 🌩️💻

Run powerful Large Language Models (LLMs) directly on your machine and seamlessly sync your conversations to the cloud. Experience the best of local control and cloud convenience.

## ✨ Features

- Run LLMs locally using Ollama or LM Studio
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
> - Cloud storage is subject to our [Privacy Policy](docs/PRIVACY.md) and [Terms of Service](docs/TERMS.md)

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

## Planned Premium Features

The following premium features are planned for future releases. Some aspects may be available during development for testing purposes:

- **Cloud LLM Access**: Access to leading models like OpenAI (GPT-4o, GPT-4 Turbo) and Anthropic (Claude 3). *(Planned)*
- **Cloud Synchronization**: Sync conversations across devices. *(Partially available for testing)*
- **Remote Access**: Access your local LLM from anywhere. *(Partially available for testing)*
- **Advanced Model Management**: Tools for optimizing model performance. *(Partially available for testing)*

> For more details about upcoming premium features and their development status, see [PREMIUM_FEATURES.md](docs/PREMIUM_FEATURES.md)

For instructions on self-hosting CloudToLocalLLM, including SSL setup, prerequisites, and advanced deployment, please see our [Self-Hosting Guide](docs/SELF_HOSTING.md).

## 🚀 Getting Started

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

## 🏗️ Project Structure

- `lib/`: Main Flutter application code (client-side UI and logic).
- `admin_control_daemon/`: Dart-based daemon for managing the application stack on a server.
  - `bin/server.dart`: Entrypoint for the admin daemon.
- `admin-ui/`: Vue.js based admin interface for interacting with the `admin_control_daemon`. (REVIEW: Is this still actively used and maintained, or has it been superseded by direct API calls or other UIs?)
- `assets/`: Global assets for the Flutter application (e.g., images, icons).
- `config/`: Configuration files for various parts of the stack.
  - `docker/`: Contains Dockerfiles (e.g., `Dockerfile.admin_daemon`, `Dockerfile.web`) and Docker Compose files (e.g., `docker-compose.yml`, `docker-compose.admin.yml`) for defining and orchestrating services.
  - `nginx/`: Nginx configuration templates (e.g., `nginx.conf`) used by the `webapp` service.
  - `systemd/`: Example systemd service files. (REVIEW: Are these still relevant with the Docker-centric deployment via `admin_control_daemon`?)
- `scripts/`: Shell scripts for various tasks.
  - `setup/`: Scripts like `docker_startup_vps.sh` for initializing the VPS environment.
  - `release/`, `build/`, `deploy/`: Other utility scripts. (REVIEW: Consolidate or document purpose clearly).
- `docs/`: Detailed documentation for different aspects of the project.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Platform-specific code and build configurations for the Flutter application.
- `tunnel_service/`: (Appears to be a separate Dart project for ngrok-like tunneling. REVIEW: Document its role and integration, or remove if deprecated). Found in `backend/tunnel_service/`.
- `auth_service/`: (Appears to be a separate Dart project. REVIEW: Document its role, likely related to FusionAuth, or remove if deprecated).
- `backend/`: Contains backend services like `tunnel_service`.

## 📚 Documentation

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

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [Ollama](https://ollama.ai/)
- [LM Studio](https://lmstudio.ai/)
- [FusionAuth](https://fusionauth.io/)

## Security: Running Containers as Non-Root

All custom containers (webapp, admin-daemon, cloud, netdata, etc.) are configured to run as a non-root user by default using `user: "1000:1000"` in their respective docker-compose files. This improves security and compatibility.

- If your main non-root user has a different UID/GID, update the `user:` field accordingly.
- Official third-party images (like postgres, fusionauth) are not overridden.
- If you encounter permission issues, ensure the mapped volumes are owned by the correct UID/GID on the host.