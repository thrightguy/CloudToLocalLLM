# CloudToLocalLLM Administrative Data Flush Guide

## 📋 Overview

The Administrative Data Flush mechanism provides secure administrative functionality to completely clear all user data when needed for maintenance, testing, or emergency scenarios. This system follows CloudToLocalLLM's established architecture patterns and security principles.

**⚠️ CRITICAL WARNING**: Data flush operations permanently delete user data and cannot be undone. Ensure proper authorization and backup procedures before execution.

---

## 🔒 **Security Architecture**

### **Multi-Layer Authentication**
- **Admin Role Validation**: Requires `admin` role in Auth0 user metadata or scopes
- **JWT Token Verification**: Standard Auth0 JWT validation with RS256 algorithm
- **Multi-Step Confirmation**: Secure confirmation token with 5-minute expiration
- **Rate Limiting**: Strict limits on flush operations (3 per hour maximum)

### **Audit Trail**
- **Complete Logging**: All operations logged with timestamps and administrator identification
- **Operation Tracking**: Unique operation IDs for correlation and monitoring
- **Result Documentation**: Detailed results of each flush operation component
- **Error Tracking**: Comprehensive error logging with rollback information

---

## 🏗️ **System Architecture**

### **Backend Components**

#### **AdminDataFlushService** (`api-backend/admin-data-flush-service.js`)
Core service handling all data flush operations:

```javascript
class AdminDataFlushService {
  // Multi-step confirmation with secure tokens
  generateConfirmationToken(adminUserId, targetScope)
  validateConfirmationToken(token, adminUserId, targetScope)
  
  // Data clearing operations
  clearUserAuthenticationData(targetUserId)
  clearUserConversationData(targetUserId)
  clearUserPreferencesData(targetUserId)
  clearUserCacheData(targetUserId)
  clearUserContainersAndNetworks(targetUserId)
  
  // Complete flush execution
  executeDataFlush(adminUserId, confirmationToken, targetUserId, options)
}
```

#### **Administrative API Routes** (`api-backend/routes/admin.js`)
Secure endpoints with proper authentication and rate limiting:

- `GET /api/admin/system/stats` - System statistics
- `POST /api/admin/flush/prepare` - Prepare flush operation
- `POST /api/admin/flush/execute` - Execute flush with confirmation
- `GET /api/admin/flush/history` - Audit trail access
- `POST /api/admin/containers/cleanup` - Emergency container cleanup

### **Frontend Components**

#### **AdminDataFlushService** (`lib/services/admin_data_flush_service.dart`)
Flutter service for administrative operations:

```dart
class AdminDataFlushService extends ChangeNotifier {
  Future<bool> prepareDataFlush({String? targetUserId, String scope})
  Future<bool> executeDataFlush({String? targetUserId, Map<String, bool> options})
  Future<bool> loadFlushHistory({int limit})
  Future<bool> emergencyContainerCleanup()
}
```

#### **AdminDataFlushScreen** (`lib/screens/admin/admin_data_flush_screen.dart`)
Administrative UI with three main tabs:
- **Dashboard**: System statistics and quick actions
- **Data Flush**: Configuration and execution interface
- **Audit Trail**: Operation history and monitoring

---

## 🚀 **Usage Guide**

### **Prerequisites**
1. **Admin Privileges**: User must have `admin` role in Auth0
2. **Valid Authentication**: Active JWT token with proper scopes
3. **Network Access**: Connection to CloudToLocalLLM API backend

### **Step-by-Step Flush Process**

#### **1. Access Administrative Interface**
```dart
// Navigate to admin screen (requires admin privileges)
Navigator.push(context, MaterialPageRoute(
  builder: (context) => const AdminDataFlushScreen(),
));
```

#### **2. Configure Flush Operation**
- **Scope Selection**:
  - `FULL_FLUSH`: Complete system data clearing
  - `USER_SPECIFIC`: Target specific user by ID
  - `CONTAINERS_ONLY`: Docker containers and networks only
  - `AUTH_ONLY`: Authentication data only

- **Options Configuration**:
  - Skip authentication data
  - Skip conversation history
  - Skip user preferences
  - Skip cached data
  - Skip container cleanup

#### **3. Prepare Flush Operation**
```javascript
// Backend: Generate confirmation token
POST /api/admin/flush/prepare
{
  "targetUserId": "user123", // Optional
  "scope": "FULL_FLUSH"
}

// Response includes confirmation token with 5-minute expiration
{
  "confirmationToken": "sha256_hash",
  "expiresAt": "2025-07-01T12:05:00Z",
  "scope": "FULL_FLUSH"
}
```

#### **4. Execute Flush Operation**
```javascript
// Backend: Execute with confirmation token
POST /api/admin/flush/execute
{
  "confirmationToken": "sha256_hash",
  "targetUserId": "user123", // Optional
  "options": {
    "skipAuth": false,
    "skipConversations": false,
    "skipContainers": false
  }
}
```

### **Emergency Container Cleanup**
For immediate container cleanup without full data flush:

```javascript
POST /api/admin/containers/cleanup
// Removes all CloudToLocalLLM containers and networks
```

---

## 📊 **Data Clearing Components**

### **1. Authentication Data**
- **Server-side**: JWT validation cache, session metadata
- **Client-side**: Secure storage tokens, authentication state
- **Scope**: Per-user or system-wide

### **2. Conversation Data**
- **Server-side**: Cached conversation metadata, temporary chat data
- **Client-side**: SQLite database conversations and messages
- **Scope**: Per-user conversation history

### **3. User Preferences**
- **Server-side**: Cached preference data, configuration state
- **Client-side**: Settings, theme preferences, application configuration
- **Scope**: Per-user customization data

