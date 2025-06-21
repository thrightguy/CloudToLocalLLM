# CloudToLocalLLM API Documentation

## 📋 Overview

CloudToLocalLLM v3.6.2+ provides comprehensive APIs for bridge communication, streaming proxy management, and service integration. This document covers all available APIs for developers and integrators.

**API Base URLs:**
- **Production**: `https://app.cloudtolocalllm.online/api`
- **Local Development**: `http://localhost:3000/api`

---

## 🔐 **Authentication**

### **Auth0 JWT Authentication**

All API endpoints require valid JWT tokens obtained through Auth0 authentication.

#### **Token Format**
```http
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### **Token Validation**
- **Algorithm**: RS256
- **Issuer**: `https://cloudtolocalllm.auth0.com/`
- **Audience**: `cloudtolocalllm-api`
- **Expiry**: 24 hours

#### **Error Responses**
```json
{
  "error": "unauthorized",
  "message": "Invalid or expired token",
  "code": 401
}
```

---

## 🌉 **Bridge API**

### **Desktop Bridge Communication**

#### **POST /api/bridge/register**
Register a desktop client with the bridge service.

**Request:**
```json
{
  "clientId": "desktop-client-uuid",
  "platform": "linux",
  "version": "3.6.2",
  "capabilities": ["ollama", "streaming", "tray"]
}
```

**Response:**
```json
{
  "success": true,
  "bridgeId": "bridge-uuid",
  "sessionToken": "session-jwt-token",
  "endpoints": {
    "websocket": "wss://app.cloudtolocalllm.online/ws/bridge/bridge-uuid",
    "status": "/api/bridge/bridge-uuid/status"
  }
}
```

#### **GET /api/bridge/{bridgeId}/status**
Get current bridge connection status.

**Response:**
```json
{
  "bridgeId": "bridge-uuid",
  "status": "connected",
  "lastSeen": "2025-06-20T16:52:20.850Z",
  "client": {
    "platform": "linux",
    "version": "3.6.2",
    "ollamaStatus": "connected",
    "models": ["llama3.2:1b", "codellama:7b"]
  }
}
```

#### **POST /api/bridge/{bridgeId}/message**
Send message to desktop client through bridge.

**Request:**
```json
{
  "type": "chat",
  "payload": {
    "model": "llama3.2:1b",
    "messages": [
      {
        "role": "user",
        "content": "Hello, how are you?"
      }
    ],
    "stream": true
  }
}
```

**Response:**
```json
{
  "success": true,
  "messageId": "msg-uuid",
  "status": "queued"
}
```

---

## 🔄 **Streaming Proxy API**

### **Proxy Lifecycle Management**

#### **POST /api/streaming/proxy/create**
Create ephemeral streaming proxy for user session.

**Request:**
```json
{
  "userId": "user-uuid",
  "bridgeId": "bridge-uuid",
  "config": {
    "timeout": 300,
    "maxMemory": "512MB",
    "maxCpu": "0.5"
  }
}
```

**Response:**
```json
{
  "success": true,
  "proxyId": "proxy-uuid",
  "endpoint": "https://proxy-uuid.cloudtolocalllm.online",
  "credentials": {
    "token": "proxy-access-token",
    "expires": "2025-06-20T17:52:20.850Z"
  }
}
```

#### **GET /api/streaming/proxy/{proxyId}/status**
Get streaming proxy status and metrics.

**Response:**
```json
{
  "proxyId": "proxy-uuid",
  "status": "running",
  "uptime": 1800,
  "metrics": {
    "requests": 45,
    "bytesTransferred": 1048576,
    "avgResponseTime": 120,
    "errorRate": 0.02
  },
  "resources": {
    "memoryUsage": "256MB",
    "cpuUsage": "15%"
  }
}
```

#### **DELETE /api/streaming/proxy/{proxyId}**
Terminate streaming proxy and cleanup resources.

**Response:**
```json
{
  "success": true,
  "message": "Proxy terminated and resources cleaned up"
}
```

---

## 💬 **Chat API**

### **Conversation Management**

#### **GET /api/chat/conversations**
List user's chat conversations.

**Query Parameters:**
- `limit`: Number of conversations (default: 50)
- `offset`: Pagination offset (default: 0)
- `sort`: Sort order (`created_desc`, `updated_desc`)

**Response:**
```json
{
  "conversations": [
    {
      "id": "conv-uuid",
      "title": "Chat about AI",
      "created": "2025-06-20T16:00:00.000Z",
      "updated": "2025-06-20T16:30:00.000Z",
      "messageCount": 12,
      "model": "llama3.2:1b"
    }
  ],
  "total": 25,
  "hasMore": true
}
```

