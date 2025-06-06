# CloudToLocalLLM

**Bridge the gap between cloud AI and local control**

CloudToLocalLLM is a comprehensive solution that enables seamless interaction with both cloud-based and local Large Language Models (LLMs). Whether you're using OpenAI's GPT models through our cloud proxy or running Ollama locally, CloudToLocalLLM provides a unified, secure, and user-friendly interface.

**Website: [https://cloudtolocalllm.online](https://cloudtolocalllm.online)**

## � Key Features

- **🔄 Dual Connectivity**: Seamlessly switch between cloud and local LLM providers
- **🔒 Privacy-First**: Your data stays secure with optional local-only mode
- **🖥️ Cross-Platform**: Available on Linux, Windows, and macOS
- **🎨 Modern UI**: Clean, intuitive interface built with Flutter
- **⚡ Real-time Streaming**: Live response streaming for natural conversations
- **🔧 Easy Setup**: Simple installation and configuration process
- **🌐 Web & Desktop**: Use in your browser or as a native desktop application
- **🖱️ System Tray**: Convenient system tray integration for quick access
- **⚙️ Settings Management**: Easy configuration of connections and preferences
- **🧪 Model Testing**: Built-in tools to test and validate local Ollama models

## 🏗️ 3-App Modular Flutter-Only Architecture

CloudToLocalLLM features a **unified Flutter-only architecture** with three independent applications for optimal modularity and system integration:

### Directory Structure
```
apps/
├── chat/                     # Main ChatGPT-like interface
│   ├── lib/                  # Flutter app source code
│   ├── pubspec.yaml         # App-specific dependencies
│   └── assets/              # Chat app assets
├── tray/                     # System tray service
│   ├── lib/                  # Flutter tray implementation
│   ├── pubspec.yaml         # Tray dependencies (tray_manager)
│   └── assets/              # Monochrome tray icons
├── settings/                 # Connection management & Ollama testing
│   ├── lib/                  # Flutter settings UI
│   ├── pubspec.yaml         # Settings dependencies
│   └── assets/              # Settings app assets
└── shared/                   # Shared library
    ├── lib/                  # Common models and utilities
    └── pubspec.yaml         # Shared dependencies
```

### **MANDATORY: Context7 Documentation Requirement**

**Before implementing any external libraries, frameworks, or APIs:**
1. **ALWAYS** use `resolve-library-id_context7` to find the correct library ID
2. **ALWAYS** use `get-library-docs_context7` to get current documentation
3. This ensures proper usage, correct parameters, and current best practices
4. **NO EXCEPTIONS** - this prevents implementation errors and deprecated usage

### Key Benefits
- **Separation of Concerns**: App-specific vs shared functionality
- **Code Reusability**: Shared models and services across applications
- **Independent Development**: Teams can work on different apps simultaneously
- **Better Maintainability**: Easier to locate and modify specific functionality

### Import Conventions
```dart
// Local imports (within same app)
import '../models/conversation.dart';
import '../services/chat_service.dart';

// Shared library imports
import 'package:cloudtolocalllm_shared/cloudtolocalllm_shared.dart';
```

For detailed architecture information, see:
- [Modular Architecture Overview](apps/README.md)
- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Migration Guide](docs/MIGRATION_GUIDE.md)

## ✨ Features

- Run LLMs locally using Ollama or LM Studio
- Hardware detection for optimal model recommendations
- Support for latest models (Llama 3, Gemma 3, Phi-3, Mistral, etc.)
- Optional cloud synchronization of conversations (premium feature)
- Remote access to your local LLM
- Modern, responsive UI
- Cross-platform support

## 📸 Screenshots & Visual Guide

CloudToLocalLLM provides a modern, intuitive interface across all platforms. This visual guide demonstrates the key features and user experience that make CloudToLocalLLM the premier solution for local and cloud LLM management.

### 🖥️ **Desktop Application Experience**

#### **Main Chat Interface**
<img src="docs/app_screenshots/cloudtolocalllm_linux_chat.png" alt="CloudToLocalLLM Linux desktop chat interface showing modern dark theme with conversation history, message input, and model selection" width="800">

*Professional chat interface featuring Material Design 3 dark theme, conversation management, and seamless local LLM integration. The interface provides real-time streaming responses with syntax highlighting and markdown support.*

