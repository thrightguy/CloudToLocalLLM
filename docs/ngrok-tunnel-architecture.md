# Ngrok Tunnel Architecture

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Overview](#overview)
3. [Architecture Components](#architecture-components)
4. [Security Integration](#security-integration)
5. [Configuration](#configuration)
6. [Usage Examples](#usage-examples)
7. [Performance Considerations](#performance-considerations)
8. [Migration Guide](#migration-guide)
9. [Troubleshooting](#troubleshooting)
10. [Developer Integration Guide](#developer-integration-guide)
11. [API Reference](#api-reference)
12. [Quick Reference](#quick-reference)
13. [Support and Resources](#support-and-resources)

---

## Quick Start Guide

### Prerequisites
1. **Install ngrok**: Download from [ngrok.com/download](https://ngrok.com/download)
2. **Get auth token**: Sign up at ngrok.com and get your auth token
3. **Authenticate ngrok**: Run `ngrok authtoken YOUR_TOKEN`
4. **Verify installation**: Run `ngrok version`

### Basic Setup (5 minutes)
1. **Open CloudToLocalLLM** and navigate to Tunnel Settings
2. **Enable Ngrok**: Toggle "Enable Ngrok Tunnel" switch
3. **Add Auth Token**: Paste your ngrok auth token (optional for basic usage)
4. **Save Configuration**: Click "Save Configuration"
5. **Test Connection**: Ngrok tunnel will start automatically when cloud proxy fails

### Verification
- Check tunnel status in the connection status card
- Look for "Ngrok Tunnel: Connected" with a public URL
- Test by accessing the tunnel URL (requires authentication)

---

## Overview

CloudToLocalLLM includes ngrok integration as a robust tunneling solution that provides secure HTTP/HTTPS tunneling as an alternative or complement to the existing WebSocket bridge architecture. This integration enables users to expose their local Ollama instances via secure ngrok URLs when WebSocket connections fail or are unavailable.

### Key Benefits
- **Automatic Fallback**: Seamless switching when cloud proxy fails
- **Secure Access**: Auth0 JWT validation for all tunnel access
- **Easy Setup**: Simple configuration through the UI
- **Cross-Platform**: Works on Windows, Linux, and macOS
- **Zero Configuration**: Works out-of-the-box with free ngrok plan

## Architecture Components

### 1. NgrokService Platform Abstraction

The ngrok integration follows CloudToLocalLLM's platform abstraction pattern:

```
NgrokService (Abstract Base)
├── NgrokServicePlatform (Factory)
│   ├── NgrokServiceDesktop (Full Implementation)
│   ├── NgrokServiceMobile (Stub - Limited Support)
│   └── NgrokServiceWeb (Stub - Not Supported)
```

#### Platform Support Matrix

| Platform | Support Level | Description |
|----------|---------------|-------------|
| Desktop (Windows/Linux/macOS) | ✅ Full | Complete ngrok tunnel management |
| Mobile (Android/iOS) | ❌ Limited | Stub implementation, not recommended |
| Web | ❌ Not Supported | Web acts as bridge server, no tunneling needed |

### 2. Integration Points

#### TunnelManagerService Integration
- Ngrok service initialization on desktop platforms
- Health monitoring and automatic reconnection
- Configuration management and updates
- Status reporting and error handling

#### ConnectionManagerService Fallback Hierarchy
1. **Local Ollama** (if preferred and available)
2. **Cloud Proxy** (WebSocket bridge - primary)
3. **Ngrok Tunnel** (fallback for cloud proxy issues)
4. **Local Ollama** (final fallback)

#### TunnelConfig Extension
```dart
class TunnelConfig {
  // Existing cloud proxy settings
  final bool enableCloudProxy;
  final String cloudProxyUrl;
  
  // New ngrok settings
  final bool enableNgrok;
  final String? ngrokAuthToken;
  final String? ngrokSubdomain;
  final String ngrokProtocol;
  final int ngrokLocalPort;
  final String ngrokLocalHost;
}
```

## Security Integration

### Auth0 JWT Validation

The ngrok integration maintains CloudToLocalLLM's security standards through:

1. **Authentication Validation**: Validates user authentication before tunnel access
2. **JWT Token Verification**: Checks for valid Auth0 access tokens
3. **Secure Tunnel URLs**: Provides authenticated tunnel access
4. **Access Control**: Prevents unauthorized tunnel usage

```dart
// Security validation example
final isValid = await ngrokService.validateTunnelAccess();
if (isValid) {
  final secureUrl = ngrokService.getSecureTunnelUrl();
  // Use secure tunnel URL
}
```

### Security Considerations

- **Public Exposure**: Ngrok tunnels expose local services publicly
- **Authentication Required**: Always validate user authentication
- **Token Management**: Secure handling of ngrok auth tokens
- **Access Logging**: Monitor tunnel access and usage

## Configuration

### Basic Configuration

```dart
final config = TunnelConfig(
  enableCloudProxy: true,
  cloudProxyUrl: 'https://app.cloudtolocalllm.online',
  enableNgrok: true,
  ngrokAuthToken: 'your-ngrok-auth-token',
  ngrokProtocol: 'https',
  ngrokLocalPort: 11434,
  ngrokLocalHost: 'localhost',
);
```

### Advanced Configuration

```dart
final config = TunnelConfig(
  enableNgrok: true,
  ngrokAuthToken: 'your-auth-token',
  ngrokSubdomain: 'my-custom-subdomain', // Requires paid plan
  ngrokProtocol: 'https',
  ngrokLocalPort: 11434,
  ngrokLocalHost: '127.0.0.1',
);
```

### Environment Variables

For production deployments, consider using environment variables:

```bash
NGROK_AUTH_TOKEN=your-ngrok-auth-token
NGROK_SUBDOMAIN=your-subdomain
NGROK_PROTOCOL=https
```

## Usage Examples

### Starting Ngrok Tunnel

```dart
final ngrokService = NgrokServicePlatform(authService: authService);
await ngrokService.initialize();

final config = NgrokConfig(
  enabled: true,
  authToken: 'your-auth-token',
  protocol: 'https',
  localPort: 11434,
);

final tunnel = await ngrokService.startTunnel(config);
if (tunnel != null) {
  print('Tunnel URL: ${tunnel.publicUrl}');
}
```

### Monitoring Tunnel Status

```dart
final status = await ngrokService.getTunnelStatus();
print('Tunnel Status: ${status['isRunning']}');
print('Security: ${status['security']}');
print('Public URL: ${status['activeTunnel']?['public_url']}');
```

### Handling Tunnel Failures

```dart
ngrokService.addListener(() {
  if (ngrokService.lastError != null) {
    print('Tunnel Error: ${ngrokService.lastError}');
    // Implement retry logic or fallback
  }
});
```

## Troubleshooting

### Installation Issues

#### 1. Ngrok Not Installed
```
Error: Ngrok is not installed or not found in PATH
```

**Solutions by Platform**:

**Windows**:
```powershell
# Option 1: Download and install manually
# 1. Download from https://ngrok.com/download
# 2. Extract to C:\ngrok\
# 3. Add C:\ngrok\ to PATH environment variable

# Option 2: Using Chocolatey
choco install ngrok

# Option 3: Using Scoop
scoop install ngrok

# Verify installation
ngrok version
```

**macOS**:
```bash
# Option 1: Using Homebrew (recommended)
brew install ngrok/ngrok/ngrok

# Option 2: Using MacPorts
sudo port install ngrok

# Verify installation
ngrok version
```

**Linux**:
```bash
# Option 1: Using Snap (Ubuntu/Debian)
sudo snap install ngrok

# Option 2: Manual installation
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar xvzf ngrok-v3-stable-linux-amd64.tgz
sudo mv ngrok /usr/local/bin

# Option 3: Using package manager (Arch Linux)
yay -S ngrok

# Verify installation
ngrok version
```

#### 2. PATH Configuration Issues
```
Error: 'ngrok' is not recognized as an internal or external command
```

**Solution**:
1. **Find ngrok location**: `where ngrok` (Windows) or `which ngrok` (Unix)
2. **Add to PATH**:
   - **Windows**: Add ngrok directory to System PATH in Environment Variables
   - **macOS/Linux**: Add `export PATH=$PATH:/path/to/ngrok` to `~/.bashrc` or `~/.zshrc`
3. **Restart terminal** and test with `ngrok version`

### Authentication Issues

#### 3. Authentication Failed
```
Error: Authentication failed
```

**Step-by-step Solution**:
1. **Get Auth Token**:
   - Visit [ngrok.com](https://ngrok.com)
   - Sign up for free account
   - Go to "Your Authtoken" section
   - Copy the auth token

2. **Set Auth Token**:
   ```bash
   ngrok authtoken YOUR_AUTH_TOKEN_HERE
   ```

3. **Verify Authentication**:
   ```bash
   ngrok config check
   ```

4. **Check CloudToLocalLLM Auth**:
   - Ensure you're logged in to CloudToLocalLLM
   - Check Auth0 authentication status
   - Verify access token is valid

#### 4. Invalid Auth Token
```
Error: Invalid authtoken
```

**Solution**:
1. **Regenerate Token**: Go to ngrok dashboard and regenerate auth token
2. **Update Token**: Run `ngrok authtoken NEW_TOKEN`
3. **Clear Cache**: Delete `~/.ngrok2/ngrok.yml` and re-authenticate
4. **Update CloudToLocalLLM**: Enter new token in tunnel settings

### Connection Issues

#### 5. Port Already in Use
```
Error: Port 11434 is already in use
```

**Diagnostic Steps**:
```bash
# Check what's using the port
# Windows
netstat -ano | findstr :11434

# macOS/Linux
lsof -i :11434
netstat -tulpn | grep :11434
```

**Solutions**:
1. **Stop Conflicting Service**: Kill the process using the port
2. **Change Ollama Port**: Configure Ollama to use different port
3. **Update CloudToLocalLLM**: Change ngrok local port in settings
4. **Use Different Port**: Configure ngrok to tunnel different port

#### 6. Tunnel Creation Timeout
```
Error: Timeout waiting for ngrok tunnel to become ready
```

**Diagnostic Steps**:
1. **Check Internet**: `ping ngrok.com`
2. **Test Manual Tunnel**: `ngrok http 11434`
3. **Check Firewall**: Ensure ngrok can connect outbound
4. **Verify Ollama**: Ensure Ollama is running on specified port

**Solutions**:
- **Network Issues**: Check firewall and proxy settings
- **Service Issues**: Check ngrok service status at status.ngrok.com
- **Configuration**: Verify local port and host settings
- **Timeout**: Increase timeout in CloudToLocalLLM settings

#### 7. Tunnel Disconnects Frequently
```
Error: Tunnel disconnected unexpectedly
```

**Solutions**:
1. **Upgrade Plan**: Free plan has connection limits
2. **Check Network**: Ensure stable internet connection
3. **Monitor Resources**: Check system resources (CPU/Memory)
4. **Update ngrok**: Ensure latest version is installed

### Debug Information

Enable debug logging to troubleshoot issues:

```dart
// Check ngrok installation
final isInstalled = await ngrokService.isNgrokInstalled();
print('Ngrok Installed: $isInstalled');

// Get version information
final version = await ngrokService.getNgrokVersion();
print('Ngrok Version: $version');

// Get detailed status
final status = await ngrokService.getTunnelStatus();
print('Detailed Status: $status');
```

### Log Analysis

Look for these log patterns:

```
🖥️ [NgrokService] Desktop service initialized
🖥️ [NgrokService] Starting ngrok tunnel...
🖥️ [NgrokService] Tunnel ready: https://abc123.ngrok.io
🖥️ [NgrokService] Tunnel access validated successfully
```

## Performance Considerations

### Connection Type Comparison

| Metric | Local Ollama | Cloud Proxy | Ngrok Tunnel |
|--------|--------------|-------------|--------------|
| **Latency** | ~1-5ms | ~50-200ms | ~100-300ms |
| **Throughput** | Full bandwidth | Limited by VPS | Limited by ngrok |
| **Reliability** | High (local) | Medium (internet) | Medium (internet) |
| **Setup Complexity** | None | Medium | Low |
| **External Dependencies** | None | CloudToLocalLLM VPS | Ngrok service |
| **Security** | Local only | Auth0 + TLS | Auth0 + TLS + ngrok |
| **Cost** | Free | Free | Free/Paid plans |

### Resource Usage

#### Local Ollama
- **Memory**: Ollama process only (~1-4GB depending on model)
- **CPU**: Model inference load
- **Network**: None (local communication)
- **Disk**: Model storage

#### Cloud Proxy (WebSocket Bridge)
- **Memory**: ~10MB for WebSocket client
- **CPU**: Minimal (message forwarding)
- **Network**: Bidirectional streaming to VPS
- **Disk**: None (no local storage)

#### Ngrok Tunnel
- **Memory**: ~50MB for ngrok process + ~10MB for tunnel management
- **CPU**: Minimal overhead for tunnel management
- **Network**: HTTP/HTTPS tunneling overhead
- **Disk**: Ngrok binary (~20MB)

### Performance Benchmarks

#### Typical Latency (Round-trip)
```
Local Ollama:     1-5ms    (baseline)
Cloud Proxy:      50-200ms (depends on location)
Ngrok Tunnel:     100-300ms (additional ngrok overhead)
```

#### Throughput Comparison
```
Local Ollama:     Full local bandwidth (1-10 Gbps)
Cloud Proxy:      VPS bandwidth (100 Mbps - 1 Gbps)
Ngrok Tunnel:     Ngrok limits (varies by plan)
```

#### Connection Establishment Time
```
Local Ollama:     Immediate (if running)
Cloud Proxy:      2-5 seconds (WebSocket handshake)
Ngrok Tunnel:     5-15 seconds (tunnel establishment)
```

### Optimization Tips

#### For All Connection Types
1. **Model Selection**: Use appropriate model size for use case
2. **Request Batching**: Batch multiple requests when possible
3. **Connection Reuse**: Maintain persistent connections
4. **Error Handling**: Implement proper retry logic

#### For Cloud Proxy
1. **Geographic Proximity**: Use VPS close to your location
2. **WebSocket Optimization**: Enable compression if available
3. **Connection Pooling**: Reuse WebSocket connections
4. **Health Monitoring**: Monitor connection quality

#### For Ngrok Tunnel
1. **Use HTTPS**: Better performance and security than HTTP
2. **Custom Subdomain**: Consistent URLs (requires paid plan)
3. **Regional Endpoints**: Use ngrok regions close to you
4. **Connection Limits**: Monitor free plan limits

#### Configuration Recommendations

**For Low Latency (Gaming, Real-time)**:
```dart
// Prefer local, fallback to cloud proxy
TunnelConfig(
  enableCloudProxy: true,
  enableNgrok: false,  // Disable for lowest latency
)
```

**For Reliability (Production)**:
```dart
// Enable all options for maximum reliability
TunnelConfig(
  enableCloudProxy: true,
  enableNgrok: true,
  ngrokProtocol: 'https',
  connectionTimeout: 10,
  healthCheckInterval: 30,
)
```

**For Development (Testing)**:
```dart
// Enable ngrok for external testing
TunnelConfig(
  enableCloudProxy: false,  // Disable cloud for testing
  enableNgrok: true,
  ngrokProtocol: 'http',  // Faster for development
)
```

### Monitoring Performance

#### Key Metrics to Track
```dart
// Connection metrics
- Connection establishment time
- Request/response latency
- Throughput (requests per second)
- Error rates by connection type
- Fallback frequency

// Resource metrics
- Memory usage per connection type
- CPU usage during operations
- Network bandwidth utilization
- Disk I/O (for local Ollama)
```

#### Performance Monitoring Code
```dart
// Example performance monitoring
class ConnectionPerformanceMonitor {
  final Map<String, List<Duration>> _latencyHistory = {};

  void recordLatency(String connectionType, Duration latency) {
    _latencyHistory.putIfAbsent(connectionType, () => []);
    _latencyHistory[connectionType]!.add(latency);

    // Keep only last 100 measurements
    if (_latencyHistory[connectionType]!.length > 100) {
      _latencyHistory[connectionType]!.removeAt(0);
    }
  }

  Duration getAverageLatency(String connectionType) {
    final latencies = _latencyHistory[connectionType] ?? [];
    if (latencies.isEmpty) return Duration.zero;

    final totalMs = latencies
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ latencies.length);
  }
}
```

## Migration Guide

### From WebSocket-Only to Hybrid Architecture

#### Phase 1: Preparation (5 minutes)

1. **Install ngrok**:
   ```bash
   # Choose your platform-specific installation method
   # See Installation Issues section above for detailed instructions
   ngrok version  # Verify installation
   ```

2. **Get ngrok Auth Token**:
   - Visit [ngrok.com](https://ngrok.com) and create account
   - Copy your auth token from the dashboard
   - Run: `ngrok authtoken YOUR_TOKEN`

3. **Backup Current Configuration**:
   - Export current tunnel settings
   - Note current cloud proxy URL and settings
   - Document any custom configurations

#### Phase 2: Enable Ngrok (2 minutes)

1. **Update CloudToLocalLLM Configuration**:
   ```dart
   // In tunnel settings UI or programmatically
   final config = existingConfig.copyWith(
     enableNgrok: true,
     ngrokAuthToken: 'your-ngrok-auth-token',
     ngrokProtocol: 'https',  // Recommended for security
   );
   ```

2. **Verify Configuration**:
   - Open Tunnel Settings in CloudToLocalLLM
   - Toggle "Enable Ngrok Tunnel"
   - Enter your auth token
   - Select HTTPS protocol
   - Save configuration

#### Phase 3: Testing (10 minutes)

1. **Test Normal Operation**:
   ```bash
   # Ensure cloud proxy works normally
   # Check connection status shows "Cloud Proxy: Connected"
   # Test chat functionality
   ```

2. **Test Fallback Behavior**:
   ```bash
   # Method 1: Simulate cloud proxy failure
   # Temporarily disable internet or block cloud proxy URL

   # Method 2: Force ngrok activation
   # Disable cloud proxy in settings temporarily
   # Verify ngrok tunnel activates automatically
   ```

3. **Verify Connection Switching**:
   - Monitor connection status in UI
   - Check logs for fallback messages
   - Test chat functionality on ngrok tunnel
   - Verify authentication works

#### Phase 4: Performance Monitoring (Ongoing)

1. **Compare Connection Types**:
   ```dart
   // Monitor these metrics
   - Latency: Cloud proxy vs ngrok tunnel
   - Throughput: Data transfer rates
   - Reliability: Connection stability
   - Resource usage: CPU and memory impact
   ```

2. **Set Up Monitoring**:
   - Enable debug logging
   - Monitor tunnel health status
   - Track connection switching frequency
   - Document any issues

#### Phase 5: Optimization (Optional)

1. **Upgrade ngrok Plan** (if needed):
   - Custom subdomain for consistent URLs
   - Higher connection limits
   - Better performance

2. **Fine-tune Configuration**:
   ```dart
   final optimizedConfig = TunnelConfig(
     enableCloudProxy: true,
     enableNgrok: true,
     ngrokAuthToken: 'your-token',
     ngrokSubdomain: 'your-custom-subdomain',  // Paid plan
     ngrokProtocol: 'https',
     ngrokLocalPort: 11434,
     connectionTimeout: 15,  // Adjust as needed
     healthCheckInterval: 30,
   );
   ```

### Migration Checklist

- [ ] **Prerequisites Complete**
  - [ ] Ngrok installed and in PATH
  - [ ] Auth token obtained and configured
  - [ ] Current configuration backed up

- [ ] **Configuration Updated**
  - [ ] Ngrok enabled in CloudToLocalLLM
  - [ ] Auth token entered in settings
  - [ ] Protocol set to HTTPS
  - [ ] Configuration saved successfully

- [ ] **Testing Complete**
  - [ ] Normal cloud proxy operation verified
  - [ ] Ngrok fallback behavior tested
  - [ ] Connection switching works correctly
  - [ ] Authentication validated on both connections

- [ ] **Monitoring Established**
  - [ ] Performance metrics baseline established
  - [ ] Logging enabled for troubleshooting
  - [ ] Health monitoring configured
  - [ ] User experience validated

### Rollback Plan

If issues occur during migration:

1. **Immediate Rollback**:
   ```dart
   // Disable ngrok in settings
   final rollbackConfig = currentConfig.copyWith(
     enableNgrok: false,
   );
   ```

2. **Restore Previous Configuration**:
   - Disable ngrok tunnel in UI
   - Verify cloud proxy still works
   - Remove ngrok auth token if desired
   - Document issues for future resolution

3. **Troubleshooting**:
   - Check logs for error messages
   - Verify ngrok installation
   - Test manual ngrok tunnel
   - Contact support if needed

### Best Practices

#### Security
1. **Always Validate Authentication**: Ensure Auth0 integration works
2. **Use HTTPS**: Configure ngrok with HTTPS protocol
3. **Monitor Access**: Track tunnel usage and access patterns
4. **Secure Tokens**: Store ngrok auth tokens securely

#### Performance
1. **Monitor Latency**: Compare connection types regularly
2. **Resource Management**: Clean up tunnels on app exit
3. **Connection Pooling**: Reuse tunnel connections when possible
4. **Health Checks**: Enable automatic reconnection

#### User Experience
1. **Clear Status Indicators**: Show current connection type
2. **Graceful Degradation**: Handle failures transparently
3. **Error Messages**: Provide helpful error information
4. **Documentation**: Keep configuration documented

#### Maintenance
1. **Regular Updates**: Keep ngrok updated to latest version
2. **Token Rotation**: Rotate auth tokens periodically
3. **Configuration Review**: Review settings quarterly
4. **Performance Analysis**: Monitor and optimize regularly

## Developer Integration Guide

### Adding Ngrok Support to New Platforms

If you need to add ngrok support to additional platforms:

1. **Create Platform Service**:
   ```dart
   // lib/services/ngrok_service_newplatform.dart
   class NgrokServiceNewPlatform extends NgrokService {
     @override
     bool get isSupported => true; // or false

     @override
     Future<NgrokTunnel?> startTunnel(NgrokConfig config) async {
       // Platform-specific implementation
     }
   }
   ```

2. **Update Platform Factory**:
   ```dart
   // lib/services/ngrok_service_platform_io.dart
   void _initialize() {
     if (Platform.isNewPlatform) {
       _platformService = NgrokServiceNewPlatform();
     } else if (isMobile) {
       // existing code
     }
   }
   ```

3. **Add Platform Detection**:
   ```dart
   static bool get isNewPlatform => Platform.isNewPlatform;
   ```

### Custom Tunnel Protocols

To add support for new tunnel protocols:

1. **Extend NgrokConfig**:
   ```dart
   class NgrokConfig {
     final String protocol; // Add new protocol options

     // Validation
     bool get isValidProtocol => ['http', 'https', 'tcp', 'tls'].contains(protocol);
   }
   ```

2. **Update Command Builder**:
   ```dart
   List<String> _buildNgrokCommand(NgrokConfig config) {
     final command = ['ngrok'];

     // Add protocol-specific handling
     switch (config.protocol) {
       case 'tcp':
         command.add('tcp');
         break;
       case 'tls':
         command.add('tls');
         break;
       default:
         command.add(config.protocol);
     }
   }
   ```

### Custom Authentication Providers

To integrate with different authentication systems:

1. **Create Auth Provider Interface**:
   ```dart
   abstract class TunnelAuthProvider {
     Future<bool> validateAccess();
     String? getAccessToken();
     bool get isAuthenticated;
   }
   ```

2. **Implement Provider**:
   ```dart
   class CustomAuthProvider implements TunnelAuthProvider {
     @override
     Future<bool> validateAccess() async {
       // Custom validation logic
     }
   }
   ```

3. **Update NgrokService**:
   ```dart
   class NgrokServiceDesktop extends NgrokService {
     final TunnelAuthProvider? _authProvider;

     NgrokServiceDesktop({TunnelAuthProvider? authProvider})
         : _authProvider = authProvider;
   }
   ```

### Testing Custom Implementations

1. **Unit Tests**:
   ```dart
   group('Custom Platform Tests', () {
     test('should support custom platform', () {
       final service = NgrokServiceCustom();
       expect(service.isSupported, true);
     });
   });
   ```

2. **Integration Tests**:
   ```dart
   group('Custom Auth Integration', () {
     test('should validate with custom auth', () async {
       final authProvider = MockCustomAuthProvider();
       final service = NgrokServiceDesktop(authProvider: authProvider);

       when(authProvider.validateAccess()).thenAnswer((_) async => true);

       final isValid = await service.validateTunnelAccess();
       expect(isValid, true);
     });
   });
   ```

### Event Handling and Callbacks

To add custom event handling:

1. **Define Events**:
   ```dart
   enum NgrokEvent {
     tunnelStarted,
     tunnelStopped,
     tunnelError,
     configurationChanged,
   }

   class NgrokEventData {
     final NgrokEvent event;
     final Map<String, dynamic> data;

     NgrokEventData(this.event, this.data);
   }
   ```

2. **Add Event Stream**:
   ```dart
   class NgrokService extends ChangeNotifier {
     final StreamController<NgrokEventData> _eventController =
         StreamController<NgrokEventData>.broadcast();

     Stream<NgrokEventData> get events => _eventController.stream;

     void _emitEvent(NgrokEvent event, Map<String, dynamic> data) {
       _eventController.add(NgrokEventData(event, data));
     }
   }
   ```

3. **Listen to Events**:
   ```dart
   ngrokService.events.listen((event) {
     switch (event.event) {
       case NgrokEvent.tunnelStarted:
         print('Tunnel started: ${event.data['url']}');
         break;
       case NgrokEvent.tunnelError:
         print('Tunnel error: ${event.data['error']}');
         break;
     }
   });
   ```

## API Reference

### NgrokService Methods

#### Core Methods
- `initialize()`: Initialize the ngrok service
- `startTunnel(config)`: Start a new tunnel with given configuration
- `stopTunnel()`: Stop the active tunnel
- `updateConfiguration(config)`: Update tunnel configuration
- `dispose()`: Clean up resources and stop tunnels

#### Status and Monitoring
- `getTunnelStatus()`: Get detailed tunnel status and health information
- `isNgrokInstalled()`: Check if ngrok is installed and available
- `getNgrokVersion()`: Get ngrok version information

#### Security and Validation
- `validateTunnelAccess()`: Validate user authentication for tunnel access
- `getSecureTunnelUrl()`: Get secure tunnel URL with authentication context

#### Properties
- `config`: Current ngrok configuration
- `activeTunnel`: Active tunnel information (null if no tunnel)
- `isRunning`: Whether ngrok tunnel is currently running
- `isStarting`: Whether ngrok tunnel is currently starting
- `lastError`: Last error message (null if no error)
- `isSupported`: Whether ngrok is supported on current platform
- `isTunnelSecure`: Whether tunnel has authentication enabled

### NgrokConfig Properties

#### Basic Configuration
- `enabled`: Enable/disable ngrok tunneling
- `protocol`: Tunnel protocol ('http', 'https', 'tcp')
- `localPort`: Local port to expose (default: 11434)
- `localHost`: Local host address (default: 'localhost')

#### Authentication
- `authToken`: Ngrok authentication token (optional for basic usage)

#### Advanced Options
- `subdomain`: Custom subdomain (requires paid plan)
- `additionalOptions`: Map of additional ngrok command-line options

#### Factory Methods
- `NgrokConfig.defaultConfig()`: Create default configuration
- `copyWith()`: Create copy with updated values

### NgrokTunnel Properties

#### Tunnel Information
- `publicUrl`: Public tunnel URL (e.g., 'https://abc123.ngrok.io')
- `localUrl`: Local service URL (e.g., 'localhost:11434')
- `protocol`: Tunnel protocol ('http', 'https', 'tcp')
- `subdomain`: Tunnel subdomain (if custom subdomain used)
- `createdAt`: Tunnel creation timestamp
- `isActive`: Tunnel active status

#### Serialization
- `fromJson(Map<String, dynamic>)`: Create tunnel from JSON data
- `toJson()`: Convert tunnel to JSON format
- `toString()`: String representation for debugging

### TunnelConfig Extensions

#### Ngrok Integration
- `enableNgrok`: Enable ngrok tunnel as fallback option
- `ngrokAuthToken`: Ngrok authentication token
- `ngrokSubdomain`: Custom subdomain for ngrok tunnel
- `ngrokProtocol`: Protocol for ngrok tunnel
- `ngrokLocalPort`: Local port for ngrok tunnel
- `ngrokLocalHost`: Local host for ngrok tunnel

#### Conversion
- `toNgrokConfig()`: Convert TunnelConfig to NgrokConfig for ngrok service

## Quick Reference

### Configuration Examples

#### Basic Setup (Free Plan)
```dart
TunnelConfig(
  enableNgrok: true,
  ngrokProtocol: 'http',
  ngrokLocalPort: 11434,
  ngrokLocalHost: 'localhost',
)
```

#### Advanced Setup (Paid Plan)
```dart
TunnelConfig(
  enableNgrok: true,
  ngrokAuthToken: 'your-auth-token',
  ngrokSubdomain: 'my-ollama',
  ngrokProtocol: 'https',
  ngrokLocalPort: 11434,
  ngrokLocalHost: 'localhost',
)
```

#### Development Setup
```dart
TunnelConfig(
  enableNgrok: true,
  ngrokAuthToken: 'dev-token',
  ngrokProtocol: 'http',
  ngrokLocalPort: 8080,
  ngrokLocalHost: '127.0.0.1',
)
```

### Status Monitoring

```dart
// Check tunnel status
final status = await ngrokService.getTunnelStatus();
print('Running: ${status['isRunning']}');
print('URL: ${status['activeTunnel']?['public_url']}');
print('Security: ${status['security']['accessValidated']}');

// Monitor for changes
ngrokService.addListener(() {
  if (ngrokService.isRunning) {
    print('Tunnel active: ${ngrokService.activeTunnel?.publicUrl}');
  } else if (ngrokService.lastError != null) {
    print('Tunnel error: ${ngrokService.lastError}');
  }
});
```

### Common Commands

```bash
# Install ngrok
# Windows: Download from https://ngrok.com/download
# macOS: brew install ngrok
# Linux: snap install ngrok

# Authenticate ngrok
ngrok authtoken YOUR_AUTH_TOKEN

# Test local tunnel manually
ngrok http 11434

# Check ngrok status
ngrok status
```

## Support and Resources

### Official Documentation

#### CloudToLocalLLM Documentation
- **Main Repository**: [github.com/imrightguy/CloudToLocalLLM](https://github.com/imrightguy/CloudToLocalLLM)
- **Issue Tracker**: [CloudToLocalLLM Issues](https://github.com/imrightguy/CloudToLocalLLM/issues)
- **Architecture Documentation**:
  - [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
  - [Streaming Proxy Architecture](docs/ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)
  - [Multi-Container Architecture](docs/ARCHITECTURE/MULTI_CONTAINER_ARCHITECTURE.md)
- **User Documentation**:
  - [User Guide](docs/USER_DOCUMENTATION/USER_GUIDE.md)
  - [Installation Guide](docs/USER_DOCUMENTATION/INSTALLATION_GUIDE.md)
  - [Troubleshooting Guide](docs/USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)

#### Ngrok Documentation
- **Official Docs**: [ngrok.com/docs](https://ngrok.com/docs)
- **Getting Started**: [ngrok.com/docs/getting-started](https://ngrok.com/docs/getting-started)
- **Authentication**: [ngrok.com/docs/secure-tunnels/ngrok-agent/reference/config](https://ngrok.com/docs/secure-tunnels/ngrok-agent/reference/config)
- **Troubleshooting**: [ngrok.com/docs/troubleshooting](https://ngrok.com/docs/troubleshooting)
- **Status Page**: [status.ngrok.com](https://status.ngrok.com)

### Community and Support

#### Getting Help
1. **Search Existing Issues**: Check [GitHub Issues](https://github.com/imrightguy/CloudToLocalLLM/issues) first
2. **Create New Issue**: Use issue templates for bug reports or feature requests
3. **Community Discussions**: Join discussions in the repository
4. **Documentation**: Check this guide and related documentation

#### Reporting Issues
When reporting ngrok-related issues, please include:
- **Platform**: Windows/macOS/Linux version
- **Ngrok Version**: Output of `ngrok version`
- **CloudToLocalLLM Version**: Check in app settings
- **Configuration**: Sanitized tunnel configuration (remove auth tokens)
- **Error Messages**: Complete error messages and logs
- **Steps to Reproduce**: Detailed reproduction steps

#### Contributing
- **Code Contributions**: Follow the contribution guidelines in the repository
- **Documentation**: Help improve documentation with corrections and additions
- **Testing**: Report bugs and test new features
- **Feature Requests**: Suggest improvements through GitHub issues

### Related Technologies

#### Auth0 Integration
- **Auth0 Documentation**: [auth0.com/docs](https://auth0.com/docs)
- **Flutter Auth0**: [auth0.com/docs/quickstart/native/flutter](https://auth0.com/docs/quickstart/native/flutter)
- **JWT Validation**: [jwt.io](https://jwt.io)

#### Flutter Development
- **Flutter Documentation**: [flutter.dev/docs](https://flutter.dev/docs)
- **Dart Documentation**: [dart.dev/guides](https://dart.dev/guides)
- **Platform Channels**: [flutter.dev/docs/development/platform-integration/platform-channels](https://flutter.dev/docs/development/platform-integration/platform-channels)

#### Ollama Integration
- **Ollama Documentation**: [ollama.ai/docs](https://ollama.ai/docs)
- **Ollama API**: [github.com/ollama/ollama/blob/main/docs/api.md](https://github.com/ollama/ollama/blob/main/docs/api.md)
- **Model Library**: [ollama.ai/library](https://ollama.ai/library)

### Useful Tools and Utilities

#### Network Debugging
- **Wireshark**: Network packet analysis
- **curl**: Command-line HTTP testing
- **Postman**: API testing and development
- **ngrok Inspector**: Built-in request inspector at http://localhost:4040

#### Development Tools
- **Flutter DevTools**: Flutter debugging and profiling
- **Dart DevTools**: Dart debugging and analysis
- **VS Code Extensions**: Flutter and Dart extensions
- **Android Studio**: Full Flutter IDE support

### Frequently Asked Questions

#### Q: Do I need a paid ngrok plan?
**A**: No, the free plan works for basic usage. Paid plans offer custom subdomains, more concurrent tunnels, and higher bandwidth limits.

#### Q: Is ngrok secure for production use?
**A**: Yes, when properly configured with HTTPS and authentication. CloudToLocalLLM adds Auth0 JWT validation for additional security.

#### Q: Can I use ngrok with custom domains?
**A**: Yes, with paid ngrok plans you can use custom domains and subdomains.

#### Q: What happens if ngrok fails?
**A**: CloudToLocalLLM automatically falls back to other connection types (cloud proxy or local Ollama) based on availability.

#### Q: How do I monitor ngrok performance?
**A**: Use the built-in tunnel status monitoring in CloudToLocalLLM and ngrok's web interface at http://localhost:4040.

### Version Compatibility

| CloudToLocalLLM Version | Ngrok Version | Notes |
|------------------------|---------------|-------|
| 1.0.0+ | 3.0+ | Recommended for best compatibility |
| 1.0.0+ | 2.3+ | Supported with limited features |
| Future versions | 3.x+ | Will maintain backward compatibility |

### License and Legal

- **CloudToLocalLLM**: Check repository license
- **Ngrok**: Commercial service with free tier
- **Auth0**: Commercial service with free tier
- **Flutter**: BSD 3-Clause License
- **Ollama**: MIT License

---

*Last updated: 2024-06-28*
*For the most current information, always refer to the official documentation and repositories.*
