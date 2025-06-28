# CloudToLocalLLM Streaming Proxy Architecture

## 📋 Overview

CloudToLocalLLM implements a sophisticated multi-tenant streaming proxy architecture that enables secure, scalable streaming sessions between web clients and local LLM instances. This architecture provides complete user isolation with minimal cloud footprint and zero data persistence.

**Key Features:**
- **Multi-Tenant Isolation**: Complete user separation with dedicated proxy containers
- **Zero-Storage Design**: No persistent user data in cloud infrastructure
- **Ephemeral Containers**: Auto-created/destroyed per user session
- **WebSocket Streaming**: Real-time bidirectional communication
- **Ngrok Tunnel Integration**: Secure HTTP/HTTPS tunneling as fallback option
- **Resource Efficiency**: Lightweight containers with strict resource limits

---

## 🏗️ **Architecture Components**

### **1. Streaming Proxy Containers**

**Base Configuration**:
- **Base Image**: `node:20-alpine` (~50MB each)
- **Resource Limits**: 512MB RAM, 0.5 CPU core
- **Security**: Non-root user execution (proxyuser:1001)
- **Lifecycle**: Ephemeral - auto-created/destroyed per user session
- **Network**: Isolated per-user Docker networks

**Container Features**:
```javascript
// proxy-server.js - Core functionality
const WebSocket = require('ws');
const http = require('http');

class StreamingProxy {
  constructor(userId, targetUrl) {
    this.userId = userId;
    this.targetUrl = targetUrl;
    this.connections = new Map();
  }
  
  async initialize() {
    // WebSocket server for client connections
    // HTTP proxy for LLM communication
    // Health monitoring endpoints
    // Automatic cleanup on inactivity
  }
}
```

### **2. Streaming Proxy Manager**

**Location**: `api-backend/streaming-proxy-manager.js`

**Core Responsibilities**:
- Docker container orchestration via dockerode
- Per-user network isolation
- Container lifecycle management
- Health monitoring and cleanup
- Resource limit enforcement

**Key Features**:
```javascript
class StreamingProxyManager {
  async createUserProxy(userId, authToken) {
    // Create isolated Docker network
    // Generate collision-free container name
    // Deploy ephemeral proxy container
    // Configure security and resource limits
    // Return connection endpoint
  }
  
  async cleanupStaleProxies() {
    // Monitor container activity
    // Remove inactive containers (10-minute timeout)
    // Clean up associated networks
    // Log cleanup operations
  }
}
```

### **3. Enhanced API Backend**

**Location**: `api-backend/server.js`

**Integration Points**:
- User authentication and authorization
- Proxy container orchestration
- WebSocket connection management
- Health monitoring and metrics
- Audit logging for security

**Authentication Flow**:
```javascript
// JWT validation for streaming sessions
app.use('/api/streaming', authenticateJWT);

// Proxy creation endpoint
app.post('/api/streaming/create', async (req, res) => {
  const userId = req.user.sub;
  const proxy = await proxyManager.createUserProxy(userId, req.token);
  res.json({ endpoint: proxy.endpoint, sessionId: proxy.sessionId });
});
```

---

## 🔒 **Security Architecture**

### **Zero-Storage Design**
- **No Persistent Data**: All user data remains on local desktop machines
- **Ephemeral Containers**: Streaming proxies auto-destroy on disconnect
- **Memory-Only Processing**: No file system writes in proxy containers
- **Audit Trails**: Session logs only, no user data retention

**Data Flow Security**:
```
Web Client → HTTPS/WSS → API Backend → Isolated Proxy → Local Desktop
```

### **Multi-Tenant Isolation**

**Network Isolation**:
- Per-user Docker networks with unique subnets
- No cross-user network communication possible
- Firewall rules enforced at container level
- Network cleanup on session termination

**Container Isolation**:
```dockerfile
# Security configuration in proxy containers
USER proxyuser:1001
WORKDIR /app
ENV NODE_ENV=production
ENV NO_UPDATE_NOTIFIER=true

# Resource limits enforced by Docker
--memory=512m
--cpus=0.5
--network=user-${userId}-network
```

**Authentication Isolation**:
- JWT validation per streaming session
- Token-based access control
- Session-specific authorization
- Automatic token expiration handling

---

## 🌐 **Connection Flow Architecture**

### **Web Client to Local LLM Flow**
```
1. Web Client → Auth0 Authentication
2. API Backend → JWT Validation
3. Proxy Manager → Create User Container
4. Streaming Proxy → Connect to Local Desktop
5. WebSocket Tunnel → Bidirectional Streaming
6. Auto Cleanup → Container Destruction
```

### **Container Lifecycle**
```javascript
// Container creation flow
async createStreamingSession(userId) {
  const network = await this.createUserNetwork(userId);
  const container = await this.deployProxyContainer(userId, network);
  const endpoint = await this.configureProxyEndpoint(container);
  
  // Start health monitoring
  this.startHealthMonitoring(container);
  
  return { endpoint, sessionId: container.id };
}

// Automatic cleanup flow
async monitorAndCleanup() {
  const staleContainers = await this.findInactiveContainers();
  for (const container of staleContainers) {
    await this.destroyContainer(container);
    await this.cleanupNetwork(container.userId);
    this.logCleanupOperation(container);
  }
}
```

