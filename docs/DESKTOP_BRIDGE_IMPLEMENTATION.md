# CloudToLocalLLM Desktop Bridge Implementation

## Overview

This document describes the implementation of the CloudToLocalLLM Desktop Bridge - a Go-based application that provides secure tunneling between local Ollama instances and the CloudToLocalLLM cloud service.

## Architecture

### Components

1. **Main Application** (`main.go`)
   - Command-line argument parsing
   - Application lifecycle management
   - Logging configuration
   - Signal handling

2. **Authentication Module** (`auth/auth.go`)
   - Auth0 integration with PKCE flow
   - Token storage and management
   - Browser-based OAuth2 flow
   - Automatic token refresh

3. **Tunnel Manager** (`tunnel/tunnel.go`)
   - WebSocket connection to cloud relay
   - Message routing between Ollama and cloud
   - Automatic reconnection
   - Bridge registration

4. **System Tray** (`tray/tray.go`)
   - Native Linux system tray integration
   - Context menu with controls
   - Status indicators
   - Desktop notifications

5. **Configuration** (`config/config.go`)
   - YAML-based configuration
   - Default settings
   - User customization

### Data Flow

```
Web App → Cloud Relay → WebSocket → Desktop Bridge → HTTP → Local Ollama
                                                    ↓
                                            System Tray UI
```

## Authentication Flow

1. User clicks "Login" in system tray
2. Bridge generates PKCE parameters
3. Browser opens Auth0 authorization URL
4. User completes authentication
5. Auth0 redirects to local callback server
6. Bridge exchanges code for tokens
7. Tokens stored securely on disk
8. Bridge registers with cloud relay

## Tunnel Protocol

### Message Format

```json
{
  "type": "request|response|ping|pong",
  "id": "unique-message-id",
  "method": "GET|POST|PUT|DELETE",
  "path": "/api/ollama/...",
  "headers": {"Content-Type": "application/json"},
  "body": "base64-encoded-body",
  "status": 200,
  "error": "error-message",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### Message Types

- **request**: Cloud → Bridge (forward to Ollama)
- **response**: Bridge → Cloud (Ollama response)
- **ping**: Cloud → Bridge (keepalive)
- **pong**: Bridge → Cloud (keepalive response)

## Linux Integration

### Package Formats

1. **Debian Package (.deb)**
   - Standard Debian package format
   - Dependency management
   - Post-install scripts
   - Desktop integration

2. **AppImage**
   - Universal Linux compatibility
   - Self-contained executable
   - No installation required
   - Desktop integration

3. **AUR Package**
   - Arch Linux integration
   - Uses AppImage as source
   - Proper Arch packaging

### Desktop Integration

- **Desktop File**: `/usr/share/applications/cloudtolocalllm-bridge.desktop`
- **Icon**: `/usr/share/pixmaps/cloudtolocalllm-bridge.png`
- **Systemd Service**: `/usr/lib/systemd/user/cloudtolocalllm-bridge.service`
- **Binary**: `/opt/cloudtolocalllm-bridge/cloudtolocalllm-bridge`
- **Symlink**: `/usr/bin/cloudtolocalllm-bridge`

### System Tray Requirements

- **GTK3**: For system tray support
- **libnotify**: For desktop notifications
- **X11/Wayland**: Display server support

## Configuration

### Default Configuration

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

### File Locations

- **Config**: `~/.config/cloudtolocalllm/bridge.yaml`
- **Tokens**: `~/.config/cloudtolocalllm/tokens.json`
- **Logs**: Configurable or systemd journal

## Build System

### Scripts

1. **build-bridge.sh**: Builds the Go application
2. **package-deb.sh**: Creates Debian package
3. **package-appimage.sh**: Creates AppImage
4. **build-all.sh**: Master build script

### Dependencies

- **Go 1.21+**: For building
- **GTK3 Dev**: For system tray
- **libnotify Dev**: For notifications
- **pkg-config**: For library detection
- **dpkg-deb**: For Debian packages
- **wget**: For AppImage tools
- **ImageMagick**: For icon conversion

### Build Process

```bash
# Install dependencies
sudo apt-get install golang-go libgtk-3-dev libnotify-dev pkg-config

