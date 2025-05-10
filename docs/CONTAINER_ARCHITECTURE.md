# CloudToLocalLLM Containerized Architecture

This document outlines the current containerized architecture for the CloudToLocalLLM platform deployed on a VPS, managed by the `admin_control_daemon`.

## Overview

The system utilizes Docker and Docker Compose for service orchestration. The key components are:

1.  **Admin Control Daemon (`admin_control_daemon`)**: A Dart-based application running in its own Docker container. It acts as the primary manager for the rest of the application stack. It exposes an API (default port 9001) to control deployment, status, and logs of other services.
    *   **Dockerfile**: `config/docker/Dockerfile.admin_daemon`
    *   **Compose File**: `config/docker/docker-compose.admin.yml` (used by `scripts/setup/docker_startup_vps.sh` to launch the daemon itself)

2.  **Main Application Services**: These are defined in `config/docker/docker-compose.yml` and managed by the `admin_control_daemon`.
    *   **Web Application (`webapp`)**:
        *   **Purpose**: Serves the main Flutter web application and handles user-facing HTTP/HTTPS traffic.
        *   **Components**: Contains Nginx acting as a reverse proxy and web server for the Flutter web build.
        *   **Dockerfile**: `config/docker/Dockerfile.web` (builds Flutter web app and configures Nginx).
        *   **SSL**: Configured for self-signed certificates by default (generated in `Dockerfile.web`). Can be configured for Let's Encrypt or commercial certificates (see `docs/DEPLOYMENT.MD`).

    *   **FusionAuth (`cloudtolocalllm-fusionauth-app`)**:
        *   **Purpose**: Provides identity and access management (IAM).
        *   **Image**: `fusionauth/fusionauth-app` (official image).
        *   **Configuration**: Managed via environment variables in `config/docker/docker-compose.yml` and persistent data in a Docker volume (`fusionauth_config`).

    *   **FusionAuth Database (`cloudtolocalllm-fusionauth-db`)**:
        *   **Purpose**: PostgreSQL database for FusionAuth.
        *   **Image**: `postgres` (official image).
        *   **Configuration**: Managed via environment variables and persistent data in a Docker volume (`fusionauth_postgres_data`).

    *   **Tunnel Service (`tunnel_service`)** (Optional - REVIEW if actively integrated and deployed):
        *   **Purpose**: Potentially provides ngrok-like tunneling capabilities for remote access to local LLMs.
        *   **Location**: `backend/tunnel_service/`
        *   **Dockerfile**: `backend/tunnel_service/Dockerfile` (if it exists and is used).
        *   **Note**: Its integration into the main `docker-compose.yml` and deployment flow needs to be confirmed.

## Network Configuration

-   A primary Docker network, typically named `cloudllm-network` (as created by `docker-compose.yml` with project name `ctl_services`), connects the main application services (`webapp`, `fusionauth-app`, `fusionauth-db`, etc.).
-   The `admin_control_daemon` container also attaches to this network (or a relevant one) to communicate with the Docker daemon and manage other containers.

## Deployment Flow Summary

1.  The `scripts/setup/docker_startup_vps.sh` script is run on the VPS.
2.  This script starts the `admin_control_daemon` container using `config/docker/docker-compose.admin.yml`.
3.  The script then calls an API endpoint on the `admin_control_daemon`.
4.  The `admin_control_daemon` uses `config/docker/docker-compose.yml` to bring up (build if necessary, then run) the `webapp`, FusionAuth services, and any other defined application services.

## Domain and SSL

-   The primary domain (e.g., `cloudtolocalllm.online`) points to the `webapp` service (Nginx).
-   SSL is handled by Nginx within the `webapp` container. See `docs/DEPLOYMENT.MD` for SSL configuration options (self-signed, Let's Encrypt, commercial).

## Security Considerations

-   **Network Segregation**: Services are on a defined Docker network.
-   **Admin Daemon**: Access to the admin daemon's API should be restricted (e.g., firewall rules on the VPS, though it currently listens on localhost by default as per `docker_startup_vps.sh` interaction).
-   **Secrets Management**: Passwords and sensitive data (e.g., for FusionAuth DB) are currently in `docker-compose.yml`. For production, consider using Docker secrets or environment variable injection through more secure means.
-   **Regular Updates**: Keep base Docker images and application dependencies updated.

## Future Enhancements

Planned improvements to the architecture:

1. **Container Orchestration** - Migration to Kubernetes for improved scaling
2. **Load Balancing** - For higher throughput and availability
3. **Monitoring** - Prometheus/Grafana for system monitoring
4. **Backup System** - Automated backups for database and user data
5. **CI/CD Pipeline** - Automated deployment and testing 