#### **Authentication Flow**
<img src="docs/app_screenshots/cloudtolocalllm_linux_login.png" alt="CloudToLocalLLM authentication screen with Auth0 integration showing secure login process" width="800">

*Secure authentication powered by Auth0 with enterprise-grade security. The clean, professional login interface supports SSO, MFA, and seamless token management for both local and cloud features.*

### 🌐 **Web Application Interface**

#### **Cross-Platform Web Experience**
<img src="docs/app_screenshots/cloudtolocalllm_web_chat.png" alt="CloudToLocalLLM web application showing responsive design and full feature parity with desktop version" width="800">

*Responsive web application providing full feature parity with the desktop version. Access your local and cloud LLMs from any browser with the same professional interface and functionality.*

#### **Comprehensive Settings Management**
<img src="docs/app_screenshots/cloudtolocalllm_web_settings.png" alt="CloudToLocalLLM settings panel displaying connection management, model configuration, and premium feature controls" width="800">

*Advanced settings panel for complete system configuration. Manage local Ollama connections, cloud proxy settings, authentication preferences, and premium features through an intuitive interface.*

### 🔧 **System Integration Features**

#### **Enhanced System Tray Architecture**
*[Screenshot: System tray context menu showing connection status, quick actions, and authentication-aware options] - Coming Soon*

The Enhanced System Tray Architecture provides:
- **Independent Operation**: Python-based daemon with crash isolation
- **Universal Connection Management**: Unified broker for local and cloud connections
- **Real-time Status**: Live connection monitoring with visual indicators
- **Quick Actions**: Show/Hide window, Settings access, Connection status, Quit

#### **Installation Process**
*[Screenshot: Platform-specific installation screens showing AppImage, Windows installer, and AUR package installation] - Coming Soon*

Streamlined installation across all platforms:
- **Linux**: AppImage (portable), AUR package (Arch), DEB package (Ubuntu/Debian)
- **Windows**: Automated installer with Docker/Ollama integration
- **Self-Hosting**: Complete VPS deployment with SSL configuration

### ⚙️ **Advanced Configuration**

#### **Connection Management**
*[Screenshot: Connection broker interface showing local Ollama and cloud proxy configuration with health monitoring] - Coming Soon*

Advanced connection management features:
- **Automatic Discovery**: Detects and connects to available LLM services
- **Health Monitoring**: Continuous connection health checks with automatic recovery
- **Failover Logic**: Intelligent switching between local and cloud connections
- **Performance Optimization**: Connection pooling and request optimization

#### **Model Management Interface**
*[Screenshot: Model management screen showing available models, download progress, and hardware recommendations] - Coming Soon*

Comprehensive model management:
- **Hardware Detection**: Automatic GPU and memory detection for optimal recommendations
- **Model Browser**: Browse and download models directly from the interface
- **Performance Analytics**: Real-time performance monitoring and optimization
- **Custom Models**: Support for custom and fine-tuned model integration

### 🚀 **Premium Features Demonstration**

#### **Cloud Connectivity**
*[Screenshot: Cloud proxy connection interface showing secure tunneling and multi-tenant isolation] - Coming Soon*

Enterprise-grade cloud features:
- **Secure Tunneling**: Encrypted connections to cloud-hosted LLMs
- **Multi-Tenant Architecture**: Complete user isolation with zero data persistence
- **Load Balancing**: Intelligent routing for optimal performance
- **Enterprise Security**: JWT authentication with automatic token management

#### **Cross-Platform Synchronization**
*[Screenshot: Synchronization interface showing conversation sync across devices with encryption status] - Coming Soon*

Advanced synchronization capabilities:
- **Conversation Sync**: Seamless conversation history across all devices
- **Settings Synchronization**: Preferences and configuration sync
- **Secure Encryption**: End-to-end encryption for all synchronized data
- **Offline Support**: Full functionality with automatic sync when online

### 📱 **Responsive Design**

#### **Mobile-Optimized Interface**
*[Screenshot: Mobile browser view showing responsive design with touch-optimized controls] - Coming Soon*

