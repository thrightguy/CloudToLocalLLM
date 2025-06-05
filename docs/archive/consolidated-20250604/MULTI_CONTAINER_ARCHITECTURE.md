# CloudToLocalLLM Multi-Container Architecture

## Overview

CloudToLocalLLM now uses a modern multi-container architecture that provides better separation of concerns, independent deployments, and improved scalability. This document describes the new architecture and deployment process.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Traffic                         │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                 Nginx Reverse Proxy                             │
│              (cloudtolocalllm-nginx-proxy)                      │
│                                                                 │
│  • SSL Termination (Let's Encrypt)                             │
│  • Domain-based routing                                        │
│  • Rate limiting & security headers                            │
│  • Load balancing & health checks                              │
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

## Container Responsibilities

### 1. Nginx Reverse Proxy (`nginx-proxy`)
- **Purpose**: Entry point for all HTTP/HTTPS traffic
- **Responsibilities**:
  - SSL termination with Let's Encrypt certificates
  - Domain-based routing (cloudtolocalllm.online, app.cloudtolocalllm.online, docs.cloudtolocalllm.online)
  - Rate limiting and security headers
  - Load balancing between backend containers
  - Health checks and failover
- **Port**: 80 (HTTP), 443 (HTTPS)
- **Dependencies**: All backend containers

### 2. Static Site Container (`static-site`)
- **Purpose**: Serves static content (homepage and documentation)
- **Responsibilities**:
  - Main website (cloudtolocalllm.online)
  - Documentation site (docs.cloudtolocalllm.online)
  - Linux package downloads
  - Static asset serving with caching
- **Port**: 80 (internal)
- **Dependencies**: None

### 3. Flutter App Container (`flutter-app`)
- **Purpose**: Serves the Flutter web application
- **Responsibilities**:
  - Flutter web application (app.cloudtolocalllm.online)
  - Auth0 authentication UI
  - Chat interface
  - Bridge status monitoring
- **Port**: 80 (internal)
- **Dependencies**: API Backend for bridge communication

### 4. API Backend Container (`api-backend`)
- **Purpose**: Handles API requests and bridge communication
- **Responsibilities**:
  - Bridge WebSocket connections
  - Auth0 token verification
  - Ollama request proxying
  - Bridge registration and status
- **Port**: 8080 (internal)
- **Dependencies**: None (external Auth0 service)

### 5. Certbot Container (`certbot`)
- **Purpose**: SSL certificate management
- **Responsibilities**:
  - Automatic SSL certificate generation
  - Certificate renewal
  - Let's Encrypt integration
- **Port**: None (runs as needed)
- **Dependencies**: None

## Domain Routing

| Domain | Container | Purpose |
|--------|-----------|---------|
| `cloudtolocalllm.online` | `static-site` | Main website and homepage |
| `docs.cloudtolocalllm.online` | `static-site` | Documentation and downloads |
| `app.cloudtolocalllm.online` | `flutter-app` | Flutter web application |
| `app.cloudtolocalllm.online/api/*` | `api-backend` | API endpoints |
| `app.cloudtolocalllm.online/ws/*` | `api-backend` | WebSocket connections |

## Deployment Benefits

### Independent Deployments
- **Flutter App Updates**: Update only the `flutter-app` container without affecting documentation or main website
- **Documentation Updates**: Update only the `static-site` container without affecting the web application
- **API Changes**: Update only the `api-backend` container without affecting frontend components
- **Configuration Changes**: Update only the `nginx-proxy` container for routing changes

### Zero-Downtime Deployments
- Rolling updates for stateless containers
- Health checks ensure traffic only goes to healthy containers
- Backup and rollback capabilities for each service

### Scalability
- Individual containers can be scaled independently
- Load balancing across multiple instances
- Resource allocation per service

## Deployment Commands

### Full Deployment
```bash
# Deploy all services
./scripts/deploy/deploy-multi-container.sh

# Deploy with rebuild
./scripts/deploy/deploy-multi-container.sh --build

# Deploy with SSL setup
./scripts/deploy/deploy-multi-container.sh --ssl-setup
```

### Service-Specific Updates
```bash
# Update Flutter app only
./scripts/deploy/update-service.sh flutter-app

# Update documentation with zero downtime
./scripts/deploy/update-service.sh static-site --no-downtime

# Update API backend with backup
./scripts/deploy/update-service.sh api-backend --backup

# Rollback nginx proxy
./scripts/deploy/update-service.sh nginx-proxy --rollback
```

### Monitoring and Logs
```bash
# View all service status
docker-compose -f docker-compose.multi.yml ps

# View logs for specific service
docker-compose -f docker-compose.multi.yml logs -f flutter-app

# View logs for all services
docker-compose -f docker-compose.multi.yml logs -f
```

## Configuration Files

### Docker Compose
- `docker-compose.multi.yml` - Main multi-container configuration
- `config/docker/Dockerfile.*` - Individual container definitions

### Nginx Configuration
- `config/nginx/nginx-proxy.conf` - Reverse proxy configuration
- `config/nginx/nginx-static.conf` - Static site nginx config
- `config/nginx/nginx-flutter.conf` - Flutter app nginx config

### SSL Certificates
- `certbot/live/` - Active SSL certificates
- `certbot/archive/` - Certificate archive
- `certbot/www/` - Let's Encrypt challenge files

## Security Features

### SSL/TLS
- Automatic HTTPS redirect
- Modern TLS configuration (TLS 1.2+)
- HSTS headers
- Perfect Forward Secrecy

### Security Headers
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block
- Referrer-Policy: strict-origin-when-cross-origin

### Rate Limiting
- API endpoints: 10 requests/second
- General traffic: 30 requests/second
- Burst handling with queuing

### Container Security
- Non-root users in all containers
- Read-only filesystems where possible
- Minimal attack surface
- Regular security updates

## Monitoring and Health Checks

### Health Check Endpoints
- `/health` - Available on all containers
- Automatic container restart on health check failure
- Load balancer integration

### Logging
- Centralized logging in `logs/` directory
- Service-specific log files
- Structured JSON logging for API backend
- Log rotation and retention

### Metrics
- Container resource usage
- Request rates and response times
- Error rates and status codes
- Bridge connection statistics

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   ```bash
   # Check service status
   docker-compose -f docker-compose.multi.yml ps
   
   # View service logs
   docker-compose -f docker-compose.multi.yml logs service-name
   ```

2. **SSL Certificate Issues**
   ```bash
   # Renew certificates
   docker-compose -f docker-compose.multi.yml --profile ssl-setup run --rm certbot renew
   ```

3. **Bridge Connection Problems**
   ```bash
   # Check API backend logs
   docker-compose -f docker-compose.multi.yml logs api-backend
   
   # Restart API backend
   ./scripts/deploy/update-service.sh api-backend
   ```

### Performance Optimization

1. **Static Asset Caching**
   - 1-year cache for immutable assets
   - No cache for dynamic content
   - Gzip compression enabled

2. **Container Resource Limits**
   - Memory limits prevent OOM issues
   - CPU limits ensure fair resource sharing
   - Health checks detect resource exhaustion

3. **Database Optimization** (if added)
   - Connection pooling
   - Query optimization
   - Index management

## Migration from Single Container

### Migration Steps
1. **Backup Current Deployment**
   ```bash
   docker-compose down
   cp -r . ../cloudtolocalllm-backup
   ```

2. **Update Configuration**
   ```bash
   git pull origin main
   ```

3. **Deploy Multi-Container**
   ```bash
   ./scripts/deploy/deploy-multi-container.sh --build --ssl-setup
   ```

4. **Verify Deployment**
   ```bash
   # Check all services are running
   docker-compose -f docker-compose.multi.yml ps
   
   # Test all domains
   curl -I https://cloudtolocalllm.online
   curl -I https://docs.cloudtolocalllm.online
   curl -I https://app.cloudtolocalllm.online
   ```

### Rollback Plan
If issues occur during migration:
```bash
# Stop new deployment
docker-compose -f docker-compose.multi.yml down

# Restore backup
cd ../cloudtolocalllm-backup
docker-compose up -d
```

## Future Enhancements

### Planned Features
1. **Container Orchestration**
   - Kubernetes deployment option
   - Docker Swarm support
   - Auto-scaling capabilities

2. **Monitoring Stack**
   - Prometheus metrics collection
   - Grafana dashboards
   - Alerting system

3. **CI/CD Integration**
   - Automated testing
   - Deployment pipelines
   - Blue-green deployments

4. **Database Layer**
   - PostgreSQL for user data
   - Redis for caching
   - Database migrations

This multi-container architecture provides a solid foundation for scaling CloudToLocalLLM while maintaining security, performance, and reliability.
