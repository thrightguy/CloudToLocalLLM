# Zrok Tunnel Integration with Multi-Tenant Docker Environment

This implementation provides a complete solution for integrating zrok tunnels with CloudToLocalLLM's multi-tenant Docker architecture, enabling seamless container-to-desktop tunnel communication.

## 🏗️ Architecture Overview

### Hybrid Desktop-Container Architecture

The implementation uses a **Hybrid Desktop-Container Architecture** that:
- Maintains existing desktop zrok functionality
- Enables containers to discover and proxy through desktop zrok tunnels
- Preserves container isolation while adding zrok capabilities
- Provides robust fallback and recovery mechanisms

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │  API Backend    │    │ Desktop Client  │
│                 │    │                 │    │                 │
│ Connection      │◄──►│ Zrok Registry   │◄──►│ Zrok Service    │
│ Manager         │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Streaming Proxy │    │ Container       │    │ Zrok Tunnel     │
│ Container       │    │ Discovery       │    │ (localhost:11434│
│                 │    │                 │    │  → public URL)  │
│ Zrok Discovery  │◄──►│ Service         │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Implementation Components

### 1. API Backend Foundation (`api-backend/`)

#### Zrok Tunnel Registry (`zrok-registry.js`)
- **Purpose**: Central registry for zrok tunnel management
- **Features**:
  - User-specific tunnel registration from desktop clients
  - Container discovery of available zrok tunnels
  - Health monitoring and automatic cleanup
  - JWT-based authentication and authorization

#### API Routes (`routes/zrok.js`)
- **Endpoints**:
  - `POST /api/zrok/register` - Register tunnel from desktop
  - `GET /api/zrok/discover` - Discover tunnels for authenticated user
  - `GET /api/zrok/discover/:userId` - Container-specific discovery
  - `POST /api/zrok/heartbeat` - Update tunnel heartbeat
  - `DELETE /api/zrok/unregister` - Unregister tunnel
  - `GET /api/zrok/health/:tunnelId` - Get tunnel health status

### 2. Container Integration (`streaming-proxy/`)

#### Zrok Discovery Service (`zrok-discovery.js`)
- **Purpose**: Discovers and manages zrok tunnel connections within containers
- **Features**:
  - Automatic discovery of user-specific zrok tunnels
  - Health monitoring and connection management
  - Fallback to cloud proxy when zrok unavailable
  - Container-specific authentication

#### Enhanced Proxy Server (`proxy-server.js`)
- **Enhancements**:
  - Integrated zrok discovery on container startup
  - Health monitoring endpoints with zrok status
  - Graceful shutdown with zrok cleanup
  - Environment-based configuration

### 3. Desktop Client Enhancement (`lib/services/`)

#### Enhanced Zrok Service (`zrok_service_desktop.dart`)
- **New Features**:
  - Automatic tunnel registration with API backend
  - Health monitoring and recovery mechanisms
  - Registration heartbeat for tunnel maintenance
  - Comprehensive error handling and logging

## 📋 Usage Instructions

### 1. API Backend Setup

```bash
# Install dependencies
cd api-backend
npm install

# Start the API backend with zrok support
npm start
```

The API backend will:
- Initialize the zrok tunnel registry
- Expose zrok management endpoints
- Handle authentication and authorization
- Provide health monitoring and cleanup

### 2. Container Deployment

```bash
# Build the enhanced streaming proxy image
cd streaming-proxy
docker build -t cloudtolocalllm-streaming-proxy:latest .

# Deploy with zrok discovery enabled
docker run -d \
  --name streaming-proxy-user123 \
  -e USER_ID=user123 \
  -e ZROK_DISCOVERY_ENABLED=true \
  -e API_BASE_URL=http://api-backend:8080 \
  cloudtolocalllm-streaming-proxy:latest
```

The container will:
- Automatically discover user's zrok tunnels
- Monitor tunnel health and connectivity
- Provide fallback to cloud proxy mode
- Report status via health endpoints

### 3. Desktop Client Integration

```dart
// Initialize zrok service with API backend integration
final zrokService = ZrokServiceDesktop(authService: authService);
await zrokService.initialize();

// Start tunnel with automatic registration
final tunnel = await zrokService.startTunnel(ZrokConfig(
  enabled: true,
  accountToken: 'your-zrok-token',
  protocol: 'http',
  localPort: 11434,
));

// Tunnel is automatically registered with API backend
// Containers can now discover and use this tunnel
```

