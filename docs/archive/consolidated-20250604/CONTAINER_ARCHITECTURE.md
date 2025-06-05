# Container Architecture

## Overview

The CloudToLocalLLM application uses Docker containers to manage its services. The main components are:

*   **Web Application (`cloudtolocalllm-webapp`)**:
*   **Purpose**: Serves the main web interface.
*   **Image**: Custom-built from `Dockerfile.web`.
*   **Configuration**: Managed via nginx configuration and persistent data in Docker volumes.
*   **Ports**: 80 (HTTP) and 443 (HTTPS).

*   **Cloud Service (`cloud`)**:
*   **Purpose**: Handles cloud-related operations.
*   **Image**: `node:20`.
*   **Configuration**: Managed via environment variables and mounted scripts.
*   **Ports**: 3456.

## Network Architecture

1.  All services are connected through a custom bridge network (`cloudllm-network`).
2.  The network provides DNS resolution between containers, allowing them to communicate using service names.
3.  The network is used by the main application services (`webapp`, `cloud`, etc.).

## Deployment Flow

1.  The `admin_control_daemon` is started first, which listens for deployment commands.
2.  When a deployment command is received, the daemon:
    *   Pulls the latest code from the Git repository.
    *   Builds any necessary Docker images.
    *   Uses `docker-compose` to orchestrate the services.
3.  The `admin_control_daemon` uses `config/docker/docker-compose.yml` to bring up (build if necessary, then run) the `webapp` and any other defined application services.

## Security Considerations

*   **Network Isolation**: Services are isolated in their own network, preventing direct access from outside.
*   **Volume Management**: Persistent data is stored in Docker volumes, ensuring data persistence across container restarts.
*   **Secrets Management**: Passwords and sensitive data are managed through environment variables and secure configuration files.

## Authentication

The application uses Auth0 for authentication, which is configured through environment variables and the web application's configuration. No local authentication service is required. 