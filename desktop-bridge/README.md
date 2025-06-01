# CloudToLocalLLM Desktop Bridge

A secure Go-based desktop application that bridges your local Ollama instance to the CloudToLocalLLM cloud service. Features system tray integration, Auth0 authentication, and WebSocket tunneling.

## Features

- **🔐 Secure Authentication**: Auth0 integration with PKCE flow
- **🌐 WebSocket Tunnel**: Secure connection to cloud relay service
- **🖥️ System Tray Integration**: Native Linux desktop integration
- **🔄 Auto-Reconnection**: Automatic reconnection on network issues
- **⚙️ Configuration Management**: YAML-based configuration
- **📊 Status Monitoring**: Real-time connection status
- **🚀 Multiple Run Modes**: GUI with tray or headless daemon mode

## Architecture

```
┌─────────────────┐    WebSocket     ┌─────────────────┐    HTTPS    ┌─────────────────┐
│   Local Ollama  │◄─────────────────│ Desktop Bridge  │◄────────────│  Cloud Relay    │
│   (localhost:   │                  │  (This App)     │             │ (app.cloudto... │
│    11434)       │                  │                 │             │  localllm.online)│
└─────────────────┘                  └─────────────────┘             └─────────────────┘
                                              │                               │
                                              │                               │
                                      ┌─────────────────┐             ┌─────────────────┐
                                      │  System Tray    │             │   Web App       │
                                      │  Integration    │             │   (Flutter)     │
                                      └─────────────────┘             └─────────────────┘
```

## Installation

### Prerequisites

- **Go 1.21+**: For building from source
- **Ollama**: Local LLM runtime
- **GTK3**: For system tray support
- **Linux**: Currently supports Linux only

### Install Dependencies (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install golang-go libgtk-3-dev libnotify-dev pkg-config
```

### Install Dependencies (Fedora/RHEL)

```bash
sudo dnf install golang gtk3-devel libnotify-devel pkg-config
```

### Install Dependencies (Arch Linux)

```bash
sudo pacman -S go gtk3 libnotify pkg-config
```

## Building

### Quick Build

```bash
# Build everything (application + packages)
./scripts/desktop/build-all.sh

# Build application only
./scripts/desktop/build-all.sh --build-only

# Build specific package
./scripts/desktop/build-all.sh --deb-only
./scripts/desktop/build-all.sh --appimage-only
```

### Manual Build

```bash
cd desktop-bridge
go mod download
go build -o cloudtolocalllm-bridge .
```

## Usage

### GUI Mode (Default)

```bash
# Run with system tray
./cloudtolocalllm-bridge

# The application will appear in your system tray
# Right-click the tray icon for options:
# - Connect/Disconnect
# - Login/Logout
# - Settings
# - About
# - Quit
```

### Headless Mode

```bash
# Run without GUI (requires prior authentication)
./cloudtolocalllm-bridge --no-tray

# Run as daemon
./cloudtolocalllm-bridge --daemon
```

### Command Line Options

```bash
cloudtolocalllm-bridge [options]

Options:
  --version           Show version information
  --help              Show help message
  --config PATH       Path to configuration file
  --log-level LEVEL   Set log level (debug, info, warn, error)
  --no-tray           Run without system tray (headless mode)
  --daemon            Run as daemon (implies --no-tray)
```

## Configuration

Configuration is automatically created at `~/.config/cloudtolocalllm/bridge.yaml`:

```yaml
auth0:
  domain: "dev-xafu7oedkd5wlrbo.us.auth0.com"
  client_id: "ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29"
  audience: "https://app.cloudtolocalllm.online"
  scopes: ["openid", "profile", "email"]
  redirect_uri: "http://localhost:3025/"

ollama:
  host: "localhost"
  port: 11434
  timeout_seconds: 60

cloud:
  websocket_url: "wss://app.cloudtolocalllm.online/ws/bridge"
  status_url: "https://app.cloudtolocalllm.online/api/ollama/bridge/status"
  register_url: "https://app.cloudtolocalllm.online/api/ollama/bridge/register"

bridge:
  port: 3025
  log_level: "info"
  auto_start: false
  show_tray_icon: true

logging:
  level: "info"
  file: ""
  max_size_mb: 10
  max_age_days: 30
  compress: true
```

## Authentication

The bridge uses Auth0 for secure authentication:

1. **First Run**: Click "Login" in the system tray menu
2. **Browser Opens**: Complete OAuth2 flow in your browser
3. **Tokens Stored**: Authentication tokens saved securely
4. **Auto-Refresh**: Tokens automatically refreshed as needed

Authentication tokens are stored at `~/.config/cloudtolocalllm/tokens.json`.

## System Integration

### Systemd Service

Enable automatic startup:

```bash
# Copy service file
sudo cp packaging/linux/systemd/cloudtolocalllm-bridge.service /usr/lib/systemd/user/

# Enable for current user
systemctl --user enable cloudtolocalllm-bridge.service
systemctl --user start cloudtolocalllm-bridge.service

# Check status
systemctl --user status cloudtolocalllm-bridge.service
```

### Desktop Integration

The application integrates with your desktop environment:

- **Applications Menu**: Appears in Network/Utility categories
- **System Tray**: Status icon with context menu
- **Notifications**: Desktop notifications for status changes
- **Autostart**: Optional automatic startup on login

## Troubleshooting

### Common Issues

**1. System Tray Not Visible**
```bash
# Check if system tray is supported
echo $XDG_CURRENT_DESKTOP

# Install system tray support
sudo apt-get install gnome-shell-extension-appindicator  # GNOME
```

**2. Authentication Fails**
```bash
# Clear stored tokens
rm ~/.config/cloudtolocalllm/tokens.json

# Try login again
./cloudtolocalllm-bridge
```

**3. Ollama Connection Issues**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/version

# Start Ollama if needed
ollama serve
```

**4. Build Issues**
```bash
# Install missing dependencies
sudo apt-get install libgtk-3-dev libnotify-dev pkg-config

# Clean and rebuild
./scripts/desktop/build-all.sh --clean
```

### Debug Mode

Enable debug logging:

```bash
./cloudtolocalllm-bridge --log-level debug
```

Or edit configuration file:

```yaml
bridge:
  log_level: "debug"
```

### Log Files

Logs are written to:
- **Console**: When running interactively
- **Systemd Journal**: When running as service
- **File**: If configured in `logging.file`

View systemd logs:
```bash
journalctl --user -u cloudtolocalllm-bridge.service -f
```

## Development

### Project Structure

```
desktop-bridge/
├── main.go              # Main application entry point
├── auth/                # Auth0 authentication
│   └── auth.go
├── config/              # Configuration management
│   └── config.go
├── tunnel/              # WebSocket tunnel
│   └── tunnel.go
├── tray/                # System tray integration
│   └── tray.go
├── go.mod               # Go module definition
└── README.md            # This file
```

### Building Packages

```bash
# Build Debian package
./scripts/desktop/package-deb.sh

# Build AppImage
./scripts/desktop/package-appimage.sh

# Prepare AUR package
./scripts/desktop/build-all.sh --aur-only
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **Website**: https://cloudtolocalllm.online
- **Documentation**: https://cloudtolocalllm.online/docs
- **Issues**: https://github.com/imrightguy/CloudToLocalLLM/issues
- **Email**: support@cloudtolocalllm.online
