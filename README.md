# CloudToLocalLLM

A Flutter application that bridges the gap between cloud services and local large language models (LLMs).

## Features

- **Local LLM Integration**: Connect to locally running LLM services like Ollama or LM Studio
- **Cloud Synchronization**: Optional synchronization of your conversations with cloud
- **Remote Access**: Access your local LLM from anywhere via secure tunnels
- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Multiple LLM Providers**: Support for Ollama and LM Studio, with extensible architecture
- **System Tray Integration**: Always accessible via system tray with persistent window management
- **Smart Window Behavior**: Main window shows on startup and minimizes to tray when closed

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

## Getting Started

### Prerequisites

- Flutter SDK (2.10.0 or higher)
- Dart SDK (2.16.0 or higher)
- (Optional) Ollama or LM Studio installed locally

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

### Cloud Synchronization

1. Create an account or log in
2. Enable cloud synchronization in Settings
3. Your conversations will automatically sync when you're online

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
