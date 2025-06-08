# CloudToLocalLLM System Architecture

## 📋 Overview

CloudToLocalLLM implements a comprehensive multi-component architecture designed for reliability, scalability, and user experience. This document consolidates all architectural information into a single authoritative reference.

**Key Architectural Principles:**
- **Independent Operation**: Components operate independently with graceful degradation
- **Universal Connection Management**: Unified interface for local and cloud connections
- **Multi-Tenant Isolation**: Complete user isolation in cloud environments
- **Zero-Storage Design**: No persistent user data in cloud infrastructure
- **Container-First**: Microservices architecture with Docker containers

---

## 🏗️ **1. Unified Flutter-Native System Tray Architecture**

### **Overview**
CloudToLocalLLM v3.4.0+ implements a unified Flutter-native system tray architecture that integrates system tray functionality directly into the main Flutter application using the `tray_manager` package. This modern approach eliminates external dependencies while providing robust cross-platform system tray support.

### **Core Components**

#### **1.1 Native Tray Service**
- **Technology**: Flutter-native with `tray_manager` package
- **Location**: `lib/services/native_tray_service.dart`
- **Operation**: Integrated within main Flutter application
- **Responsibilities**:
  - Cross-platform system tray integration (Linux/Windows/macOS)
  - Real-time connection status display with visual indicators
  - Context menu management (Show/Hide/Settings/Quit)
  - Integration with tunnel manager service for live updates

#### **1.2 Tunnel Manager Service Integration**
- **Purpose**: Centralized connection and status management
- **Location**: `lib/services/tunnel_manager_service.dart`
- **Features**:
  - Local Ollama connection monitoring
  - Cloud proxy connection management
  - Health checks and automatic reconnection
  - WebSocket support for real-time updates
  - Status broadcasting to system tray

#### **1.3 Unified Application Architecture**
- **Role**: Single Flutter application handling all functionality
- **Integration**: System tray, UI, chat, and connection management in one process
- **Benefits**: Simplified deployment, reduced complexity, single executable

### **Architecture Benefits**
- **Unified Codebase**: All functionality in single Flutter application
- **Native Performance**: Direct Flutter integration without IPC overhead
- **Cross-Platform Consistency**: Same implementation across all platforms
- **Simplified Deployment**: Single executable with no external dependencies
- **Real-Time Updates**: Direct service integration for instant status updates

---

## 🌐 **2. Multi-Tenant Streaming Architecture**

### **Overview**
Production-ready multi-tenant streaming architecture with complete user isolation and minimal cloud footprint, enabling secure, scalable streaming sessions with zero data persistence.

### **Core Components**

#### **2.1 Streaming Proxy Containers**
- **Base Image**: `node:20-alpine` (~50MB each)
- **Resource Limits**: 512MB RAM, 0.5 CPU core
- **Security**: Non-root user execution (proxyuser:1001)
- **Lifecycle**: Ephemeral - auto-created/destroyed per user session

**Features:**
- Zero persistent storage
- WebSocket-based streaming
- JWT authentication validation
- Health monitoring endpoints
- Automatic stale connection cleanup

#### **2.2 Streaming Proxy Manager**
- **Technology**: Docker API integration via dockerode
- **Isolation**: Per-user Docker networks
- **Naming**: Collision-free SHA256-based identifiers
- **Monitoring**: Real-time health checks and activity tracking

**Security Features:**
- Complete network isolation between users
- Automatic cleanup of stale proxies (10-minute inactivity)
- Resource limits enforcement
- Audit logging for all proxy operations

#### **2.3 Enhanced API Backend**
- **Technology**: Node.js with Express framework
- **Responsibilities**:
  - User authentication and authorization
  - Proxy container orchestration
  - WebSocket connection management
  - Health monitoring and metrics

### **Security Architecture**

#### **Zero-Storage Design**
- **No Persistent Data**: All user data remains on local desktop machines
- **Ephemeral Containers**: Streaming proxies auto-destroy on disconnect
- **Memory-Only Processing**: No file system writes in proxy containers
- **Audit Trails**: Session logs only, no user data retention

