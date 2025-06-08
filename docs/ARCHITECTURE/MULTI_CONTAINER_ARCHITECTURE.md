# CloudToLocalLLM Multi-Container Architecture

## 📋 Overview

CloudToLocalLLM implements a modern multi-container architecture that provides better separation of concerns, independent deployments, and improved scalability. This architecture enables reliable, secure, and maintainable cloud infrastructure for the CloudToLocalLLM platform.

**Key Benefits:**
- **Separation of Concerns**: Each container handles specific functionality
- **Independent Scaling**: Scale components based on demand
- **Fault Isolation**: Container failures don't cascade to other services
- **Zero-Downtime Updates**: Rolling updates without service interruption
- **Security Isolation**: Network and process isolation between services

---

## 🏗️ **Container Architecture Overview**

### **Architecture Diagram**
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
│ Flutter App │ │ API Backend │ │   Certbot   │ │ Streaming   │
│ Container   │ │ Container   │ │ Container   │ │ Proxy Mgr   │
│             │ │             │ │             │ │ Container   │
│ • Web App   │ │ • Bridge    │ │ • SSL Cert  │ │ • Proxy     │
│ • Auth UI   │ │   API       │ │   Management│ │   Lifecycle │
│ • Chat UI   │ │ • WebSocket │ │ • Auto      │ │ • User      │
│ • Marketing │ │ • Streaming │ │   Renewal   │ │   Isolation │
│   Pages     │ │   Proxy Mgr │ │             │ │             │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
                                                       │
                                                       ▼
                                              ┌─────────────┐
                                              │ Ephemeral   │
                                              │ Streaming   │
                                              │ Proxies     │
                                              │ (Per User)  │
                                              └─────────────┘
```

---

## 🐳 **Container Specifications**

### **1. Nginx Reverse Proxy (`nginx-proxy`)**

**Purpose**: Central routing, SSL termination, and load balancing

**Configuration**:
```nginx
# Domain-based routing
server {
    server_name cloudtolocalllm.online;
    location / {
        proxy_pass http://flutter-app:80;
    }
}

