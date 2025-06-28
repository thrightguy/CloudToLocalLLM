# CloudToLocalLLM: Your Personal AI Powerhouse 🌩️💻

[![Version](https://img.shields.io/badge/version-3.6.2-blue.svg)](https://github.com/imrightguy/CloudToLocalLLM/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.8+-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20Web-lightgrey.svg)](https://github.com/imrightguy/CloudToLocalLLM)

**Website: [https://cloudtolocalllm.online](https://cloudtolocalllm.online)**

**CloudToLocalLLM** bridges the gap between powerful cloud-based Large Language Models (LLMs) and the privacy and control of local execution. It offers a seamless, multi-tenant experience for interacting with local LLMs via a sophisticated cloud-hosted web interface and a robust system tray application.

This project is currently in **Alpha (v3.6.2)**. Expect rapid development and potential breaking changes.

## 🌟 Key Highlights (v3.6.2)

*   **Modern Multi-Container Architecture**: Ensures scalability, resilience, and maintainability. (See [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md))
*   **Unified Flutter-Native Architecture**: Single Flutter application with integrated system tray functionality, eliminating external dependencies.
*   **Multi-Tenant Streaming Proxy**: Securely connects web users to their local LLM instances via ephemeral, isolated proxy containers.
*   **Auth0 Integration**: Robust and secure authentication for web users.
*   **Comprehensive API**: For bridge communication, proxy management, and future extensions.
*   **Cross-Platform Client Support**: Linux (AppImage, AUR, Debian) and Windows desktop support (v3.6.0+).

## 🏗️ Multi-Container Architecture
CloudToLocalLLM features a modern multi-container architecture that provides:
*   **Scalability**: Easily handle multiple users and connections.
*   **Resilience**: Isolated services prevent cascading failures.
*   **Maintainability**: Clear separation of concerns simplifies development and updates.
*   **Security**: Enhanced network policies and container isolation.

Key containers include:
*   `nginx-proxy`: SSL termination and request routing.
*   `flutter-app`: The unified Flutter web application (UI, chat, marketing pages).
*   `api-backend`: Core API, authentication, and streaming proxy management.
*   `streaming-proxy` (ephemeral): Lightweight proxies for user-to-local-LLM communication.
*   `certbot`: Automated SSL certificate management.

For detailed information, see [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md). The system architecture document covers the complete unified Flutter-native implementation including the integrated system tray functionality.

## ✨ Features

### 🧠 **LLM & AI Features**
*   **Local LLM Agnostic**: Designed to work with Ollama-compatible LLMs.
*   **Model Management**: View and select available local models.
*   **Chat Interface**: Modern, responsive chat UI for interacting with your LLM.
*   **Streaming Support**: Real-time response streaming from the LLM.

### ☁️ **Cloud & Web Features**
*   **Web Application**: Access your local LLM from anywhere via a browser.
*   **Auth0 Authentication**: Secure user login and management.
*   **Multi-Tenant Design**: Isolates user data and connections.
*   **Streaming Proxy Architecture**: Securely tunnels web client requests to the correct local bridge via ephemeral, isolated proxy containers managed by the `api-backend`.

### 🔧 **System Integration Features**

#### **Unified Flutter-Native System Tray**

The Unified Flutter-Native System Tray provides:
*   **Integrated Operation**: Native Flutter system tray using `tray_manager` package.
*   **Real-time Connection Status**: Live visual indicators for Ollama and cloud connections.
*   **Context-Aware Menu**: Dynamic options based on connection and authentication state.
*   **Cross-Platform Support**: Consistent behavior across Linux, Windows, and macOS.
*   **Zero External Dependencies**: No separate daemon processes required.
*   **Instant Updates**: Direct service integration for immediate status changes.

#### **Installation Process**

Streamlined installation across all platforms:
*   **Linux**:
    *   **AppImage**: Portable, no-installation-needed package.
    *   **AUR Package**: For Arch Linux users (`cloudtolocalllm`).
    *   **Debian Package**: For Debian/Ubuntu based systems (`.deb`).
*   **Windows**: Desktop application with system tray support (v3.6.0+).
*   **macOS**: Planned for future releases.

Self-hosting the entire stack on a VPS is also a deployment option for advanced users.

## Core Features vs Premium Features

### ✅ **Core Features (Included)**
*   Local LLM connection via Ollama
*   Secure web interface for chat
*   System tray client for connection management
*   Basic conversation history (local)
*   Multi-container deployment for self-hosting

### 🚀 **Premium Features (Planned)**
*   Advanced cloud sync (settings, conversations across devices)
*   Team collaboration features
*   Priority support
*   Enhanced security & compliance options

## 📋 Versioning Strategy
CloudToLocalLLM uses a granular build numbering system:
*   **Format**: `v<major>.<minor>.<patch>+<build>` (e.g., `v3.3.1+045`)
*   **`major.minor.patch`**: Semantic versioning for core application.
*   **`build`**: Incremental build number for CI/CD.

This allows for precise tracking of releases and development builds.
For detailed information, see [Versioning Strategy](docs/DEPLOYMENT/VERSIONING_STRATEGY.md).

## 🚀 Deployment

### Multi-Container Deployment (Recommended for Self-Hosting)
<!-- The script `scripts/deploy/update_and_deploy.sh` is used for deploying the multi-container setup to a VPS. Higher-level scripts like `scripts/deploy/complete_automated_deployment.sh` may orchestrate this. -->
Deploy the full CloudToLocalLLM stack to your own Virtual Private Server (VPS) using Docker Compose.
```bash
# Example: Navigate to project root and run deployment script
cd /path/to/CloudToLocalLLM
./scripts/deploy/update_and_deploy.sh --force
# For a more automated deployment, consider scripts like ./scripts/deploy/complete_automated_deployment.sh
```
This setup provides a scalable and secure environment for multiple users. See `docs/OPERATIONS/SELF_HOSTING.md` for detailed instructions.

### Legacy Single Container (Deprecated)
The legacy single-container deployment is deprecated and no longer supported. Please migrate to the multi-container architecture.

## 📁 Project Structure
CloudToLocalLLM follows an organized directory structure for better maintainability and development:

### Core Directories
*   `api-backend/`: Node.js backend for API, Auth0 integration, and `streaming-proxy-manager.js` which orchestrates ephemeral proxy containers.
*   `lib/`: Unified Flutter application code (UI, chat, system tray, settings, services).
*   `streaming-proxy/`: Contains the Node.js code for the lightweight, ephemeral proxy server (`proxy-server.js`) that runs in isolated Docker containers.
*   `web/`: Entry point and configuration for the Flutter web application.
*   `assets/`: Static assets for the Flutter application (images, fonts, version info).

### Documentation
*   `docs/`: Comprehensive documentation.
    *   `ARCHITECTURE/`: System architecture diagrams and explanations.
    *   `DEPLOYMENT/`: Deployment guides, strategies, and workflows.
    *   `OPERATIONS/`: Operational guides, maintenance, and troubleshooting.
    *   `USER_DOCUMENTATION/`: User-facing guides and FAQs.
    *   `DEVELOPMENT/`: Developer guides, contribution guidelines.

### Scripts & Automation
*   `scripts/`: Organized build, deployment, packaging, and utility scripts.
    *   `build/`: Scripts for building application components.
    *   `deploy/`: Scripts for deploying to various environments (VPS, etc.).
    *   `packaging/`: Scripts for creating distributable packages (AppImage, AUR, Deb).
    *   `release/`: Scripts for managing releases.
    *   `utils/`: Helper and utility scripts.
    *   `README.md`: Detailed overview of available scripts.

### Configuration & Infrastructure
*   `config/`: Configuration files for various platforms and services (Nginx, Docker).
*   `docker/`: Dockerfiles and related files for building service containers.
*   `static_homepage/`: **Legacy** static HTML files for the original project website and downloads page. The main website and documentation are now served by the Flutter application (`flutter-app` container).
*   `aur-package/`: Files for creating and maintaining the Arch User Repository (AUR) package.

### Development Tools
*   `.vscode/`: VS Code editor configurations, launch settings, recommended extensions.
*   `analysis_options.yaml`: Dart static analysis settings.
*   `pubspec.yaml`: Flutter project dependencies and metadata.

For detailed information about any component, see the respective README files in each directory.

## 🚀 Getting Started
1.  **Install Ollama**: Ensure Ollama is installed and running on your local machine. Download models you wish to use (e.g., `ollama pull llama3.2`).
2.  **Install CloudToLocalLLM Client**:
    *   **Linux**: Install via AUR (`yay -S cloudtolocalllm`) or download static package from [cloudtolocalllm.online/download](https://cloudtolocalllm.online/download/).
    *   **Windows**: Download Windows desktop application (v3.6.0+) from releases or build from source.
    *   **macOS**: Coming soon
3.  **Launch CloudToLocalLLM**: The unified application starts with integrated system tray functionality.
4.  **Connect to Local LLM**: The application automatically detects Ollama if running on default ports. Configure if necessary via settings.
5.  **Access Web UI (Optional for Remote Access)**:
    *   Visit [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online) for web access.
    *   Log in using your Auth0 credentials.
    *   Configure tunnel connection to your local Ollama instance.



## 🔧 Key Scripts Overview
This project includes a variety of scripts to automate common tasks. Here are some of the key ones:
*   `scripts/deploy/update_and_deploy.sh`: Deploys the multi-container architecture to a VPS.
*   `scripts/deploy/complete_automated_deployment.sh`: A higher-level script for automated deployment to a live VPS environment.
*   `scripts/packaging/build_aur_universal.sh`: **Universal AUR builder** - automatically detects platform and uses native or Docker-based building.
*   `scripts/docker/build-aur-docker.sh`: Docker-based AUR package builder for Ubuntu systems using Arch Linux container.
*   `scripts/create_aur_binary_package.sh`: Legacy AUR package builder (use universal builder instead).
*   `scripts/build_unified_package.sh`: Builds and packages the unified Flutter application for static download distribution (e.g., a `.tar.gz` archive).
*   `scripts/packaging/build_aur.sh`: Native AUR package builder for Arch Linux systems.
*   `scripts/build_unified_package.sh`: A comprehensive script that builds various components (Flutter app, potentially others) and assembles them into a unified structure, often used as a precursor to packaging scripts.
*   `scripts/version_manager.sh`: Manages project version numbers across different files.
*   `scripts/deploy/complete_automated_deployment.sh`: Orchestrates a full deployment workflow including versioning, building, and distributing.

Refer to `scripts/README.md` for a more exhaustive list and detailed explanations.

## 📦 Building Client Applications

Instructions for building and packaging client applications for different platforms:

### Linux (General Static Package)
Uses `scripts/build_unified_package.sh`. This script typically:
1.  Builds the Flutter application in release mode.
2.  Copies necessary assets and libraries.
3.  Creates a distributable archive (e.g., `.tar.gz`).
```bash
./scripts/build_unified_package.sh
```
The output will be in the `dist/` directory.

### Linux (AUR Package)
**Cross-Platform Support**: AUR packages can now be built on Ubuntu systems using Docker!

**Universal Builder** (Recommended):
```bash
# Auto-detects platform (native on Arch, Docker on Ubuntu)
./scripts/packaging/build_aur_universal.sh
```

**Platform-Specific Methods**:
- **Arch Linux**: Uses native `scripts/packaging/build_aur.sh`
- **Ubuntu/Other**: Uses Docker container with Arch Linux environment
- **Manual Docker**: `./scripts/docker/build-aur-docker.sh build`

**Legacy Method**:
```bash
./scripts/create_aur_binary_package.sh
```

The Docker-based solution provides:
- Complete Arch Linux environment in container
- Pre-installed Flutter SDK and build tools
- Automatic file permission handling
- Integration with existing deployment workflows

For detailed Docker setup and usage, see [scripts/docker/README.md](scripts/docker/README.md).

### Windows
**Status**: Available (v3.6.0+)

1.  **Prerequisites**:
    *   Install [Ollama](https://ollama.ai/) for local LLM support.
    *   Ensure Windows 10/11 with latest updates.
2.  **Install CloudToLocalLLM**:
    *   Download the latest Windows release from the [releases page](https://github.com/imrightguy/CloudToLocalLLM/releases).
    *   Or build from source using `flutter build windows --release`.
3.  **Run CloudToLocalLLM**: Launch the executable - it will appear in the system tray with full desktop integration.

## 📚 Documentation
CloudToLocalLLM features comprehensive, well-organized documentation. The documentation has been streamlined into logical topic areas for better discoverability and maintenance.

*   **Core Concepts**:
    *   [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
    *   [Multi-Container Deep Dive](docs/ARCHITECTURE/MULTI_CONTAINER_ARCHITECTURE.md)
    *   [Enhanced System Tray Architecture](docs/ARCHITECTURE/ENHANCED_SYSTEM_TRAY_ARCHITECTURE.md)
    *   [Streaming Proxy Architecture](docs/ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)
*   **Deployment & Operations**:
    *   [Complete Deployment Workflow](docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)
    *   [Self-Hosting on VPS](docs/OPERATIONS/SELF_HOSTING.md)
    *   [Versioning Strategy](docs/DEPLOYMENT/VERSIONING_STRATEGY.md)
*   **User Guides**:
    *   [Installation Guide](docs/USER_DOCUMENTATION/INSTALLATION_GUIDE.md)
    *   [First Time Setup](docs/USER_DOCUMENTATION/FIRST_TIME_SETUP.md)
    *   [User Troubleshooting Guide](docs/USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)
*   **Development**:
    *   [Developer Onboarding](docs/DEVELOPMENT/DEVELOPER_ONBOARDING.md)
    *   [Contribution Guidelines](CONTRIBUTING.md)
    *   [API Documentation](docs/DEVELOPMENT/API_DOCUMENTATION.md)

- **Self-Hosters**: Use [Self-Hosting Guide](docs/OPERATIONS/SELF_HOSTING.md) → [Infrastructure Guide](docs/OPERATIONS/INFRASTRUCTURE_GUIDE.md)

### **🏗️ Technical Reference:**
- [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md): Complete technical architecture including enhanced tray, streaming, and containers
- [Versioning Strategy](docs/DEPLOYMENT/VERSIONING_STRATEGY.md): Version format and management strategy

## 🤝 Contributing
We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to the project, report issues, and submit pull requests.

Key areas for contribution:
*   Bug fixes and stability improvements
*   Platform-specific enhancements (Windows, macOS)
*   New features and integrations
*   Documentation updates and translations
*   Testing and quality assurance

If you encounter further issues, please check the project's issue tracker on GitHub.

## 📜 License
This project is licensed under the [MIT License](LICENSE).

---

*CloudToLocalLLM - Bridging the Cloud and Your Local Machine for AI.*