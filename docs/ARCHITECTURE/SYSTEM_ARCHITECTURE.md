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

## 🏗️ **1. Enhanced System Tray Architecture**

### **Overview**
The Enhanced System Tray Architecture provides independent operation, universal connection management, and enhanced reliability through a completely independent system tray daemon.

### **Core Components**

#### **1.1 Enhanced Tray Daemon**
- **Technology**: Python-based with pystray library
- **Operation**: Independent background service
- **Responsibilities**:
  - Universal connection broker for ALL connections
  - Authentication token management
  - System tray integration and UI
  - Health monitoring and automatic reconnection

#### **1.2 Connection Broker**
- **Purpose**: Centralized connection management
- **Features**:
  - Local Ollama connection handling
  - Cloud proxy connection management
  - Automatic failover between connection types
  - Connection pooling and optimization

#### **1.3 Main Flutter Application**
- **Role**: User interface and chat functionality
- **Dependencies**: Connects through tray daemon broker
- **Benefits**: Crash isolation from connection management

### **Architecture Benefits**
- **Separation of Concerns**: Clear separation between UI and connection management
- **Enhanced Reliability**: Elimination of system tray crashes and segmentation faults
- **Universal Connections**: Seamless switching between local and cloud
- **Persistent Operation**: System tray persists across app restarts

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

## 🖥️ **4. System Tray Implementation**

### **Implementation Details**

#### **4.1 Python-Based Architecture**
- **Library**: pystray for cross-platform system tray support
- **Process Model**: Separate process architecture for crash isolation
- **Communication**: TCP socket IPC with JSON protocol
- **Packaging**: PyInstaller for standalone executables

#### **4.2 Cross-Platform Support**
- **Linux**: libayatana-appindicator3 integration
- **Windows**: Native system tray API
- **macOS**: NSStatusBar integration
- **Icons**: Monochrome/grayscale for theme compatibility

#### **4.3 IPC Communication Protocol**
```json
{
  "command": "SHOW|HIDE|SETTINGS|QUIT|STATUS",
  "data": {
    "authentication_state": "authenticated|unauthenticated",
    "connection_status": "connected|disconnected|error"
  }
}
```

### **Menu Structure**
- **Show/Hide CloudToLocalLLM**: Toggle main application visibility
- **Settings**: Open connection configuration
- **About**: Application information
- **Quit**: Graceful shutdown

---

## 🔄 **5. Connection Flow Architecture**

### **Local Connection Flow**
```
Desktop App → Tray Daemon → Local Ollama (localhost:11434)
```

### **Cloud Connection Flow**
```
Desktop App → Tray Daemon → Cloud Proxy → User's Streaming Container
```

### **Hybrid Connection Management**
- **Automatic Detection**: Tray daemon detects available connections
- **Failover Logic**: Automatic switching between local and cloud
- **Health Monitoring**: Continuous connection health checks
- **User Preference**: Manual override for connection preference

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

This consolidated architecture document provides the complete technical foundation for understanding CloudToLocalLLM's system design, replacing the previous scattered architecture documentation with a single authoritative reference.
