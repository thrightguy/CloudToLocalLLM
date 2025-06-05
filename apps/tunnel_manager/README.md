# CloudToLocalLLM Tunnel Manager v1.0.0

**Independent Flutter desktop application for tunnel management and connection brokering**

The Tunnel Manager is a dedicated application that handles all connection brokering between local Ollama instances and CloudToLocalLLM cloud services. It operates independently from the main application and provides comprehensive system integration with proper semantic versioning.

## 🏗️ Architecture Overview

The Tunnel Manager implements a multi-layered architecture:

- **Connection Broker**: Manages connections to local Ollama and cloud services
- **HTTP REST API**: Provides external API for status queries and control
- **Health Monitoring**: Continuous connection health checks and metrics
- **System Integration**: Seamless integration with system tray daemon
- **Configuration Management**: Hot-reloadable configuration with validation

## 🚀 Features

### Core Functionality
- **Universal Connection Management**: Handles both local Ollama (localhost:11434) and cloud proxy connections
- **Persistent Tunnel Management**: Maintains stable connections with automatic reconnection
- **Authentication Token Management**: Secure storage using Flutter's secure storage
- **HTTP REST API Server**: Provides API on localhost:8765 for external applications
- **Real-time Status Updates**: WebSocket support for live connection monitoring

### Advanced Features
- **Connection Pooling**: Optimized request routing with performance optimization
- **Health Monitoring**: Continuous health checks with configurable intervals (5-300 seconds)
- **Metrics Collection**: Comprehensive performance metrics (latency, throughput, error rates)
- **Automatic Recovery**: Crash recovery with SQLite-based state persistence
- **Configuration Hot-reloading**: Update settings without service restart

### System Integration
- **Background Service**: Runs as headless service with optional GUI
- **System Tray Integration**: Communicates with enhanced tray daemon v2.0.0
- **Auto-startup**: Integration via systemd user service (Linux)
- **Desktop Integration**: Material Design 3 GUI for configuration and diagnostics

## 📋 API Reference

### REST API Endpoints

The Tunnel Manager provides a comprehensive REST API on `http://localhost:8765`:

#### Health Check
```
GET /api/health
```
Returns server health status and uptime information.

#### Connection Status
```
GET /api/status
```
Returns detailed status of all tunnel connections including:
- Connection states (connected/disconnected/connecting)
- Endpoint information and versions
- Available models and latency metrics
- Error information and quality indicators

#### Connection Management
```
GET /api/connections
```
Lists all configured connections with detailed status.

#### Performance Metrics
```
GET /api/metrics
```
Returns comprehensive performance metrics:
- API server statistics (requests, success rate)
- Connection latency percentiles (p50, p95, p99)
- Throughput and error rate metrics
- Memory usage and uptime statistics

#### Tunnel Control
```
POST /api/tunnel/start
POST /api/tunnel/stop  
POST /api/tunnel/restart
```
Control tunnel service lifecycle with graceful shutdown handling.

#### Version Information
```
GET /api/version
```
Returns version information for tunnel manager and API compatibility.

### WebSocket API

Real-time updates available via WebSocket connection:
```
ws://localhost:8765/ws
```

Message types:
- `status_update`: Connection status changes
- `model_update`: Available model updates
- `metrics_update`: Performance metrics updates

## ⚙️ Configuration

### Configuration File Location
- **Linux**: `~/.cloudtolocalllm/tunnel_config.json`
- **Windows**: `%LOCALAPPDATA%/CloudToLocalLLM/tunnel_config.json`
- **macOS**: `~/Library/Application Support/CloudToLocalLLM/tunnel_config.json`

### Configuration Options

#### Local Ollama Configuration
```json
{
  "enableLocalOllama": true,
  "ollamaHost": "localhost",
  "ollamaPort": 11434,
  "connectionTimeout": 30
}
```

#### Cloud Proxy Configuration
```json
{
  "enableCloudProxy": true,
  "cloudProxyUrl": "https://app.cloudtolocalllm.online",
  "cloudProxyAudience": "https://api.cloudtolocalllm.online"
}
```

#### API Server Configuration
```json
{
  "apiServerPort": 8765,
  "enableApiServer": true,
  "allowedOrigins": [
    "http://localhost:*",
    "https://app.cloudtolocalllm.online"
  ]
}
```

#### Health Monitoring Configuration
```json
{
  "healthCheckInterval": 30,
  "maxRetries": 5,
  "retryDelay": 2
}
```

#### Performance Configuration
```json
{
  "connectionPoolSize": 10,
  "requestTimeout": 60,
  "enableMetrics": true
}
```

#### UI and Auto-start Configuration
```json
{
  "minimizeToTray": true,
  "startMinimized": false,
  "showNotifications": true,
  "logLevel": "INFO",
  "autoStartTunnel": true,
  "autoStartOnBoot": false
}
```

### Configuration Validation