Mobile-first responsive design:
- **Touch Optimization**: Gesture-friendly interface for mobile devices
- **Adaptive Layout**: Intelligent layout adaptation for different screen sizes
- **Performance Optimization**: Efficient resource usage on mobile devices
- **Feature Parity**: Complete functionality across all device types

---

### 🎯 **Visual Design Principles**

CloudToLocalLLM's interface follows modern design principles established during our documentation consolidation:

- **Professional Aesthetics**: Clean, enterprise-ready visual design
- **Consistent Experience**: Uniform interface across all platforms and features
- **Accessibility**: High contrast, readable fonts, and keyboard navigation support
- **Performance**: Optimized rendering for smooth, responsive interactions

### 📸 **Contributing Screenshots**

Help improve our visual documentation! We welcome community contributions for missing screenshots:

- **System Tray Demonstrations**: Context menus, status indicators, cross-platform tray integration
- **Installation Processes**: Platform-specific installation workflows and package managers
- **Advanced Features**: Premium functionality, enterprise features, and configuration screens
- **Cross-Platform Comparisons**: Side-by-side platform comparisons and feature demonstrations

To contribute screenshots, please follow our [Contributing Guidelines](docs/USER_DOCUMENTATION/USER_GUIDE.md) and ensure screenshots meet our quality standards for resolution, clarity, and professional presentation.

## Hardware Detection & Model Recommendations

CloudToLocalLLM automatically detects your hardware capabilities and recommends appropriate models:

- **System RAM Detection**: Identifies available system memory
- **GPU Detection**: Detects NVIDIA, AMD, and Intel GPUs when available
- **VRAM Analysis**: Measures available VRAM for optimal model selection
- **Smart Recommendations**: Suggests models based on your specific hardware profile

> For detailed information about hardware detection and model recommendations, see [Features Guide](docs/USER_DOCUMENTATION/FEATURES_GUIDE.md)

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
> - Cloud storage is subject to our [Privacy Policy](docs/LEGAL/PRIVACY.md) and [Terms of Service](docs/LEGAL/TERMS.md)

## 🎛️ Enhanced System Tray Architecture

CloudToLocalLLM features an **Enhanced System Tray Architecture** that provides independent, reliable system tray functionality with universal connection management:

### Key Features
- **Independent Operation**: System tray daemon operates independently of the main Flutter app
- **Universal Connection Broker**: Handles ALL connections (local Ollama + cloud proxy) through a centralized broker
- **Crash Isolation**: Tray daemon failures don't affect the main application
- **Separate Settings Interface**: Independent configuration and monitoring GUI
- **Automatic Failover**: Intelligent switching between local and cloud connections

### System Tray Functionality
- **Persistent Tray Icon**: Always available with connection status indicators
- **Quick Actions**: Show/Hide window, Settings, Connection status, Quit
- **Authentication-Aware Menus**: Dynamic menu based on login status
- **Real-time Status**: Live connection monitoring and health checks

### Connection Management
- **Unified API**: Single interface for both local Ollama and cloud connections
- **Automatic Discovery**: Detects and connects to the best available service
- **Health Monitoring**: Continuous connection health checks with automatic recovery
- **Request Proxying**: All API calls routed through the connection broker

For detailed information about the enhanced architecture, see [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md).

## Core Features vs Premium Features

### ✅ **Core Features (Included)**
- **Basic Sync**: Conversation synchronization across devices
- **Local LLM Management**: Full Ollama and LM Studio integration
- **System Tray Integration**: Enhanced desktop experience with Python-based daemon
- **Cross-Platform Support**: Linux, Windows, macOS, and web
- **Modern UI**: Dark theme with Material Design 3

### 💎 **Premium Features (Future Paid Upgrades)**
- **Advanced Cloud Sync**: Settings and preferences synchronization across devices
- **Cloud LLM Access**: Access to leading models like OpenAI (GPT-4o, GPT-4 Turbo) and Anthropic (Claude 3)
- **Remote Access**: Secure access to your local LLM from anywhere
- **Advanced Model Management**: Performance optimization tools and analytics
- **Priority Support**: Dedicated technical support and feature requests

> For more details about upcoming premium features and their development status, see [Features Guide](docs/USER_DOCUMENTATION/FEATURES_GUIDE.md)

## 📋 Versioning Strategy