### 4. Flutter App Connection

```dart
// Connection manager automatically uses container-discovered zrok tunnels
final connectionManager = ConnectionManagerService(
  localOllama: localOllamaService,
  tunnelManager: tunnelManagerService,
  authService: authService,
);

// Get best available connection (includes zrok tunnels)
final connectionType = connectionManager.getBestConnectionType();
final streamingService = connectionManager.getStreamingService();
```

## 🔧 Configuration

### Environment Variables

#### API Backend
```bash
# API Backend Configuration
PORT=8080
AUTH0_DOMAIN=your-auth0-domain
AUTH0_AUDIENCE=your-auth0-audience
LOG_LEVEL=info
```

#### Streaming Proxy Container
```bash
# Container Configuration
USER_ID=user-123
PROXY_ID=proxy-abc
ZROK_DISCOVERY_ENABLED=true
API_BASE_URL=http://api-backend:8080
LOG_LEVEL=info
```

#### Desktop Client
```dart
// AppConfig.dart
class AppConfig {
  static const String apiBaseUrl = 'https://api.cloudtolocalllm.online';
  // ... other configuration
}
```

## 🧪 Testing

### Run Integration Test

```bash
# Run the comprehensive integration test
node test_zrok_integration.js
```

This test demonstrates:
- ✅ Zrok Registry initialization
- ✅ Desktop client tunnel registration
- ✅ Container tunnel discovery
- ✅ Connection management
- ✅ Health monitoring
- ✅ Heartbeat updates
- ✅ Registry statistics
- ✅ Cleanup and unregistration

### Manual Testing

1. **Start API Backend**:
   ```bash
   cd api-backend && npm start
   ```

2. **Deploy Container**:
   ```bash
   docker run -d --name test-proxy \
     -e USER_ID=test-user \
     -e ZROK_DISCOVERY_ENABLED=true \
     cloudtolocalllm-streaming-proxy:latest
   ```

3. **Register Tunnel** (via desktop client or API):
   ```bash
   curl -X POST http://localhost:8080/api/zrok/register \
     -H "Authorization: Bearer your-jwt-token" \
     -H "Content-Type: application/json" \
     -d '{"tunnelInfo": {"publicUrl": "https://test.share.zrok.io", "localUrl": "http://localhost:11434", "shareToken": "test-token"}}'
   ```

4. **Check Discovery**:
   ```bash
   curl http://localhost:8080/api/zrok/discover \
     -H "Authorization: Bearer your-jwt-token"
   ```

## 🔄 Connection Fallback Hierarchy

The enhanced connection manager follows this hierarchy:

1. **Local Ollama** (Direct localhost:11434)
2. **Cloud Proxy with Zrok** (Container with discovered zrok tunnel)
3. **Cloud Proxy** (Container without zrok)
4. **Direct Zrok** (Fallback direct tunnel)
5. **Cloud Fallback** (Final fallback)

## 🛡️ Security Features

- **JWT Authentication**: All API endpoints require valid Auth0 tokens
- **Container Isolation**: Each user gets isolated Docker networks
- **Token Validation**: Container tokens validated for discovery requests
- **Health Monitoring**: Automatic detection and recovery from failures
- **Audit Logging**: Comprehensive logging of all tunnel operations

## 🔍 Monitoring and Debugging

### Health Endpoints

- `GET /health` - API backend health with zrok registry stats
- `GET /metrics` - Container metrics with zrok discovery status
- `GET /zrok/status` - Container-specific zrok status

### Logging

All components use structured logging with service-specific prefixes:
- `🌐 [ZrokRegistry]` - API backend registry operations
- `🌐 [ZrokDiscovery]` - Container discovery operations
- `🌐 [ZrokService]` - Desktop client operations
- `🔗 [ConnectionManager]` - Flutter app connection management

## 🚀 Next Steps

This implementation provides a working proof-of-concept that demonstrates:

1. ✅ **Complete Integration**: Desktop ↔ API Backend ↔ Container communication
2. ✅ **Health Monitoring**: Automatic detection and recovery from failures
3. ✅ **Multi-Tenant Support**: Isolated per-user tunnel management
4. ✅ **Robust Fallback**: Graceful degradation when zrok unavailable
5. ✅ **Production Ready**: Comprehensive error handling and logging

The architecture is ready for production deployment and provides immediate value by enabling zrok tunnels to work seamlessly within the multi-tenant Docker environment.