#### **POST /api/chat/conversations**
Create new chat conversation.

**Request:**
```json
{
  "title": "New Chat",
  "model": "llama3.2:1b",
  "systemPrompt": "You are a helpful assistant."
}
```

**Response:**
```json
{
  "success": true,
  "conversation": {
    "id": "conv-uuid",
    "title": "New Chat",
    "created": "2025-06-20T17:00:00.000Z",
    "model": "llama3.2:1b"
  }
}
```

#### **POST /api/chat/conversations/{conversationId}/messages**
Send message in conversation.

**Request:**
```json
{
  "content": "What is machine learning?",
  "stream": true
}
```

**Response (Streaming):**
```json
{"type": "start", "messageId": "msg-uuid"}
{"type": "chunk", "content": "Machine learning is"}
{"type": "chunk", "content": " a subset of artificial"}
{"type": "chunk", "content": " intelligence..."}
{"type": "complete", "messageId": "msg-uuid", "totalTokens": 150}
```

---

## 📊 **Health and Monitoring**

### **System Health**

#### **GET /api/health**
Get overall system health status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-06-20T17:00:00.000Z",
  "services": {
    "api": "healthy",
    "database": "healthy",
    "auth": "healthy",
    "streaming": "healthy"
  },
  "metrics": {
    "uptime": 86400,
    "activeConnections": 42,
    "requestsPerMinute": 150
  }
}
```

#### **GET /api/health/detailed**
Get detailed health information for debugging.

**Response:**
```json
{
  "status": "healthy",
  "services": {
    "api": {
      "status": "healthy",
      "responseTime": 15,
      "memoryUsage": "256MB",
      "cpuUsage": "5%"
    },
    "database": {
      "status": "healthy",
      "connections": 10,
      "queryTime": 8
    }
  },
  "infrastructure": {
    "containerCount": 4,
    "networkLatency": 2,
    "diskUsage": "45%"
  }
}
```

---

## 🔌 **WebSocket API**

### **Real-time Communication**

#### **Connection Endpoint**
```
wss://app.cloudtolocalllm.online/ws/{type}/{id}
```

**Types:**
- `bridge/{bridgeId}`: Desktop bridge communication
- `chat/{conversationId}`: Real-time chat updates
- `status/{userId}`: System status updates

#### **Message Format**
```json
{
  "type": "message_type",
  "id": "message-uuid",
  "timestamp": "2025-06-20T17:00:00.000Z",
  "payload": {
    // Type-specific data
  }
}
```

#### **Bridge Messages**
```json
// Desktop → Cloud
{
  "type": "status_update",
  "payload": {
    "ollamaStatus": "connected",
    "models": ["llama3.2:1b"],
    "systemLoad": 0.15
  }
}

// Cloud → Desktop
{
  "type": "chat_request",
  "payload": {
    "model": "llama3.2:1b",
    "messages": [...],
    "stream": true
  }
}
```

---

## 🛠️ **Development Tools**

### **API Testing**

#### **Postman Collection**
Download the complete API collection:
```bash
curl -o cloudtolocalllm-api.json \
  https://raw.githubusercontent.com/imrightguy/CloudToLocalLLM/main/docs/api/postman-collection.json
```

#### **OpenAPI Specification**
```bash
curl https://app.cloudtolocalllm.online/api/docs/openapi.json
```

### **Rate Limiting**

All APIs are rate-limited:
- **Authenticated Users**: 1000 requests/hour
- **Bridge Connections**: 10000 requests/hour
- **Streaming**: 100 concurrent connections

**Rate Limit Headers:**
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

---

## 🔧 **Error Handling**

### **Standard Error Format**
```json
{
  "error": "error_code",
  "message": "Human-readable error message",
  "code": 400,
  "details": {
    "field": "validation_error_details"
  },
  "requestId": "req-uuid"
}
```

### **Common Error Codes**
- `400`: Bad Request - Invalid input
- `401`: Unauthorized - Invalid/missing token
- `403`: Forbidden - Insufficient permissions
- `404`: Not Found - Resource doesn't exist
- `429`: Too Many Requests - Rate limit exceeded
- `500`: Internal Server Error - Server issue

---

**For additional API details, examples, and SDKs, visit the [GitHub repository](https://github.com/imrightguy/CloudToLocalLLM) or check the interactive API documentation at `/api/docs`.**