CloudToLocalLLM uses a granular build numbering system:

**Format**: `MAJOR.MINOR.PATCH+BUILD`

- **Major (x.0.0)**: Creates GitHub releases - significant changes
- **Minor (x.y.0)**: No GitHub release - feature additions
- **Patch (x.y.z)**: No GitHub release - bug fixes
- **Build (x.y.z+nnn)**: No GitHub release - incremental builds

**Examples**: `3.1.1+001` → `3.1.1+002` → `3.1.2+001` → `4.0.0+001`

For detailed information, see [Versioning Strategy](docs/DEPLOYMENT/VERSIONING_STRATEGY.md).

## 🚀 Deployment

### Multi-Container Deployment (Recommended)

Deploy all services with the new multi-container architecture:

```bash
# Full deployment with SSL setup
./scripts/deploy/deploy-multi-container.sh --build --ssl-setup

# Deploy specific services only
./scripts/deploy/deploy-multi-container.sh flutter-app
./scripts/deploy/update-service.sh static-site --no-downtime
```

### Legacy Single Container

For instructions on self-hosting CloudToLocalLLM with the legacy single container, including SSL setup, prerequisites, and advanced deployment, please see our [Self-Hosting Guide](docs/OPERATIONS/SELF_HOSTING.md).

## 📁 Project Structure

CloudToLocalLLM follows an organized directory structure for better maintainability and development:

### Core Directories
- `lib/` - Flutter application source code
- `api-backend/` - Node.js backend server
- `tray_daemon/` - System tray daemon implementation
- `web/` - Web-specific Flutter assets

### Documentation
- `docs/` - Comprehensive project documentation
  - Architecture guides, deployment instructions, troubleshooting
  - User guides, setup instructions, and API documentation

### Scripts & Automation
- `scripts/` - Organized build, deployment, and utility scripts
  - `build/` - Build scripts for different platforms
  - `deploy/` - Deployment and VPS scripts
  - `setup/` - Initial server setup scripts
  - `release/` - Release management and distribution
  - `ssl/` - SSL certificate management
  - `verification/` - Testing and verification tools

### Packaging & Distribution
- `packaging/` - Platform-specific packaging configurations
  - DEB packages, AppImage, Windows installers
- `installers/` - Installation scripts and packages
- `aur-package/` - Arch User Repository (AUR) package files

### Configuration & Infrastructure
- `config/` - Configuration files for various platforms
- `docker/` - Docker containers and build contexts
- `static_homepage/` - Project website and documentation site

### Development Tools
- `.vscode/` - VS Code workspace configuration
- `linux/`, `assets/` - Platform-specific assets and configurations

For detailed information about any component, see the respective README files in each directory.

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
- `tray_daemon/`: **Enhanced System Tray Architecture** - Independent tray daemon with universal connection management.
  - `enhanced_tray_daemon.py`: Main enhanced tray daemon with connection broker.
  - `connection_broker.py`: Universal connection broker for local and cloud services.
  - `settings_app.py`: Independent GUI for daemon configuration.
  - `start_enhanced_daemon.sh`: Startup script for the enhanced daemon.
  - `ENHANCED_ARCHITECTURE.md`: Comprehensive architecture documentation.
- `admin_control_daemon/`: Dart-based daemon for managing the application stack on a server.
  - `bin/server.dart`: Entrypoint for the admin daemon.
- `admin-ui/`: Vue.js based admin interface. (Status: Potentially for specific admin tasks, primary user interface is the Flutter app).
- `assets/`: Global assets for the Flutter application (e.g., images, icons).
- `config/`: Configuration files for various parts of the stack.
  - `docker/`: Contains Dockerfiles (e.g., `Dockerfile.admin_daemon`, `Dockerfile.web`) and Docker Compose files (e.g., `docker-compose.yml`, `docker-compose.admin.yml`).
  - `nginx/`: Nginx configuration templates (e.g., `nginx.conf`) used by the `webapp` service.
  - `systemd/`: Example systemd service files (e.g., `cloudtolocalllm.service`), primarily for scenarios where services might be run outside Docker.
- `scripts/`: Utility scripts for development, deployment, maintenance, and build tasks. See "Key Scripts Overview" below for more details.
  - `auth0/`, `deploy/`, `maintenance/`, `powershell/`, `release/`, `setup/`, `ssl/`, `utils/`, `verification/`: Subdirectories categorizing various scripts.
