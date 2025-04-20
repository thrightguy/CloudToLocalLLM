# CloudToLocalLLM

CloudToLocalLLM is a project that bridges the gap between cloud-based applications and local large language models (LLMs). It consists of a native Windows application built with Flutter that connects to locally installed LLMs (Ollama or LM Studio) and an optional cloud component that enables secure remote access.

## Project Overview

The architecture consists of two main components:

### Local Windows Application
- **Native Flutter App**: A Windows desktop application that provides a user-friendly interface for interacting with local LLMs.
- **LLM Integration**: Direct communication with locally installed LLM providers (Ollama or LM Studio).
- **Secure Tunnel**: Optional component that allows remote access to your local LLM through the cloud.

### Cloud Component (Optional)
- **Web Server**: A Node.js-based web server that provides remote access to connected local LLMs.
- **Authentication**: Secure login with Auth0 or other identity providers.
- **API Gateway**: Secure relay of requests between web clients and local LLMs.

This architecture allows you to leverage the power of local LLMs while optionally accessing them remotely through a secure cloud interface, ensuring privacy and control over your LLM instances.

## Features

- **Native Windows Experience**: Run as a standard Windows application with system tray integration.
- **Multiple LLM Support**: Connect to Ollama or LM Studio for local LLM execution.
- **Model Management**: Download, manage, and use different LLM models.
- **Chat Interface**: User-friendly chat interface for interacting with LLMs.
- **Cloud Connectivity**: Optional secure connection to the cloud for remote access.
- **User Authentication**: Secure login with Auth0 or other identity providers.
- **Offline Mode**: Use the application without internet connectivity.
- **Dark/Light Theme**: Choose between dark and light application themes.

## Prerequisites

### For the Windows Application
- **Windows 10/11**: The application is designed for Windows operating systems.
- **Hardware Requirements**:
  - Minimum: 8GB RAM, 4-core CPU
  - Recommended: 16GB RAM, 8-core CPU, NVIDIA GPU with at least 4GB VRAM for GPU acceleration
