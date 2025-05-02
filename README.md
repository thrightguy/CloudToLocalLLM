# CloudToLocalLLM

A Windows application that serves as an entry point for communicating with local LLMs (Language Learning Models). Built with Flutter, it provides a native Windows experience for managing and interacting with locally installed LLMs like Ollama.

> **Note**: This project has moved to GitLab for better large file support and enhanced CI/CD capabilities.

## What's New in v1.2.0
- **Enhanced System Tray Integration**: Full control of the application from the system tray
- **Improved Ollama Integration**: 
  - Automatic installation and setup via Setup-Ollama.ps1
  - ZIP-based installation for better portability
  - Support for both NVIDIA and AMD GPUs
- **Tunnel Management**: Secure remote access through ngrok integration
- **Settings UI**: Enhanced Windows-specific settings and LLM process management

## Features

- **Native Windows Experience**
  - System tray integration with status indicators
  - Automatic LLM service management
  - Dark/Light theme support
  
- **LLM Integration**
  - Direct communication with Ollama
  - Automatic installation and configuration
  - Model management and status monitoring
  
- **Remote Access**
  - Secure tunneling via ngrok
  - Automatic tunnel management
  - Status monitoring and health checks

## Prerequisites

- **Windows 10/11**
- **Hardware Requirements**:
  - Minimum: 8GB RAM, 4-core CPU
  - Recommended: 16GB RAM, 8-core CPU
  - Optional: NVIDIA/AMD GPU for acceleration

## Installation

1. **Download and Install**
   ```powershell
   # Clone the repository
   git clone https://gitlab.com/thrightguy-group/CloudToLocalLLM.git
   cd CloudToLocalLLM
   
   # Run the setup script
   .\Setup-Ollama.ps1
   ```

2. **Build the Application**
   ```powershell
   # Install Flutter (if not already installed)
   # Then build the application
   .\build.ps1 -Release
   ```

## Usage

1. **Start the Application**
   - Launch from the Start menu or desktop shortcut
   - The app will appear in your system tray
   - Click the tray icon to open the interface

2. **LLM Management**
   - Ollama will be automatically installed and configured
   - Download models through the UI or using `ollama pull model_name`
   - Monitor LLM status from the system tray

3. **Remote Access**
   - Enable remote access in settings
   - A secure tunnel will be created automatically
   - Access your LLM through the provided URL

## Project Structure

```
CloudToLocalLLM/
├── lib/                    # Flutter application code
│   ├── config/            # Application configuration
│   ├── models/            # Data models
│   ├── services/          # Business logic
│   ├── providers/         # State management
│   ├── screens/           # UI screens
│   └── widgets/           # Reusable components
├── windows/               # Windows-specific code
├── tools/                 # Installation tools
└── Setup-Ollama.ps1      # Ollama setup script
```

## Remote Access

Remote access is handled by the separate cloud component. See [CloudToLocalLLM_cloud](https://gitlab.com/thrightguy-group/CloudToLocalLLM_cloud) for details.

## Contributing

1. Fork the repository on [GitLab](https://gitlab.com/thrightguy-group/CloudToLocalLLM)
2. Create a feature branch
3. Make your changes
4. Create a merge request

## License

MIT License - see LICENSE file

## Acknowledgments

- [Ollama](https://ollama.ai/)
- [Flutter](https://flutter.dev/)
- [ngrok](https://ngrok.com/)