- `docs/`: Detailed documentation for different aspects of the project.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Platform-specific code and build configurations for the Flutter application.
- `tunnel_service/` (in `backend/`): Dart project for ngrok-like tunneling, enabling remote access.
- `auth_service/` (likely related to FusionAuth): Backend authentication service components.
- `backend/`: Contains backend services like `tunnel_service`.

## 🔧 Key Scripts Overview

This project includes a variety of scripts to automate common tasks. Here are some of the key ones:

- **Server Management & Deployment (primarily for Linux VPS):**
  - `scripts/setup_cloudllm_user.sh`: Sets up a dedicated `cloudllm` user with necessary permissions and SSH configuration on a new VPS.
  - `scripts/deploy_vps.sh`: Automates the initial deployment of the application stack to a VPS, including system checks, Docker/Docker Compose installation, UFW/Fail2ban setup, and initial application startup.
  - `scripts/manual_staging_wildcard.sh` (and its production version): Manages Let's Encrypt SSL certificate generation and renewal using Certbot with a manual DNS challenge for wildcard domains. Used for setting up HTTPS for `https://cloudtolocalllm.online` and its subdomains.
  - `scripts/fix_service.sh`: Utility to overwrite the systemd service file for `cloudtolocalllm.service` and restart it.
  - `scripts/troubleshooting_commands.sh`: A collection of useful commands for diagnosing issues on the VPS, particularly related to Docker and service logs.
- **Application Building & Packaging:**
  - `scripts/improve_windows_app.ps1` (PowerShell): Builds the Flutter Windows application and creates an Inno Setup installer. Includes features like version extraction from `pubspec.yaml` and GUID generation.
  - `PKGBUILD.template`: A template for creating an Arch Linux package (for AUR distribution) from a pre-built Flutter Linux release.
  - `scripts/generate_icons.ps1` (PowerShell) & `generate_icons.bat`: Scripts for generating application icons using ImageMagick.
- **Development & Utility:**
  - `scripts/git-push.ps1` (PowerShell): Automates common Git operations like adding, committing, and pushing changes.
  - `scripts/logging.ps1` (PowerShell): Provides log rotation functionality.
  - `scripts/ollama_service_manager.ps1` (PowerShell): Manages a locally installed Ollama service (start, stop, status).
  - `scripts/organize_scripts.ps1` (PowerShell): Helps organize scripts into subdirectories.
  - `scripts/update_references.ps1` (PowerShell): Updates references to scripts if they are moved.
  - `scripts/test_installation.ps1` (PowerShell): Contains functions to test aspects of the local setup, like Ollama API reachability.

For detailed usage, refer to the scripts themselves or related documentation.

##📦 Building Client Applications

Instructions for building and packaging client applications for different platforms:

### Windows

