# CloudToLocalLLM Containerized Architecture

This document outlines the containerized architecture for the CloudToLocalLLM platform deployed on VPS.

## Overview

The CloudToLocalLLM system uses a multi-container architecture with the following components:

1. **Nginx Proxy** - Front-facing reverse proxy that handles all incoming traffic
2. **Portal** - Main Flutter web application 
3. **API Service** - Backend API for the platform
4. **Database** - PostgreSQL database for user data
5. **User Manager** - Service that handles user container creation and management
6. **User Containers** - Individual containers for each user (dynamically created)

## Architecture Diagram

```
                                    +-------------------+
                                    |                   |
                                    |  DNS (Subdomains) |
                                    |                   |
                                    +-------------------+
                                             |
                                             v
+----------------------------------------------------------------------+
|                         VPS Host (Docker Environment)                |
|                                                                      |
|  +--------------+      +--------------+      +--------------+        |
|  |              |      |              |      |              |        |
|  | Nginx Proxy  |----->|    Portal    |      | API Service  |        |
|  |  Container   |      |  Container   |      |  Container   |        |
|  |              |      |              |      |              |        |
|  +--------------+      +--------------+      +--------------+        |
|         |                                            |               |
|         |                                            v               |
|         |                                    +--------------+        |
|         |                                    |              |        |
|         |                                    |  Database    |        |
|         |                                    |  Container   |        |
|         |                                    |              |        |
|         |                                    +--------------+        |
|         |                                            ^               |
|         v                                            |               |
|  +--------------+                           +--------------+         |
|  |              |                           |              |         |
|  | User Manager |-------------------------->| User         |         |
|  |  Container   |                           | Containers   |         |
|  |              |                           |              |         |
|  +--------------+                           +--------------+         |
|                                                                      |
+----------------------------------------------------------------------+
```

## Network Configuration

The system uses two Docker networks:

1. **proxy-network** - Connects the front-facing services (nginx, portal, api)
2. **user-network** - Connects the nginx proxy to user containers

## Container Details

### 1. Nginx Proxy Container

- **Image**: nginx:alpine
- **Purpose**: Handles all HTTP/HTTPS traffic and routes to appropriate services
- **Features**:
  - SSL termination
  - Domain/subdomain routing
  - Static file serving
  - Reverse proxy to services

### 2. Portal Container

- **Purpose**: Serves the main Flutter web application
- **Features**:
  - User authentication and dashboard
  - Management interface

### 3. API Service Container

- **Image**: node:18-alpine
- **Purpose**: Provides RESTful API for the platform
- **Features**:
  - User management endpoints
  - Container provisioning via User Manager
  - Data persistence via Database

### 4. Database Container

- **Image**: postgres:14-alpine
- **Purpose**: Stores all platform data
- **Features**:
  - User authentication data
  - Container metadata
  - User settings and preferences

### 5. User Manager Container

- **Image**: node:18-alpine
- **Purpose**: Manages user containers
- **Features**:
  - Creates containers on demand
  - Monitors container health
  - Resource allocation
  - Lifecycle management

### 6. User Containers

- **Purpose**: Individual environments for each user
- **Features**:
  - Isolated user environment
  - User-specific LLM configuration
  - Accessible via subdomain (username.users.cloudtolocalllm.online)

## Domain and Subdomain Structure

The platform uses the following domain structure:

- **cloudtolocalllm.online** - Main portal
- **api.cloudtolocalllm.online** - API service
- **users.cloudtolocalllm.online** - User landing page
- **{username}.users.cloudtolocalllm.online** - User-specific environments

## SSL Configuration

SSL certificates are managed through Certbot with automatic renewal:

1. Wildcard certificate covers all subdomains
2. Certificate renewal handled via cron jobs
3. Renewal hooks automatically update certificates in Nginx

## Deployment

The entire architecture can be deployed using:

```powershell
.\containers_setup.ps1 "user@your-vps-ip"
```

This script:
1. Builds the Flutter web app locally
2. Sets up the containerized environment on the VPS
3. Configures SSL certificates
4. Creates the Docker networks and containers

## Security Considerations

The architecture incorporates several security measures:

1. **Network Isolation** - Containers only have access to required networks
2. **SSL Everywhere** - All traffic encrypted with HTTPS
3. **Container Isolation** - Users isolated in separate containers
4. **Principle of Least Privilege** - Containers run with minimal permissions
5. **Automatic Updates** - SSL certificates auto-renew

## Future Enhancements

Planned improvements to the architecture:

1. **Container Orchestration** - Migration to Kubernetes for improved scaling
2. **Load Balancing** - For higher throughput and availability
3. **Monitoring** - Prometheus/Grafana for system monitoring
4. **Backup System** - Automated backups for database and user data
5. **CI/CD Pipeline** - Automated deployment and testing 