- **Software Requirements**:
  - The installer will automatically set up Docker Desktop and Ollama
  - Alternatively, you can manually install one of these LLM providers:
    - [Ollama](https://ollama.ai/download) - Recommended for ease of use
    - [LM Studio](https://lmstudio.ai/) - Alternative with additional model options
- **Flutter**: Only required for development, not for running the application.

### For the Cloud Component (Optional)
- **Node.js**: Version 14 or higher
- **npm**: For package management
- **Auth0 Account**: For setting up authentication (optional)

## Setup Instructions

### Windows Application Setup

1. **Download and Install the Application**
   - Download the installer from the [Releases](https://github.com/thrightguy/CloudToLocalLLM/releases) page.
   - Run the installer and follow the on-screen instructions.
   - The application will be installed to your chosen location and shortcuts will be created in the Start menu and optionally on your desktop.

2. **LLM Provider Setup**
   - The installer will automatically set up Docker Desktop and Ollama with GPU support (if an NVIDIA GPU is detected).
   - Alternatively, you can manually install [Ollama](https://ollama.ai/download) or [LM Studio](https://lmstudio.ai/) if you prefer not to use Docker.

3. **Run the Application**
   - Launch CloudToLocalLLM from the Start menu or desktop shortcut.
   - The application will start and appear in your system tray.
   - Click the system tray icon to open the main interface.

4. **Configure the Application**
   - On first run, the application will guide you through initial setup.
   - Select your preferred LLM provider (Ollama or LM Studio).
   - Choose whether to enable cloud connectivity.

### Cloud Component Setup (Optional)

#### Local Development Setup

1. **Clone the Repository**
   ```
   git clone https://github.com/thrightguy/CloudToLocalLLM.git
   cd CloudToLocalLLM/webapp
   ```

2. **Install Dependencies**
   ```
   npm install
   ```

3. **Configure Environment Variables**
   - Copy the `.env.example` file to `.env`
   - Update the values in `.env` with your Auth0 credentials and other settings

4. **Start the Server**
   ```
   npm start
   ```

5. **Access the Web Interface**
   - Open your browser and navigate to `http://localhost:3000`
   - Log in with your Auth0 credentials

#### Cloud Deployment Options

You can deploy the cloud component to various cloud platforms:

1. **Render** (Recommended)
   - Easy deployment with automatic updates
   - Free tier available for testing
   - See [RENDER_DEPLOYMENT.md](RENDER_DEPLOYMENT.md) for detailed instructions

2. **Other Cloud Platforms**
   - The application can be deployed to any platform that supports Node.js
   - Examples include Heroku, AWS, Azure, Google Cloud, etc.
   - Deployment steps will vary by platform

## Usage

### Windows Application

1. **Launch the Application**
   - Start the application from the desktop shortcut or by running `CloudToLocalLLM.exe`.
   - The application will appear in your system tray.
   - Click the system tray icon to open the main interface.

2. **Connect to an LLM Provider**
   - If you used the installer, Docker Desktop and Ollama will be automatically set up and running.
   - If you manually installed an LLM provider, ensure it is running.
   - Select your preferred provider (Ollama or LM Studio) from the dropdown in the settings screen.

3. **Manage Models**
   - Navigate to the Models screen to see available models.
   - Download new models by clicking the "Add Model" button.
   - For Ollama, you can download models like `llama2`, `mistral`, or `tinyllama`.
   - For LM Studio, you can select from your locally installed models.

4. **Chat with the LLM**
   - Create a new conversation by clicking the "+" button.
   - Select a model from the dropdown at the top of the screen.
   - Type your prompt in the input field and press Enter or click Send.
   - The LLM's response will appear in the chat interface.

5. **Enable Cloud Connectivity (Optional)**
   - Navigate to Settings > Cloud Settings.
   - Toggle "Enable Remote Access" to on.
   - Log in with your cloud account credentials.
   - The application will establish a secure tunnel to the cloud service.

### Cloud Interface (Optional)

1. **Access the Web Interface**
   - Navigate to `http://localhost:3000` in your browser (or your deployed cloud URL).
   - Log in with your credentials.

2. **Connect to Your Local LLM**
   - After logging in, you'll see a list of your connected local LLMs.
   - Select the LLM you want to use.

3. **Chat with the LLM**
   - Create a new conversation or select an existing one.
   - Type your prompt and press Enter or click Send.
   - The request will be securely relayed to your local LLM, and the response will be displayed.

## Project Structure

The project is organized into the following main directories:

### Windows Application

- **lib/**: Flutter application code
  - **config/**: Configuration files
    - **app_config.dart**: Application settings
    - **theme.dart**: UI theme definitions
  - **models/**: Data models
    - **llm_model.dart**: LLM model class
    - **message.dart**: Chat message class
    - **user.dart**: User profile class
    - **conversation.dart**: Conversation class
  - **services/**: Business logic
    - **ollama_service.dart**: Communicates with Ollama API
    - **auth_service.dart**: Handles authentication
    - **tunnel_service.dart**: Manages tunnel for remote access
    - **cloud_service.dart**: Handles cloud communication
    - **storage_service.dart**: Local data persistence
  - **providers/**: State management
    - **llm_provider.dart**: LLM state management
    - **auth_provider.dart**: Authentication state
    - **settings_provider.dart**: App settings state
  - **screens/**: UI screens
    - **home_screen.dart**: Main screen
    - **chat_screen.dart**: Chat interface
    - **models_screen.dart**: Model management
    - **settings_screen.dart**: Application settings
  - **widgets/**: Reusable UI components
  - **main.dart**: Application entry point
- **windows/**: Windows-specific code
  - **runner/**: Native Windows code

### Cloud Component

- **webapp/**: Cloud service code
  - **server.js**: Main server file
  - **package.json**: Node.js dependencies
  - **.env**: Environment configuration
  - **public/**: Static web assets

## Troubleshooting

### Windows Application

- **LLM Provider Not Detected**:
  - Ensure Ollama or LM Studio is installed and running.
  - Check the provider's API port (Ollama: 11434, LM Studio: 1234).
  - Restart the application after starting the LLM provider.

- **Models Not Appearing**:
  - For Ollama, ensure models are installed using `ollama list`.
  - For LM Studio, ensure models are properly loaded in the LM Studio interface.
  - Click the refresh button in the Models screen.

- **Cloud Connection Issues**:
  - Verify your internet connection.
  - Check that you're logged in with valid credentials.
  - Ensure the cloud server is running and accessible.

### Cloud Component

- **Server Not Starting**:
  - Check that Node.js is installed (version 14+).
  - Verify all dependencies are installed with `npm install`.
  - Check the `.env` configuration file.

- **Authentication Issues**:
  - Verify your Auth0 configuration in the `.env` file.
  - Check Auth0 dashboard for login errors.
  - Ensure redirect URLs are properly configured.

## Contributing

Contributions are welcome! To contribute:

1. **Fork the Repository**
   - Fork the repository on GitHub.

2. **Create a Feature Branch**
   ```
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Implement your feature or bug fix.
   - Add or update tests as necessary.
   - Update documentation to reflect your changes.

4. **Follow Coding Standards**
   - For Flutter/Dart code:
     - Run `dart format .` to format your code.
     - Run `dart analyze` to check for issues.
   - For JavaScript code:
     - Run `npm run lint` to check for issues.

5. **Commit Your Changes**
   ```
   git commit -m "Add feature: your feature description"
   ```

6. **Push to Your Branch**
   ```
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Open a pull request on GitHub.
   - Provide a clear description of the changes.
   - Link any related issues.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Ollama](https://ollama.ai/) for providing an easy-to-use LLM server.
- [LM Studio](https://lmstudio.ai/) for local LLM inference.
- [Flutter](https://flutter.dev/) for the cross-platform UI framework.
- [Node.js](https://nodejs.org/) for the cloud service.
- [Auth0](https://auth0.com/) for authentication services.

---

Happy coding with your local LLMs! 🚀