server {
    server_name app.cloudtolocalllm.online;
    location / {
        proxy_pass http://flutter-app:80;
    }
    location /api/ {
        proxy_pass http://api-backend:3000;
    }
    location /ws/ {
        proxy_pass http://api-backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

**Responsibilities**:
- SSL certificate management and termination
- Domain-based request routing
- Load balancing and health checks
- Security headers and rate limiting
- Static asset caching and compression

### **2. Flutter App Container (`flutter-app`)**

**Purpose**: Serves the unified Flutter web application

**Build Configuration**:
```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

**Responsibilities**:
- Flutter web application serving (app.cloudtolocalllm.online)
- Marketing homepage (cloudtolocalllm.online)
- Auth0 authentication UI
- Chat interface and settings
- Static asset serving with caching

**Features**:
- Unified Flutter web architecture
- Platform detection (kIsWeb) for feature adaptation
- Responsive design for all screen sizes
- Progressive Web App (PWA) capabilities

### **3. API Backend Container (`api-backend`)**

**Purpose**: Handles API requests, WebSocket connections, and streaming proxy management

**Technology Stack**:
```javascript
// Node.js with Express framework
const express = require('express');
const WebSocket = require('ws');
const dockerode = require('dockerode');

// Core services
- Authentication and authorization
- Bridge API endpoints
- WebSocket connection management
- Streaming proxy orchestration
```

**Responsibilities**:
- Bridge API endpoints for desktop communication
- WebSocket connection management for real-time updates
- User authentication and authorization (Auth0 integration)
- Streaming proxy container orchestration
- Health monitoring and metrics collection

**API Endpoints**:
- `/api/auth/*` - Authentication endpoints
- `/api/bridge/*` - Desktop bridge communication
- `/api/streaming/*` - Streaming proxy management
- `/ws/*` - WebSocket connections

### **4. Certbot Container (`certbot`)**

**Purpose**: Automated SSL certificate management

**Configuration**:
```yaml
certbot:
  image: certbot/certbot
  volumes:
    - ./certbot/conf:/etc/letsencrypt
    - ./certbot/www:/var/www/certbot
  command: certonly --webroot -w /var/www/certbot --email admin@cloudtolocalllm.online -d cloudtolocalllm.online -d app.cloudtolocalllm.online --agree-tos --no-eff-email
```

**Responsibilities**:
- SSL certificate acquisition from Let's Encrypt
- Automatic certificate renewal
- Certificate validation and deployment
- DNS challenge handling for wildcard certificates

### **5. Streaming Proxy Manager Container**

**Purpose**: Manages ephemeral streaming proxy containers

**Core Functionality**:
```javascript
class StreamingProxyManager {
  async createUserProxy(userId) {
    // Create isolated Docker network
    // Deploy ephemeral proxy container
    // Configure security and resource limits
    // Return connection endpoint
  }
  
  async cleanupStaleProxies() {
    // Monitor container activity
    // Remove inactive containers
    // Clean up associated networks
  }
}
```

**Responsibilities**:
- Ephemeral proxy container lifecycle management
- Per-user network isolation
- Resource limit enforcement
- Health monitoring and cleanup
- Security policy enforcement

---

## 🌐 **Domain Routing Strategy**

### **Domain Mapping**
| Domain | Container | Purpose | Features |
|--------|-----------|---------|----------|
| `cloudtolocalllm.online` | `flutter-app` | Marketing homepage | Static content, downloads, documentation |
| `app.cloudtolocalllm.online` | `flutter-app` | Flutter web application | Chat interface, settings, authentication |
| `app.cloudtolocalllm.online/api/*` | `api-backend` | API endpoints | REST API, authentication, bridge communication |
| `app.cloudtolocalllm.online/ws/*` | `api-backend` | WebSocket connections | Real-time updates, streaming |

### **SSL Configuration**
```nginx
# SSL termination at nginx-proxy
ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;

# Security headers
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
```

---

## 🔄 **Container Communication**

### **Internal Network**
```yaml
# Docker Compose network configuration
networks:
  cloudtolocalllm-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### **Service Discovery**
- **DNS-based**: Containers communicate using service names
- **Health Checks**: Built-in health monitoring for all services
- **Load Balancing**: Automatic load distribution for scaled services

### **Data Flow**
```
Client Request → nginx-proxy → flutter-app/api-backend
API Backend → Streaming Proxy Manager → Ephemeral Proxies
Ephemeral Proxies → Desktop Bridge → Local Ollama
```

---

## 📊 **Scalability and Performance**

### **Horizontal Scaling**
```yaml
# Docker Compose scaling configuration
services:
  api-backend:
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

### **Resource Allocation**
- **nginx-proxy**: 256MB RAM, 0.2 CPU cores
- **flutter-app**: 512MB RAM, 0.3 CPU cores
- **api-backend**: 1GB RAM, 0.5 CPU cores (scalable)
- **certbot**: 128MB RAM, 0.1 CPU cores (periodic)

### **Performance Monitoring**
- **Container Metrics**: CPU, memory, network usage
- **Application Metrics**: Response times, error rates
- **Infrastructure Metrics**: Disk usage, network throughput
- **Health Checks**: Automated service health monitoring

---

## 🔒 **Security Architecture**

### **Network Security**
- **Container Isolation**: Each container runs in isolated environment
- **Network Segmentation**: Separate networks for different service tiers
- **Firewall Rules**: Restrictive ingress/egress policies
- **SSL/TLS**: End-to-end encryption for all communications

### **Access Control**
- **Service Authentication**: Inter-service authentication tokens
- **User Authorization**: JWT-based user access control
- **API Rate Limiting**: Protection against abuse and DoS
- **Audit Logging**: Comprehensive security event logging

### **Data Protection**
- **Zero Persistence**: No user data stored in cloud containers
- **Encrypted Transit**: All data encrypted in transit
- **Secure Storage**: Sensitive configuration in encrypted volumes
- **Regular Updates**: Automated security updates for base images

---

## 🛠️ **Deployment and Operations**

### **Deployment Process**
```bash
# Deploy multi-container stack
docker-compose up -d

# Scale specific services
docker-compose up -d --scale api-backend=3

# Rolling updates
docker-compose pull
docker-compose up -d --no-deps api-backend
```

### **Monitoring and Logging**
```bash
# Container status
docker-compose ps

# Service logs
docker-compose logs -f api-backend

# Resource usage
docker stats
```

### **Backup and Recovery**
- **Configuration Backup**: Automated backup of container configurations
- **SSL Certificate Backup**: Secure backup of SSL certificates
- **Database Backup**: Backup of any persistent data
- **Disaster Recovery**: Automated recovery procedures

---

This multi-container architecture provides a robust, scalable, and secure foundation for CloudToLocalLLM's cloud infrastructure while maintaining clear separation of concerns and enabling independent scaling of components.
