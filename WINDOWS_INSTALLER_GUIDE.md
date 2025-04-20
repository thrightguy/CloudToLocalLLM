# CloudToLocalLLM Windows Installer Guide

This document provides information about the CloudToLocalLLM Windows installer, including its features, usage instructions, and future enhancement plans.

## Overview

The CloudToLocalLLM Windows installer is designed to simplify the setup process for the CloudToLocalLLM application, including the Ollama Docker instance. The installer provides options for customizing the installation and configuring the Ollama Docker setup.

## Features

The installer includes the following features:

1. **Installation Options**:
   - Install for current user only (no admin rights required)
   - Install for all users (requires admin rights)
   - Custom installation directory selection

2. **Docker and Ollama Setup**:
   - Automatic Docker Desktop installation (if not already installed)
   - Ollama Docker container setup with GPU support (for NVIDIA GPUs)
   - Custom Ollama API port configuration
   - Custom data directory for models

3. **Additional Options**:
   - Desktop shortcut creation
   - Automatic startup configuration
   - GPU acceleration toggle (for NVIDIA GPUs)

## Installation Instructions

### Prerequisites

- Windows 10 or Windows 11
- Internet connection for downloading Docker Desktop (if not already installed)
- NVIDIA GPU with CUDA support (optional, for GPU acceleration)
- WSL (Windows Subsystem for Linux) enabled

### Installation Steps

1. **Download the Installer**:
   - Download the latest installer from the [Releases](https://github.com/thrightguy/CloudToLocalLLM/releases) page.

2. **Run the Installer**:
   - Double-click the installer file (`CloudToLocalLLM-Windows-X.X.X-Setup.exe`).
   - If prompted by User Account Control, click "Yes" to allow the installer to run.

3. **Select Installation Type**:
   - Choose whether to install for the current user only or for all users.
   - If you select "Install for all users," you will need administrator privileges.

4. **Choose Installation Directory**:
   - Select the directory where you want to install the application.
   - The default is in the Program Files directory.

5. **Select Components**:
   - Choose which components to install:
     - **Desktop Icon**: Creates a shortcut on the desktop.
     - **Install Ollama Docker container**: Sets up Docker Desktop and the Ollama container.
     - **Use custom data directory for models**: Allows you to specify a custom location for model data.
     - **Start application at Windows startup**: Configures the application to start automatically when Windows starts.
     - **Enable GPU acceleration**: Enables GPU acceleration for Ollama (NVIDIA only).

6. **Configure Ollama** (if selected):
   - Specify the Ollama API port (default: 11434).
   - If you selected a custom data directory, specify the directory location.

7. **Complete Installation**:
   - Click "Install" to begin the installation process.
   - The installer will install the application and set up Docker and Ollama if selected.
   - Once complete, you can choose to launch the application immediately.

## Post-Installation

After installation, the following components will be set up:

1. **CloudToLocalLLM Application**:
   - The main application executable and supporting files.
   - Desktop and Start menu shortcuts (if selected).

2. **Docker and Ollama** (if selected):
   - Docker Desktop installed and configured.
   - Ollama Docker container running with the specified configuration.
   - TinyLlama model installed as a default model.

3. **Registry Settings**:
   - Configuration settings stored in the Windows registry.
   - Update check settings configured.

## Troubleshooting

### Common Issues

1. **Docker Installation Fails**:
   - Ensure you have an internet connection.
   - Try installing Docker Desktop manually from [docker.com](https://www.docker.com/products/docker-desktop).
   - Ensure WSL is enabled on your system.

2. **Ollama Container Fails to Start**:
   - Check that Docker Desktop is running.
   - Verify that port 11434 (or your custom port) is not in use by another application.
   - Check the Docker logs for more information.

3. **GPU Acceleration Not Working**:
   - Ensure you have an NVIDIA GPU with CUDA support.
   - Verify that the NVIDIA Container Toolkit is installed.
   - Check that WSL 2 is configured correctly for GPU passthrough.

### Getting Help

If you encounter issues not covered in this guide, please:

1. Check the [GitHub Issues](https://github.com/thrightguy/CloudToLocalLLM/issues) for similar problems and solutions.
2. Create a new issue with detailed information about your problem.

## Future Enhancements

The following enhancements are planned for future versions of the installer:

1. **LM Studio Integration**:
   - Add support for installing and configuring LM Studio as an alternative to Ollama.

2. **Automatic Model Updates**:
   - Add functionality to automatically update Ollama models.

3. **GPU Monitoring and Optimization**:
   - Add tools for monitoring GPU usage and optimizing performance.

4. **Backup and Restore**:
   - Add functionality to backup and restore models and configurations.

5. **Advanced Logging and Diagnostics**:
   - Enhance logging and add diagnostic tools for troubleshooting.

6. **Multi-language Support**:
   - Add support for multiple languages in the installer interface.

7. **Silent Installation**:
   - Add support for silent installation for enterprise deployment.

## Building the Installer

If you want to build the installer yourself, follow these steps:

1. **Prerequisites**:
   - Install [Inno Setup 6](https://jrsoftware.org/isdl.php) or later.
   - Ensure you have PowerShell 5.1 or later.

2. **Build Steps**:
   - Clone the repository.
   - Build the Flutter application in Release mode.
   - Run the `build.ps1` script to create the installer.

```powershell
# Build the Flutter application
flutter build windows --release

# Build the installer
.\build.ps1
```

The installer will be created in the `releases` folder.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.