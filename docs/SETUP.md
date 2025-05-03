# CloudToLocalLLM Setup Guide

This guide will help you set up CloudToLocalLLM on your system, including both the client application and any required dependencies.

## System Requirements

- OS: Windows 10/11, macOS 10.14+, or Linux (Ubuntu 18.04+)
- RAM: Minimum 8GB (16GB+ recommended for running large LLMs)
- Disk Space: At least 5GB for the application and base models
- Optional: NVIDIA GPU with CUDA support for faster model inference

## Prerequisites

Before installing CloudToLocalLLM, make sure you have:

1. **Flutter SDK** (version 2.10.0 or higher)
   - [Official Flutter Installation Guide](https://flutter.dev/docs/get-started/install)
   - Run `flutter doctor` to verify your installation

2. **Dart SDK** (version 2.16.0 or higher)
   - This should be included with Flutter SDK

3. **Git** for version control
   - [Git Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

## Setting Up Local LLM Backend (Optional)

You have two options for connecting to LLMs:

### Option 1: Ollama (Recommended for most users)

1. **Install Ollama**:
   - Windows: [Ollama for Windows](https://ollama.ai/download/windows)
   - macOS: `curl -fsSL https://ollama.ai/install.sh | sh`
   - Linux: `curl -fsSL https://ollama.ai/install.sh | sh`

2. **Verify Installation**:
   ```bash
   ollama --version
   ```

3. **Pull a Starting Model**:
   ```bash
   ollama pull tinyllama # A smaller model to start with
   ```

### Option 2: LM Studio

1. **Download and Install LM Studio**:
   - Visit [LM Studio's website](https://lmstudio.ai/) and download the appropriate version for your OS

2. **Launch LM Studio** and follow the setup wizard
   - Download at least one model through the interface

## Installing CloudToLocalLLM

### Development Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/CloudToLocalLLM.git
   cd CloudToLocalLLM
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run in Development Mode**:
   ```bash
   flutter run
   ```

### Building for Production

#### Windows

```bash
flutter build windows --release
```
The built application will be in `build\windows\runner\Release\`.

#### macOS

```bash
flutter build macos --release
```
The built application will be in `build/macos/Build/Products/Release/`.

#### Linux

```bash
flutter build linux --release
```
The built application will be in `build/linux/x64/release/bundle/`.

## Configuration

After installing CloudToLocalLLM, you'll need to configure it:

1. **Launch the application**

2. **Navigate to Settings**:
   - Click on the gear icon in the top-right corner

3. **Configure LLM Settings**:
   - Select your preferred LLM provider (Ollama or LM Studio)
   - If needed, adjust the IP address and port (defaults should work for local installations)

4. **Test Connection**:
   - Create a new conversation and send a test message
   - If the LLM responds, your setup is complete!

## Troubleshooting

### Common Issues

1. **Application won't connect to LLM**:
   - Verify your LLM service is running (`ollama list` or check LM Studio)
   - Check IP address and port settings
   - Verify no firewall is blocking connections

2. **Missing Dependencies**:
   - Run `flutter doctor` to check for missing dependencies
   - Follow the instructions to install them

3. **Build Errors**:
   - Make sure you have the latest Flutter SDK: `flutter upgrade`
   - Clean the build: `flutter clean` then try building again

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [GitHub Issues](https://github.com/your-username/CloudToLocalLLM/issues) for similar problems
2. Join our community discussion (link in README)
3. Open a new issue with detailed information about your problem

## Next Steps

After successful setup, check out:

1. The [User Guide](USER_GUIDE.md) for instructions on using the application
2. The [Contributing Guide](../CONTRIBUTING.md) if you'd like to contribute to the project 