# CloudToLocalLLM System Tray Daemon

A cross-platform system tray daemon for CloudToLocalLLM that provides reliable system tray functionality with crash isolation from the main Flutter application.

## Architecture

This Python-based daemon implements a separate process architecture that communicates with the main Flutter app via TCP sockets using a JSON protocol. This design provides:

- **Crash Isolation**: Tray daemon failures don't affect the main application
- **Cross-Platform Compatibility**: Works on Linux, Windows, and macOS
- **Reliable Communication**: TCP socket IPC with health monitoring
- **Graceful Degradation**: Main app continues to function if tray is unavailable
- **Automatic Recovery**: Health checks and automatic restart capabilities

## Features

- **System Tray Integration**: Native system tray icon with context menu
- **Monochrome Icons**: Platform-appropriate monochrome icons for better compatibility
- **State Management**: Different icon states (idle, connected, error)
- **Menu Actions**: Show/hide window, settings, quit functionality
- **Health Monitoring**: Automatic health checks and restart on failure
- **Logging**: Comprehensive logging for debugging and monitoring
- **Configuration**: Cross-platform configuration directory support

## Dependencies

- Python 3.7 or later
- `pystray` >= 0.19.4 - Cross-platform system tray library
- `Pillow` >= 9.0.0 - Image processing for icons

## Building

### Manual Build

1. Install dependencies:
   ```bash
   cd tray_daemon
   pip install -r requirements.txt
   pip install pyinstaller
   ```

2. Build executable:
   ```bash
   python build_daemon.py
   ```

### Automated Build

Use the integrated build script:
```bash
./scripts/build/build_tray_daemon.sh
```

This will:
- Check Python installation
- Create virtual environment
- Install dependencies
- Build platform-specific executable
- Test the executable
- Clean up build artifacts

## Usage

### Standalone Usage

```bash
# Start with auto-assigned port
./cloudtolocalllm-tray

# Start with specific port
./cloudtolocalllm-tray --port 8080

# Enable debug logging
./cloudtolocalllm-tray --debug

# Show version
./cloudtolocalllm-tray --version
```

### Integration with Flutter App

The daemon is automatically started by the Flutter app's `SystemTrayManager`. The communication flow is:

1. Flutter app starts the daemon process
2. Daemon writes its TCP port to `~/.cloudtolocalllm/tray_port`
3. Flutter app reads the port and connects via TCP
4. JSON messages are exchanged for tray operations

## IPC Protocol

The daemon communicates with the Flutter app using JSON messages over TCP:

### Commands from Flutter to Daemon

```json
{"command": "UPDATE_TOOLTIP", "text": "CloudToLocalLLM - Connected"}
{"command": "UPDATE_ICON", "state": "connected"}
{"command": "PING"}
{"command": "QUIT"}
```

### Commands from Daemon to Flutter

```json
{"command": "SHOW"}
{"command": "HIDE"}
{"command": "SETTINGS"}
{"command": "QUIT"}
{"response": "PONG"}
```

## File Locations

### Configuration Directory

- **Linux**: `~/.cloudtolocalllm/`
- **Windows**: `%LOCALAPPDATA%\CloudToLocalLLM\`
- **macOS**: `~/Library/Application Support/CloudToLocalLLM/`

### Files

- `tray_port` - Contains the TCP port number for IPC
- `tray.log` - Daemon log file for debugging

### Executable Locations

- **Linux DEB/AUR**: `/usr/bin/cloudtolocalllm-tray`
- **Linux AppImage**: `./bin/cloudtolocalllm-tray`
- **Windows**: `%PROGRAMFILES%\CloudToLocalLLM\bin\cloudtolocalllm-tray.exe`
- **macOS**: `/Applications/CloudToLocalLLM.app/Contents/MacOS/cloudtolocalllm-tray`

## Development

### Local Development

For development and testing without packaging:

```bash
cd tray_daemon
python tray_daemon.py --debug
```

### Testing

The build script includes basic testing:
- Version flag test
- Help flag test
- Executable creation verification

### Debugging

Enable debug logging to see detailed operation:
```bash
./cloudtolocalllm-tray --debug
```

Check the log file for issues:
- Linux: `~/.cloudtolocalllm/tray.log`
- Windows: `%LOCALAPPDATA%\CloudToLocalLLM\tray.log`
- macOS: `~/Library/Application Support/CloudToLocalLLM/tray.log`

## Platform-Specific Notes

### Linux

- Supports both X11 and Wayland (through XWayland)
- Uses monochrome icons for better desktop environment compatibility
- Requires system tray support in the desktop environment

### Windows

- Uses native Windows system tray APIs
- Supports Windows 10 and later
- Icons adapt to light/dark system themes

### macOS

- Uses native macOS menu bar integration
- Supports both Intel and Apple Silicon
- Template images adapt to dark/light menu bar themes

## Troubleshooting

### Common Issues

1. **Daemon not starting**: Check Python installation and dependencies
2. **No tray icon**: Verify desktop environment supports system tray
3. **Connection failed**: Check firewall settings and port availability
4. **Segmentation faults**: This architecture isolates such issues to the daemon

### Error Recovery

The system includes multiple recovery mechanisms:
- Automatic daemon restart on failure (up to 3 attempts)
- Health monitoring with 30-second intervals
- Graceful degradation when tray is unavailable
- Main app continues functioning without tray

## Integration with Build Pipeline

The tray daemon is integrated into CloudToLocalLLM's existing build pipeline:

1. **Development**: Manual build using `build_daemon.py`
2. **CI/CD**: Automated build via `build_tray_daemon.sh`
3. **Packaging**: Binaries included in DEB, AppImage, and AUR packages
4. **Distribution**: Cross-platform binaries via GitHub Actions

This ensures the daemon is available across all supported platforms and distribution methods.