# Build everything
./scripts/desktop/build-all.sh

# Build specific components
./scripts/desktop/build-all.sh --build-only
./scripts/desktop/build-all.sh --deb-only
./scripts/desktop/build-all.sh --appimage-only
```

## Security Considerations

### Authentication

- **PKCE Flow**: Prevents authorization code interception
- **Local Callback**: Secure token exchange
- **Token Storage**: Encrypted storage on disk
- **Automatic Refresh**: Seamless token renewal

### Network Security

- **TLS/WSS**: All communication encrypted
- **JWT Validation**: Server-side token verification
- **Origin Validation**: Request source verification
- **Rate Limiting**: Abuse prevention

### System Security

- **Non-root**: Runs as regular user
- **Sandboxing**: Limited system access
- **Secure Defaults**: Conservative configuration
- **Input Validation**: All inputs validated

## Error Handling

### Connection Issues

- **Automatic Reconnection**: Exponential backoff
- **Status Indicators**: Visual feedback
- **Graceful Degradation**: Fallback modes
- **Error Notifications**: User alerts

### Authentication Issues

- **Token Refresh**: Automatic renewal
- **Re-authentication**: Seamless re-login
- **Error Recovery**: Clear error messages
- **Fallback Options**: Manual intervention

## Monitoring and Logging

### Log Levels

- **debug**: Detailed debugging information
- **info**: General operational messages
- **warn**: Warning conditions
- **error**: Error conditions

### Metrics

- **Connection Status**: Connected/disconnected
- **Message Count**: Requests/responses
- **Error Rate**: Failed operations
- **Latency**: Response times

## Future Enhancements

### Planned Features

1. **Windows Support**: Windows system tray
2. **macOS Support**: macOS menu bar
3. **Configuration GUI**: Settings dialog
4. **Multiple Ollama**: Support multiple instances
5. **Load Balancing**: Distribute requests
6. **Metrics Dashboard**: Performance monitoring

### Technical Improvements

1. **gRPC Protocol**: More efficient communication
2. **Compression**: Reduce bandwidth usage
3. **Caching**: Improve response times
4. **Clustering**: High availability
5. **Auto-update**: Seamless updates

## Testing

### Unit Tests

```bash
cd desktop-bridge
go test ./...
```

### Integration Tests

```bash
# Test with local Ollama
./cloudtolocalllm-bridge --version
./cloudtolocalllm-bridge --help
```

### Package Tests

```bash
# Test Debian package
sudo dpkg -i dist/cloudtolocalllm-bridge_1.0.0_amd64.deb
cloudtolocalllm-bridge --version

# Test AppImage
chmod +x dist/CloudToLocalLLM-Bridge-1.0.0-x86_64.AppImage
./dist/CloudToLocalLLM-Bridge-1.0.0-x86_64.AppImage --version
```

## Deployment

### Release Process

1. **Version Bump**: Update version numbers
2. **Build Packages**: Create all package formats
3. **Test Packages**: Verify functionality
4. **Upload Releases**: GitHub releases
5. **Update AUR**: Publish to AUR
6. **Documentation**: Update docs

### Distribution

- **GitHub Releases**: Primary distribution
- **Debian Repository**: Future consideration
- **AUR**: Arch Linux users
- **Snap/Flatpak**: Universal packages (future)

## Support

### Documentation

- **README**: Basic usage instructions
- **Man Page**: Detailed reference (future)
- **Wiki**: Community documentation
- **API Docs**: Developer reference

### Community

- **GitHub Issues**: Bug reports and features
- **Discussions**: Community support
- **Discord**: Real-time chat (future)
- **Email**: Direct support

This implementation provides a robust, secure, and user-friendly bridge between local Ollama instances and the CloudToLocalLLM cloud service, with comprehensive Linux desktop integration.