#### **Multi-Tenant Isolation**
- **Network Isolation**: Per-user Docker networks with unique subnets
- **Container Isolation**: Separate proxy containers per user
- **Resource Isolation**: CPU and memory limits per proxy
- **Authentication Isolation**: JWT validation per streaming session

---

## 🐳 **3. Multi-Container Architecture**

### **Overview**
Modern multi-container architecture providing better separation of concerns, independent deployments, and improved scalability.

### **Container Architecture Diagram**
```
┌─────────────────────────────────────────────────────────────────┐
│                        Nginx Reverse Proxy                     │
│                     (nginx-proxy container)                    │
│                                                                 │
│  *.cloudtolocalllm.online → Route to appropriate container     │
└─────┬─────────────────┬─────────────────┬─────────────────┬─────┘
      │                 │                 │                 │
      ▼                 ▼                 ▼                 ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ Static Site │ │ Flutter App │ │ API Backend │ │   Certbot   │
│ Container   │ │ Container   │ │ Container   │ │ Container   │
│             │ │             │ │             │ │             │
│ • Homepage  │ │ • Web App   │ │ • Bridge    │ │ • SSL Cert  │
│ • Docs      │ │ • Auth UI   │ │   API       │ │   Management│
│ • Downloads │ │ • Chat UI   │ │ • WebSocket │ │             │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

### **Container Responsibilities**

#### **3.1 Nginx Reverse Proxy (`nginx-proxy`)**
- **Purpose**: Central routing and SSL termination
- **Responsibilities**:
  - SSL certificate management
  - Domain-based routing
  - Load balancing and health checks
  - Security headers and rate limiting

#### **3.2 Static Site Container (`static-site`)**
- **Purpose**: Serves static content
- **Responsibilities**:
  - Main website (cloudtolocalllm.online)
  - Documentation site
  - Linux package downloads
  - Static asset serving with caching

#### **3.3 Flutter App Container (`flutter-app`)**
- **Purpose**: Serves the Flutter web application
- **Responsibilities**:
  - Flutter web application (app.cloudtolocalllm.online)
  - Auth0 authentication UI
  - Chat interface
  - Bridge status monitoring

#### **3.4 API Backend Container (`api-backend`)**
- **Purpose**: Handles API requests and WebSocket connections
- **Responsibilities**:
  - Bridge API endpoints
  - WebSocket connection management
  - User authentication and authorization
  - Proxy container orchestration

### **Domain Routing**
| Domain | Container | Purpose |
|--------|-----------|---------|
| `cloudtolocalllm.online` | `static-site` | Main website and homepage |
| `app.cloudtolocalllm.online` | `flutter-app` | Flutter web application |
| `app.cloudtolocalllm.online/api/*` | `api-backend` | API endpoints |
| `app.cloudtolocalllm.online/ws/*` | `api-backend` | WebSocket connections |

---

## 🖥️ **4. Flutter-Native System Tray Implementation**

### **Implementation Details**

#### **4.1 Flutter-Native Architecture**
- **Library**: `tray_manager` package for cross-platform system tray support
- **Integration**: Direct integration within main Flutter application
- **Communication**: Direct service calls within Flutter application
- **Packaging**: Single Flutter executable with integrated tray functionality

#### **4.2 Cross-Platform Support**
- **Linux**: Native system tray integration with desktop environment compatibility
- **Windows**: Native Windows system tray API integration
- **macOS**: NSStatusBar integration through Flutter plugin
- **Icons**: Platform-adaptive icons with connection status indicators

#### **4.3 Service Integration**
```dart
// Direct Flutter service integration
final nativeTray = NativeTrayService();
await nativeTray.initialize(
  tunnelManager: tunnelManager,
  onShowWindow: () => WindowManagerService().showWindow(),
  onHideWindow: () => WindowManagerService().hideToTray(),
  onSettings: () => navigateToSettings(),
  onQuit: () => exitApplication(),
);
```

#### **4.4 Connection Status Integration**
- **Real-Time Updates**: Direct integration with `TunnelManagerService`
- **Visual Indicators**: Dynamic icon changes based on connection status
- **Status Types**: Connected, Disconnected, Connecting, Error states
- **Automatic Updates**: Live status monitoring without polling

### **Menu Structure**
- **Show CloudToLocalLLM**: Bring main window to foreground
- **Hide to Tray**: Minimize application to system tray
- **Connection Status**: Display current connection state
- **Settings**: Open application settings
- **Quit**: Graceful application shutdown

---

## 🔄 **5. Unified Connection Flow Architecture**

### **Local Connection Flow**
```
Flutter App → TunnelManagerService → Local Ollama (localhost:11434)
```

### **Cloud Connection Flow**
```
Flutter App → TunnelManagerService → Cloud Proxy → User's Streaming Container
```

### **Web Platform Connection Flow**
```
Flutter Web → UnifiedConnectionService → Cloud Tunnel → Local Ollama
```

### **Integrated Connection Management**
- **Unified Service**: Single `TunnelManagerService` handles all connection types
- **Real-Time Monitoring**: Continuous health checks with live status updates
- **Automatic Failover**: Seamless switching between local and cloud connections
- **Platform Detection**: Automatic platform-specific connection handling
- **Status Broadcasting**: Real-time updates to system tray and UI components

---

## 📊 **6. Performance Characteristics**

### **Scalability Metrics**
- **Concurrent Users**: 1000+ streaming sessions per VPS
- **Proxy Startup Time**: <5 seconds per container
- **Resource Efficiency**: ~50MB RAM per active user
- **Network Throughput**: Full bandwidth per isolated session

### **Monitoring & Health Checks**
- **Container Health**: HTTP health endpoints every 30 seconds
- **Proxy Activity**: Real-time connection tracking
- **Resource Usage**: Memory and CPU monitoring per proxy
- **Cleanup Automation**: Stale proxy removal every 60 seconds

---

## 🔒 **7. Security Architecture**

### **Authentication & Authorization**
- **JWT Tokens**: Secure token-based authentication
- **Auth0 Integration**: Enterprise-grade authentication provider
- **Token Management**: Automatic refresh and secure storage

### **Network Security**
- **TLS Encryption**: End-to-end encryption for all connections
- **Network Isolation**: Per-user Docker networks
- **Firewall Rules**: Restrictive ingress/egress policies
- **Rate Limiting**: Protection against abuse

### **Data Protection**
- **Zero Persistence**: No user data stored in cloud
- **Local Encryption**: Sensitive data encrypted at rest
- **Audit Logging**: Comprehensive security event logging
- **Compliance**: GDPR/CCPA ready architecture

---

## 🚀 **6. Unified Flutter-Native Architecture Benefits**

### **Development Benefits**
- **Single Codebase**: All functionality in unified Flutter application
- **Simplified Debugging**: No inter-process communication complexity
- **Faster Development**: Direct service integration without IPC protocols
- **Consistent Testing**: Single application testing approach

### **Deployment Benefits**
- **Single Executable**: No external daemon dependencies
- **Simplified Installation**: Standard Flutter application deployment
- **Reduced Package Size**: Elimination of Python runtime and dependencies
- **Platform Consistency**: Same deployment approach across all platforms

### **User Experience Benefits**
- **Faster Startup**: No daemon initialization delays
- **Real-Time Updates**: Instant status updates without polling
- **Reliable Operation**: No daemon communication failures
- **Native Integration**: Platform-native system tray behavior

### **Maintenance Benefits**
- **Unified Updates**: Single application update process
- **Simplified Support**: Single process for troubleshooting
- **Consistent Logging**: Unified logging across all components
- **Reduced Complexity**: Elimination of multi-process architecture

---

This consolidated architecture document provides the complete technical foundation for understanding CloudToLocalLLM's v3.4.0+ unified Flutter-native system design, accurately reflecting the current implementation that eliminates Python dependencies and multi-process complexity.
