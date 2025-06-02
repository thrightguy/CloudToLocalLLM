# CloudToLocalLLM Enhanced System Tray Architecture

## Overview

The CloudToLocalLLM Enhanced System Tray Architecture implements a completely independent system tray daemon that acts as a universal connection broker for all CloudToLocalLLM connections. This architecture provides:

- **Independent Operation**: System tray daemon operates independently of the main Flutter app
- **Universal Connection Management**: Handles ALL connections (local Ollama + cloud proxy)
- **Centralized Authentication**: Manages authentication tokens and connection state
- **Separate Settings Interface**: Independent configuration and monitoring
- **Crash Isolation**: Tray daemon failures don't affect the main application

## Architecture Components

### 1. Enhanced Tray Daemon (`enhanced_tray_daemon.py`)

**Primary Features:**
- Independent system tray with cross-platform support
- Universal connection broker for all external services
- TCP socket IPC with JSON protocol
- Application lifecycle management
- Authentication-aware menu system

**Connection Management:**
- Handles both local Ollama and cloud proxy connections
- Automatic connection monitoring and failover
- Unified API for the main Flutter app
- Streaming support for chat functionality

### 2. Connection Broker (`connection_broker.py`)

**Core Functionality:**
- Manages multiple connection types (local_ollama, cloud_proxy)
- Automatic connection health monitoring
- Request proxying with path mapping
- Streaming chat support
- Configuration persistence

**Connection Types:**
- **Local Ollama**: Direct HTTP connection to localhost:11434
- **Cloud Proxy**: Authenticated HTTPS connection to cloud services

### 3. Enhanced Tray Service (`enhanced_tray_service.dart`)

**Flutter Integration:**
- Communicates with the enhanced tray daemon via TCP sockets
- Provides unified API for the main Flutter application
- Handles daemon lifecycle management
- Automatic reconnection and health monitoring

### 4. Unified Connection Service (`unified_connection_service.dart`)

**Application Interface:**
- Single point of access for all connections
- Routes ALL requests through the tray daemon
- Consistent API regardless of connection type
- Real-time connection status updates

### 5. Settings Application (`settings_app.py`)

**Independent Configuration:**
- Standalone GUI for daemon configuration
- Connection testing and monitoring
- Authentication token management
- Real-time status display

## Key Benefits

### 1. Complete Independence
- Tray daemon can start, stop, and operate independently
- Main Flutter app can connect to existing daemon or start new one
- Settings can be configured without main app running

### 2. Unified Connection Management
- All connections (local + cloud) go through the same broker
- Consistent API for the main application
- Automatic failover between connection types
- Centralized authentication and token management

### 3. Enhanced Reliability
- Crash isolation between components
- Automatic reconnection and health monitoring
- Graceful degradation when connections fail
- Comprehensive error handling and logging

### 4. Improved User Experience
- Seamless switching between local and cloud connections
- Real-time connection status in system tray
- Independent settings interface
- Persistent daemon across app restarts

## Installation and Setup

### 1. Install Python Dependencies

```bash
cd tray_daemon
pip install -r requirements.txt
```

### 2. Start Enhanced Tray Daemon

```bash
# Start daemon in background
./start_enhanced_daemon.sh start

# Start daemon in debug mode
./start_enhanced_daemon.sh start --debug

# Check daemon status
./start_enhanced_daemon.sh status
```

### 3. Configure Connections

```bash
# Launch settings app
python3 settings_app.py
```

### 4. Run Main Flutter Application

The Flutter app will automatically connect to the running daemon or start a new one if needed.

## Configuration

### Connection Configuration File

Location: `~/.cloudtolocalllm/connection_config.json`

```json
{
  "local_ollama": {
    "connection_type": "local_ollama",
    "host": "localhost",
    "port": 11434,
    "api_base_url": "http://localhost:11434",
    "enabled": true,
    "timeout": 30
  },
  "cloud_proxy": {
    "connection_type": "cloud_proxy",
    "api_base_url": "https://api.cloudtolocalllm.online",
    "auth_token": "your_auth_token_here",
    "enabled": false,
    "timeout": 30
  }
}
```

### IPC Communication

The daemon listens on a TCP socket (auto-assigned port) and communicates via JSON messages:

**Commands from Flutter App:**
- `PING` - Health check
- `UPDATE_TOOLTIP` - Update tray tooltip
- `UPDATE_ICON` - Update tray icon state
- `AUTH_STATUS` - Update authentication status
- `UPDATE_AUTH_TOKEN` - Update cloud authentication token
- `PROXY_REQUEST` - Proxy a request through connection broker
- `GET_CONNECTION_STATUS` - Get current connection status

**Commands from Daemon:**
- `SHOW` - Show main window
- `HIDE` - Hide main window
- `SETTINGS` - Open settings
- `QUIT` - Quit application
- `CONNECTION_STATUS_CHANGED` - Connection status update

## Development

### Running in Development Mode

1. **Start daemon in debug mode:**
   ```bash
   ./start_enhanced_daemon.sh start --debug
   ```

2. **Run Flutter app:**
   ```bash
   flutter run -d linux
   ```

3. **Monitor logs:**
   ```bash
   tail -f ~/.cloudtolocalllm/tray.log
   ```

### Testing Connections

Use the settings app to test individual connections:

```bash
python3 settings_app.py
```

Or test via command line:

```bash
# Test local Ollama
curl http://localhost:11434/api/version

# Test cloud proxy (with auth token)
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.cloudtolocalllm.online/health
```

## Troubleshooting

### Common Issues

1. **Daemon won't start:**
   - Check Python dependencies: `pip install -r requirements.txt`
   - Verify Python 3 is available: `python3 --version`
   - Check logs: `~/.cloudtolocalllm/tray.log`

2. **Flutter app can't connect:**
   - Verify daemon is running: `./start_enhanced_daemon.sh status`
   - Check port file: `~/.cloudtolocalllm/tray_port`
   - Restart daemon: `./start_enhanced_daemon.sh restart`

3. **Connections failing:**
   - Use settings app to test connections
   - Check Ollama is running: `systemctl status ollama`
   - Verify authentication tokens are valid

### Log Files

- **Daemon logs:** `~/.cloudtolocalllm/tray.log`
- **Flutter logs:** Console output when running `flutter run`
- **Connection logs:** Included in daemon logs with connection status

## Migration from Old Architecture

The new architecture is designed to be backward compatible, but for optimal performance:

1. **Stop old tray daemon:**
   ```bash
   pkill -f tray_daemon.py
   ```

2. **Start enhanced daemon:**
   ```bash
   ./start_enhanced_daemon.sh start
   ```

3. **Update Flutter app** to use new services (already implemented)

4. **Configure connections** using the settings app

The main Flutter app will automatically detect and use the enhanced daemon when available.