### **Health Monitoring**
- **Container Health**: HTTP health endpoints every 30 seconds
- **Connection Activity**: Real-time WebSocket connection tracking
- **Resource Usage**: Memory and CPU monitoring per proxy
- **Cleanup Automation**: Stale proxy removal every 60 seconds

---

## 🔗 **Ngrok Tunnel Integration**

### **Overview**
Ngrok integration provides secure HTTP/HTTPS tunneling as an alternative or complement to the WebSocket bridge architecture, enabling robust fallback when cloud proxy connections fail.

### **Platform Support**
- **Desktop**: Full ngrok tunnel management and process execution
- **Web**: Not supported (web platform acts as bridge server)
- **Mobile**: Limited support (stub implementation)

### **Architecture Integration**
```
Connection Fallback Hierarchy:
1. Local Ollama (if preferred and available)
2. Cloud Proxy (WebSocket bridge - primary)
3. Ngrok Tunnel (fallback for cloud proxy issues)
4. Local Ollama (final fallback)
```

### **Security Features**
- **Auth0 JWT Validation**: Validates user authentication before tunnel access
- **Token Verification**: Checks for valid access tokens
- **Secure URLs**: Provides authenticated tunnel access
- **Access Control**: Prevents unauthorized tunnel usage

### **Configuration Example**
```dart
final config = TunnelConfig(
  enableCloudProxy: true,
  cloudProxyUrl: 'https://app.cloudtolocalllm.online',
  enableNgrok: true,
  ngrokAuthToken: 'your-ngrok-auth-token',
  ngrokProtocol: 'https',
  ngrokLocalPort: 11434,
);
```

### **Tunnel Management**
- **Automatic Startup**: Tunnels start automatically when enabled
- **Health Monitoring**: Continuous tunnel health checks
- **Auto-Reconnection**: Automatic reconnection on failures
- **Resource Cleanup**: Proper cleanup on application exit

### **Use Cases**
- **WebSocket Connectivity Issues**: When cloud proxy WebSocket connections fail
- **Network Restrictions**: Environments with restrictive firewall rules
- **Development/Testing**: Local development with external access needs
- **Backup Connectivity**: Redundant connection option for reliability

---

## 📊 **Performance Characteristics**

### **Scalability Metrics**
- **Concurrent Users**: 1000+ streaming sessions per VPS
- **Proxy Startup Time**: <5 seconds per container
- **Resource Efficiency**: ~50MB RAM per active user
- **Network Throughput**: Full bandwidth per isolated session

### **Resource Management**
```yaml
# Docker Compose resource limits
services:
  streaming-proxy:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 128M
          cpus: '0.1'
```

### **Monitoring and Metrics**
- **Container Metrics**: CPU, memory, network usage per proxy
- **Session Metrics**: Connection duration, data transfer volume
- **Health Metrics**: Success rates, error frequencies
- **Performance Metrics**: Latency, throughput, availability

---

## 🔄 **Integration with Desktop Application**

### **Local Bridge Connection**
```javascript
// Desktop application exposes local bridge
const bridgeServer = http.createServer();
bridgeServer.listen(LOCAL_BRIDGE_PORT, 'localhost');

// Streaming proxy connects to local bridge
const localConnection = new WebSocket(`ws://localhost:${LOCAL_BRIDGE_PORT}`);
```

### **Authentication Handshake**
```javascript
// Secure authentication between proxy and desktop
const authMessage = {
  type: 'auth',
  token: userAuthToken,
  sessionId: proxySessionId,
  timestamp: Date.now()
};

localConnection.send(JSON.stringify(authMessage));
```

### **Bidirectional Streaming**
- **Client to LLM**: Web client messages → Proxy → Desktop → Ollama
- **LLM to Client**: Ollama responses → Desktop → Proxy → Web client
- **Real-Time**: WebSocket streaming for instant communication
- **Error Handling**: Graceful degradation and reconnection

---

## 🛠️ **Development and Operations**

### **Local Development**
```bash
# Start local streaming proxy for testing
cd streaming-proxy
npm install
npm start

# Test proxy functionality
curl http://localhost:3001/health
# Expected: {"status":"healthy","timestamp":"..."}
```

### **Production Deployment**
```bash
# Deploy streaming proxy infrastructure
docker-compose up -d streaming-proxy-manager

# Monitor proxy containers
docker ps --filter "label=cloudtolocalllm.proxy"

# Check proxy logs
docker logs cloudtolocalllm-proxy-${userId}
```

### **Monitoring and Debugging**
```bash
# Monitor active streaming sessions
curl http://api-backend:3000/api/admin/streaming/sessions

# Check container resource usage
docker stats --filter "label=cloudtolocalllm.proxy"

# View cleanup logs
docker logs streaming-proxy-manager | grep cleanup
```

---

This streaming proxy architecture provides a secure, scalable, and efficient solution for connecting web clients to local LLM instances while maintaining complete user isolation and zero data persistence in the cloud infrastructure.