### **4. Cache Data**
- **Server-side**: Memory cache, temporary files, session data
- **Client-side**: Application cache, temporary storage
- **Scope**: Performance and temporary data

### **5. Docker Infrastructure**
- **Containers**: User-specific streaming proxy containers
- **Networks**: Isolated user networks with unique subnets
- **Volumes**: Associated data volumes (if any)
- **Labels**: CloudToLocalLLM-specific container labels

---

## 🔍 **Monitoring and Verification**

### **System Statistics**
```javascript
GET /api/admin/system/stats
{
  "totalContainers": 15,
  "userContainers": 8,
  "userNetworks": 8,
  "activeUsers": 8,
  "lastFlushOperation": "2025-07-01T10:30:00Z"
}
```

### **Operation History**
```javascript
GET /api/admin/flush/history?limit=50
{
  "data": [
    {
      "operationId": "uuid",
      "adminUserId": "admin123",
      "targetUserId": "user123",
      "startTime": "2025-07-01T10:30:00Z",
      "endTime": "2025-07-01T10:30:15Z",
      "status": "completed",
      "results": {
        "authentication": { "tokens": 1, "sessions": 1 },
        "conversations": { "conversations": 5, "messages": 150 },
        "containers": { "containers": 2, "networks": 1 }
      }
    }
  ]
}
```

### **Verification Checklist**
After flush operation completion:

- [ ] **Container Cleanup**: Verify all target containers removed
- [ ] **Network Cleanup**: Confirm user networks deleted
- [ ] **Authentication State**: Check token invalidation
- [ ] **Data Persistence**: Verify no residual user data
- [ ] **Audit Logging**: Confirm operation logged properly
- [ ] **System Health**: Validate overall system stability

---

## ⚠️ **Safety Considerations**

### **Pre-Execution Checklist**
- [ ] **Authorization Confirmed**: Proper administrative approval obtained
- [ ] **Backup Completed**: Critical data backed up if necessary
- [ ] **Scope Validated**: Correct target users/scope selected
- [ ] **Impact Assessment**: Understood consequences of operation
- [ ] **Rollback Plan**: Recovery procedures identified

### **Error Handling**
- **Partial Failures**: Individual component failures logged, operation continues
- **Complete Failures**: Full operation rollback where possible
- **Network Issues**: Timeout handling and retry mechanisms
- **Container Errors**: Graceful handling of Docker API failures

### **Rate Limiting**
- **Admin Operations**: 10 requests per 15 minutes
- **Flush Operations**: 3 operations per hour maximum
- **Emergency Cleanup**: Included in admin rate limits

---

## 🧪 **Testing Procedures**

### **Unit Tests**
```bash
# Test data flush service
npm test api-backend/admin-data-flush-service.test.js

# Test administrative routes
npm test api-backend/routes/admin.test.js
```

### **Integration Tests**
```bash
# Test complete flush workflow
npm test tests/integration/admin-flush-integration.test.js

# Test container cleanup
npm test tests/integration/container-cleanup.test.js
```

### **Manual Testing**
1. **Admin Access**: Verify admin role requirement
2. **Token Generation**: Test confirmation token workflow
3. **Flush Execution**: Execute test flush on development data
4. **Audit Trail**: Verify operation logging and history
5. **Error Scenarios**: Test invalid tokens, expired confirmations

---

## 📚 **Integration with Deployment**

### **Deployment Verification Checklist**
Add to existing deployment verification:

- [ ] **Admin Endpoints**: Verify `/api/admin/*` routes accessible
- [ ] **Authentication**: Test admin role validation
- [ ] **Rate Limiting**: Confirm rate limits active
- [ ] **Logging**: Verify audit trail functionality
- [ ] **Container Access**: Test Docker API connectivity
- [ ] **UI Access**: Confirm admin interface loads properly

### **Monitoring Integration**
- **Metrics**: Track flush operation frequency and success rates
- **Alerts**: Monitor for failed flush operations or errors
- **Dashboards**: Include admin operation statistics
- **Logs**: Centralized logging for all administrative actions

---

## 🔧 **Troubleshooting**

### **Common Issues**

#### **Authentication Failures**
```
Error: Admin access required
Solution: Verify user has 'admin' role in Auth0 metadata
```

#### **Token Expiration**
```
Error: Invalid or expired confirmation token
Solution: Generate new confirmation token (5-minute expiration)
```

#### **Container Cleanup Failures**
```
Error: Failed to remove container
Solution: Check Docker daemon status and permissions
```

#### **Rate Limit Exceeded**
```
Error: Flush operation rate limit exceeded
Solution: Wait for rate limit window to reset (1 hour)
```

### **Debug Commands**
```bash
# Check admin service status
curl -H "Authorization: Bearer $TOKEN" \
  https://app.cloudtolocalllm.online/api/admin/health

# View system statistics
curl -H "Authorization: Bearer $TOKEN" \
  https://app.cloudtolocalllm.online/api/admin/system/stats

# Check operation history
curl -H "Authorization: Bearer $TOKEN" \
  https://app.cloudtolocalllm.online/api/admin/flush/history
```

---

## 📞 **Support and Escalation**

For issues with the administrative data flush system:

1. **Check Logs**: Review audit trail and error logs
2. **Verify Permissions**: Confirm admin role assignment
3. **Test Connectivity**: Validate API backend accessibility
4. **Emergency Procedures**: Use emergency container cleanup if needed
5. **Escalation**: Contact system administrators for critical issues

**Remember**: Data flush operations are irreversible. Always verify authorization and scope before execution.