The tunnel manager validates all configuration options:
- Port ranges (1-65535)
- URL formats (http/https)
- Timeout values (minimum thresholds)
- Log levels (DEBUG, INFO, WARN, ERROR)

## 🔧 Installation & Setup

### Prerequisites
- Flutter 3.5.4 or later
- Dart SDK 3.5.4 or later
- Linux desktop environment (primary target)
- Python 3.7+ (for tray daemon integration)

### Building from Source
```bash
# Build tunnel manager only
./scripts/build/build_tunnel_manager.sh

# Build all applications (recommended)
./scripts/build/build_linux_multi.sh
```

### System Integration
```bash
# Install desktop integration
./install-system-integration.sh

# Manual systemd service setup
cp config/systemd/cloudtolocalllm-tunnel.service ~/.config/systemd/user/
systemctl --user enable cloudtolocalllm-tunnel.service
systemctl --user start cloudtolocalllm-tunnel.service
```

## 🔍 Troubleshooting

### Common Issues

#### Connection Failures
1. **Ollama not detected**: Verify Ollama is running on localhost:11434
2. **Cloud authentication failed**: Check authentication tokens in secure storage
3. **Port conflicts**: Ensure API server port (8765) is available

#### Performance Issues
1. **High latency**: Check network connectivity and health check intervals
2. **Memory usage**: Monitor connection pool size and metrics collection
3. **CPU usage**: Verify health check frequency and logging levels

#### System Integration
1. **Tray daemon communication**: Ensure tray daemon v2.0.0+ is running
2. **Auto-start issues**: Check systemd service configuration and permissions
3. **Desktop integration**: Verify desktop entry installation and icon paths

### Diagnostic Commands
```bash
# Check tunnel manager status
curl http://localhost:8765/api/health

# View detailed connection status
curl http://localhost:8765/api/status | jq

# Monitor performance metrics
curl http://localhost:8765/api/metrics | jq

# Test tunnel control
curl -X POST http://localhost:8765/api/tunnel/restart
```

### Log Files
- **Application logs**: `~/.cloudtolocalllm/tunnel_manager.log`
- **API server logs**: `~/.cloudtolocalllm/api_server.log`
- **System service logs**: `journalctl --user -u cloudtolocalllm-tunnel.service`

## 🔄 Version Compatibility

### Component Compatibility Matrix
- **Main App v3.2.0**: ✅ Compatible
- **Shared Library v3.2.0**: ✅ Required
- **Tray Daemon v2.0.0+**: ✅ Required
- **Ollama v0.9.0+**: ✅ Recommended

### Migration from Previous Versions
The tunnel manager is a new component in v1.0.0. No migration is required for fresh installations.

For systems with existing tray daemon v1.x:
1. Stop existing tray daemon
2. Install tunnel manager v1.0.0
3. Install tray daemon v2.0.0
4. Update configuration files

## 🤝 Integration with Main Application

The tunnel manager integrates seamlessly with the main CloudToLocalLLM application:

1. **Independent Operation**: Runs separately from main app
2. **API Communication**: Main app queries tunnel status via REST API
3. **Shared Authentication**: Uses same Auth0 tokens for cloud connections
4. **Unified Configuration**: Shares configuration directory structure
5. **System Tray Coordination**: Communicates via enhanced tray daemon

## 📊 Performance Benchmarks

### Target Performance Metrics
- **Tunnel Latency**: <100ms for local connections, <500ms for cloud
- **Memory Usage**: <50MB during normal operation
- **CPU Usage**: <5% during idle, <15% during active tunneling
- **API Response Time**: <10ms for status queries
- **Connection Uptime**: >99.9% for stable networks

### Monitoring and Alerting
- Real-time metrics via `/api/metrics` endpoint
- Prometheus-compatible metrics export
- Configurable alert thresholds for latency and error rates
- Integration with system notification centers

## 🔐 Security Considerations

### Authentication and Authorization
- Secure token storage using Flutter's secure storage
- No root privileges required for operation
- Proper sandboxing and process isolation
- Encrypted inter-service communication

### Network Security
- HTTPS-only for cloud connections
- Configurable CORS policies for API server
- Local-only API server binding by default
- Certificate validation for all external connections

## 📈 Future Roadmap

### Planned Features (v1.1.0)
- Advanced load balancing between multiple Ollama instances
- Plugin system for custom connection types
- Enhanced metrics dashboard with charts
- Configuration backup and restore functionality

### Long-term Goals (v2.0.0)
- Multi-user support with user isolation
- Distributed tunnel management across multiple machines
- Advanced caching and request optimization
- Integration with container orchestration platforms

## 📞 Support

For issues, questions, or contributions:
- **GitHub Issues**: [CloudToLocalLLM Issues](https://github.com/imrightguy/CloudToLocalLLM/issues)
- **Documentation**: [cloudtolocalllm.online](https://cloudtolocalllm.online)
- **Community**: Join our Discord server for real-time support

---

**CloudToLocalLLM Tunnel Manager v1.0.0** - Independent tunnel management for your personal AI powerhouse.