1.  **Prerequisites**:
    *   Flutter SDK installed and configured.
    *   Inno Setup 6 installed (e.g., from [https://jrsoftware.org/isinfo.php](https://jrsoftware.org/isinfo.php)), and `ISCC.exe` should be in your system PATH or one of the common installation locations checked by the script.
    *   A `LICENSE` file in the project root.
2.  **Build Process**:
    *   Run the `scripts/improve_windows_app.ps1` PowerShell script.
    *   This script will:
        *   Read the application version from `pubspec.yaml`.
        *   Build the Flutter Windows application (`flutter build windows`).
        *   Generate an Inno Setup script (`.iss`) file.
        *   Compile the installer using `ISCC.exe`.
        *   The resulting installer will be placed in the `installer/` directory.
3.  **Code Signing (Manual Step)**: For a trusted installation, the generated executable and installer should be signed with a valid code signing certificate. This step is typically performed manually after the build.

### Linux (AUR Package)

1.  **Prerequisites**:
    *   Flutter SDK installed and configured.
    *   Arch Linux environment with `base-devel` package group installed (for `makepkg`).
    *   A `LICENSE` file in the project root.
2.  **Build Flutter App**:
    *   Generate a release build of the Flutter Linux application:
        ```bash
        flutter build linux --release
        ```
    *   This will create the application bundle in `build/linux/x64/release/bundle/`.
3.  **Create Release Artifact**:
    *   Archive the contents of the `build/linux/x64/release/bundle/` directory into a `.tar.gz` file. The `PKGBUILD.template` expects this tarball to contain the `bundle/` directory at its root, or a single top-level directory which then contains `bundle/`. Name it appropriately, e.g., `cloudtolocalllm-linux-x64-1.3.3.tar.gz` (replace `1.3.3` with the actual version).
    *   Include the `LICENSE` file in the root of this tarball.
4.  **Host the Artifact**:
    *   Upload the created `.tar.gz` file to a publicly accessible URL (e.g., as a release asset on GitHub).
5.  **Prepare `PKGBUILD`**:
    *   Copy `PKGBUILD.template` to a new file named `PKGBUILD`.
    *   Edit `PKGBUILD`:
        *   Update the `pkgver` if the script didn't pick it up correctly (it tries to get it from `pubspec.yaml`).
        *   Replace the placeholder `source` URL with the direct download link to your hosted `.tar.gz` artifact.
        *   Calculate the `sha256sum` of your `.tar.gz` artifact (`sha256sum your-artifact.tar.gz`) and replace `'SKIP'` in the `sha256sums` array with this sum.
        *   Review and update `maintainer` and `contributor` fields.
        *   Ensure the `license` field accurately reflects your project's license. If you have a `LICENSE` file, `custom:LICENSE` is appropriate, assuming the `LICENSE` file is included in the tarball and installed by the `PKGBUILD`.
6.  **Test Locally**:
    *   In the directory containing your `PKGBUILD` file (and nothing else related to the build, to ensure a clean build):
        ```bash
        makepkg -si
        ```
    *   This will download the source, verify checksums, build the package, and install it. Test the installed application.
7.  **AUR Submission**:
    *   Once the package builds and installs correctly, you can follow the instructions on the Arch Wiki to submit it to the Arch User Repository (AUR). This involves creating an AUR account, creating a new Git repository on `aur.archlinux.org`, and pushing your `PKGBUILD` (and any other necessary files like a `.SRCINFO` file generated by `makepkg --printsrcinfo > .SRCINFO`).

## 📚 Documentation

CloudToLocalLLM features comprehensive, well-organized documentation. The documentation has been streamlined into logical topic areas for better discoverability and maintenance.

### **📋 Primary Documentation**

**🚀 Getting Started:**
- [Installation Guide](docs/INSTALLATION/INSTALLATION_GUIDE.md): Complete installation instructions for all platforms (Linux, Windows, Self-hosting)
- [User Guide](docs/USER_DOCUMENTATION/USER_GUIDE.md): Basic usage and interface overview
- [Features Guide](docs/USER_DOCUMENTATION/FEATURES_GUIDE.md): Comprehensive feature documentation, integrations, and premium capabilities

**🔧 Deployment & Operations:**
- [Complete Deployment Workflow](docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md): **THE** authoritative deployment guide with version management
- [Deployment Workflow Diagram](docs/DEPLOYMENT/DEPLOYMENT_WORKFLOW_DIAGRAM.md): Visual deployment process and troubleshooting
- [Self-Hosting Guide](docs/OPERATIONS/SELF_HOSTING.md): VPS deployment for cloud features
- [Infrastructure Guide](docs/OPERATIONS/INFRASTRUCTURE_GUIDE.md): Environment strategy, maintenance, and server setup

**🏗️ Technical Reference:**
- [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md): Complete technical architecture including enhanced tray, streaming, and containers
- [Versioning Strategy](docs/DEPLOYMENT/VERSIONING_STRATEGY.md): Version format and management strategy
- [Release Notes](docs/RELEASE/RELEASE_NOTES.md): Version history and release management

**📄 Legal & Compliance:**
- [Privacy Policy](docs/LEGAL/PRIVACY.md): Privacy policy and data handling
- [Terms of Service](docs/LEGAL/TERMS.md): Terms of service and usage agreement

### **📁 Documentation Structure**

The documentation is organized into logical topic areas:

```
docs/
├── DEPLOYMENT/     # Deployment guides and version management
├── ARCHITECTURE/   # Technical architecture documentation
├── INSTALLATION/   # Platform-specific installation guides
├── USER_DOCUMENTATION/ # User guides and feature documentation
├── OPERATIONS/     # Infrastructure and maintenance guides
├── RELEASE/        # Release notes and version history
├── LEGAL/          # Privacy policy and terms of service
└── archive/        # Archived/obsolete documentation
```

### **🔍 Quick Navigation**

- **New Users**: Start with [Installation Guide](docs/INSTALLATION/INSTALLATION_GUIDE.md) → [User Guide](docs/USER_DOCUMENTATION/USER_GUIDE.md)
- **Developers**: See [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md) → [Features Guide](docs/USER_DOCUMENTATION/FEATURES_GUIDE.md)
- **Deployers**: Follow [Complete Deployment Workflow](docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)
- **Self-Hosters**: Use [Self-Hosting Guide](docs/OPERATIONS/SELF_HOSTING.md) → [Infrastructure Guide](docs/OPERATIONS/INFRASTRUCTURE_GUIDE.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. (Note: Ensure your `LICENSE` file is up-to-date and correctly reflects your chosen license. For AUR, it's typically included in the package.)

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

## ⚙️ Troubleshooting

Here are some common troubleshooting steps:

- **Docker Container Issues:**
  - **Container not starting/restarting:**
    - Check logs: `sudo docker logs <container_name_or_id>` (e.g., `sudo docker logs cloudtolocalllm-webapp-1`)
    - Check status: `sudo docker ps -a` (look for `Exited` or `Restarting` status)
  - **Permission errors for volume mounts:** Ensure the host directories mapped into containers (especially `./certbot/conf` for SSL certificates) have the correct ownership and permissions for the user the container runs as (often UID/GID 1000 if not specified otherwise, or the `cloudllm` user for this project).
  - **`docker-compose` vs `docker compose`:** Be consistent. The newer `docker compose` (v2 plugin) is recommended. If you encounter `docker-compose: command not found`, try `docker compose`.
- **SSL Certificate Problems (Nginx/Webapp):**
  - **"No such file or directory" for `fullchain.pem` or `privkey.pem` in Nginx logs:**
    - Verify the volume mount in `docker-compose.yml`: `webapp` service should mount `./certbot/conf:/etc/letsencrypt`.
    - Check host path: `ls -l /opt/cloudtolocalllm/certbot/conf/live/cloudtolocalllm.online/` (or the path you configured Certbot to use). Ensure `fullchain.pem` and `privkey.pem` exist and are valid symlinks to files in the `../../archive/cloudtolocalllm.online/` directory.
    - If `.../live/cloudtolocalllm.online` contains actual files instead of symlinks, or if it's an `...online-0001` directory, you might need to rename/remove the incorrect `live` directory and re-run Certbot, or manually fix the symlinks (e.g., `ln -sfn ../../archive/cloudtolocalllm.online/privkey1.pem privkey.pem`).
    - Ensure correct permissions for `privkey.pem` (e.g., `640` or `644`, readable by the Nginx user inside the container).
  - **Browser SSL warnings (NET::ERR_CERT_AUTHORITY_INVALID):** If using Let's Encrypt staging certificates, this is expected. Switch to production certificates for public use.
- **Git Issues on VPS:**
  - **"dubious ownership":** Run `git config --global --add safe.directory /opt/cloudtolocalllm` as the `cloudllm` user.
  - **"cannot open '.git/FETCH_HEAD': Permission denied":** Ensure `/opt/cloudtolocalllm` and its contents are owned by the `cloudllm` user: `sudo chown -R cloudllm:cloudllm /opt/cloudtolocalllm`.
- **Flutter Web App UI Not Updating:**
  - After `git pull` on the server, you must rebuild the `webapp` Docker image: `docker compose build --no-cache webapp` (as `cloudllm`).
  - Then, recreate the container: `docker compose up -d --force-recreate webapp` (as `cloudllm`).
- **General VPS Issues:**
  - Refer to `scripts/troubleshooting_commands.sh` for a list of helpful diagnostic commands.
  - Check system logs: `journalctl -u cloudtolocalllm.service` (if using the systemd service), `dmesg`, `/var/log/syslog`.

If you encounter further issues, please check the project's issue tracker on GitHub.