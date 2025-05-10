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

The CloudToLocalLLM VPS deployment, specifically the `webapp` service, handles SSL termination. Here's an overview of the SSL strategy (see `docs/DEPLOYMENT.MD` for full details):

1.  **Self-Signed Certificates (Initial Default for `webapp` container)**:
    *   For ease of initial setup, the `webapp` Docker image is configured to generate and use self-signed SSL certificates by default.
    *   This allows the service to start up with HTTPS immediately without external dependencies.
    *   Browsers will show a warning for self-signed certificates; this is expected for local development or if you haven't configured a public certificate yet.

2.  **Let's Encrypt (Recommended for Public Servers)**:
    *   Free, automated certificates from Let's Encrypt.
    *   Requires your domain to be correctly pointed to your VPS.
    *   The `docs/DEPLOYMENT.MD` guide explains how to configure the system to use Let's Encrypt, typically involving the `certbot-service`.

3.  **Commercial/Wildcard SSL Certificates**: 
    *   Suitable for production environments, especially with multiple subdomains.
    *   Covers all subdomains (e.g., `*.cloudtolocalllm.online`).
    *   Requires purchasing a certificate and configuring Nginx to use it (see `docs/DEPLOYMENT.MD`).

See [DEPLOYMENT.MD](docs/DEPLOYMENT.md) for detailed SSL configuration instructions.

## 🛠️ Prerequisites

- Flutter SDK (3.0.0 or higher recommended)
- Dart SDK (3.0.0 or higher recommended)
- (Optional) Ollama or LM Studio installed locally. Ollama can be installed via its desktop application (Windows, macOS, Linux) or run via Docker. For server/VPS deployments, ensure Ollama is not directly exposed to the internet without proper security measures.

## 🚀 Getting Started

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/thrightguy/CloudToLocalLLM.git
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
- [VPS_DEPLOYMENT.md](docs/VPS_DEPLOYMENT.md): Specific guide for VPS deployments (REVIEW for current accuracy, especially regarding `docker_startup_vps.sh`).
- [DEPLOYMENT_INSTRUCTIONS.md](docs/DEPLOYMENT_INSTRUCTIONS.md): Step-by-step deployment instructions (REVIEW for redundancy with other deployment docs).
- [RENDER_DEPLOYMENT.md](docs/RENDER_DEPLOYMENT.md): Guide for deploying on Render (REVIEW for current relevance).
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
*Historical Note: The `cloud` folder, previously used for separate cloud service components, is now deprecated. All development, documentation, and deployment for cloud-related features and the local application are managed from this main project root. The core application is a Flutter/Dart project. For any cloud-related code or deployment details, refer to the main project and this README.*
---

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [Ollama](https://ollama.ai/)
- [LM Studio](https://lmstudio.ai/)

## Static Portal Files (REVIEW: Is this still the process, or are all static assets part of the Flutter web build in the webapp container?)

To update the static portal files (e.g., `index.html`, `login.html`, `theme.css`):

1.  **Upload changed files to the VPS:**
    Replace `~/.ssh/id_rsa` with the path to your SSH key if different.
    ```bash
    scp -i ~/.ssh/id_rsa index.html root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/index.html
    scp -i ~/.ssh/id_rsa login.html root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/login.html
    scp -i ~/.ssh/id_rsa css/theme.css root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/css/theme.css
    ```

    > ⚠️ **Do NOT copy files directly into the container.**
    > Any files placed in `/usr/share/nginx/html` inside the container will be overwritten by the contents of `/opt/cloudtolocalllm/portal/` on the host.

    No container restart is needed for static file changes.

## Deployment (REVIEW: Consolidate with /docs/DEPLOYMENT.md and ensure VPS script `scripts/setup/docker_startup_vps.sh` is the primary documented method for VPS)

### Dart Deployment Tool (REVIEW: Is this tool (`tools/deploy.dart`) still maintained/used or replaced by `admin_control_daemon` + `docker_startup_vps.sh`?)

We provide a unified Dart-based tool for deploying and managing the CloudToLocalLLM portal:

```bash
# Install dependencies
dart pub add args path

# Deploy with default configuration
dart tools/deploy.dart deploy
# ... (other commands from original README) ...
dart tools/deploy.dart --help
```

Using this tool eliminates the need for multiple shell scripts and provides a consistent deployment process.

## System Daemon Management (REVIEW: Ensure this aligns with `admin_control_daemon` and `docker_startup_vps.sh`. Is `cloudctl` still a thing?)

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
- `/etc/systemd/system/cloudtolocalllm.service`: Main service (REVIEW: How does this relate to the Dockerized setup managed by `admin_control_daemon`?)
- `/etc/systemd/system/cloudtolocalllm-monitor.service`: Monitoring service (if enabled)

## Updating Live Site Files (Nginx Container) (REVIEW: This seems to refer to a generic nginx setup. For this project, the `webapp` container serves the Flutter web build. Is this section still relevant, or does it describe an old process?)

All live HTML, CSS, and static files for your site are served from:

```
/opt/cloudtolocalllm/portal/
```
**on the host**. This directory is bind-mounted into the running `nginx-proxy` container at `/usr/share/nginx/html`.

**To update your site:**
1. Edit your HTML or CSS files locally.
2. Upload them to `/opt/cloudtolocalllm/portal/` on your VPS.
   Example using `scp`:
   ```bash
   scp -i ~/.ssh/your_ssh_key localfile.html user@your_vps_ip:/opt/cloudtolocalllm/portal/localfile.html
   ```
   (Replace `~/.ssh/your_ssh_key`, `localfile.html`, `user@your_vps_ip` accordingly)
3. Nginx will automatically serve the updated files. No container restart is needed.
