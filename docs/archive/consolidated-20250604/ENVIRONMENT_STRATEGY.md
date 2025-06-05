# Environment Strategy

## Overview

This document outlines the environment strategy for the CloudToLocalLLM application.

## Authentication (Auth0)

*   **Production**: The application uses Auth0 for authentication in all environments.
*   **Configuration**: This is managed in `lib_custom/config/app_config.dart` via the Auth0 configuration settings.
*   **Rationale**: Using Auth0 provides a secure, scalable, and maintainable authentication solution without the need for self-hosted authentication services.

## Environment Variables

*   **Development**: Uses `.env.development` for local development settings.
*   **Production**: Uses `.env` for production settings.
*   **Secrets**: Sensitive information is stored in environment variables and not committed to the repository.

## Docker Environment

*   **Development**: Uses development-specific Docker configurations.
*   **Production**: Uses production-optimized Docker configurations.
*   **Volumes**: Persistent data is stored in Docker volumes.

## SSL Configuration

*   **Development**: Uses self-signed certificates.
*   **Production**: Uses Let's Encrypt or commercial SSL certificates.
*   **Configuration**: SSL settings are managed through environment variables and Docker configurations.

## Monitoring and Logging

*   **Development**: Basic logging for debugging.
*   **Production**: Comprehensive logging and monitoring setup.
*   **Tools**: Prometheus and Grafana for metrics collection and visualization.

## Backup Strategy

*   **Development**: Manual backups as needed.
*   **Production**: Automated regular backups of all persistent data.
*   **Storage**: Backups are stored in a secure, off-site location.

## Security Considerations

*   **Development**: Basic security measures for local development.
*   **Production**: Comprehensive security measures including:
    *   Regular security updates
    *   Network isolation
    *   Access control
    *   Monitoring and alerting

## Current Approach (As of May 2024)

For the initial development phase leading up to the first production version, the project utilizes a single, unified environment for certain key services.

### Authentication (FusionAuth)

*   **Single Target:** The Flutter application (for web, desktop, and planned mobile) is configured to **always** target the live production FusionAuth instance located at `https://auth.cloudtolocalllm.online`.
*   **Configuration:** This is managed in `lib_custom/config/app_config.dart` via the `AppConfig.fusionAuthBaseUrl` getter, which directly returns the production URL regardless of the Flutter build mode (debug or release).
*   **Rationale:** This approach simplifies the initial setup and testing, as there is no separate development or staging instance of FusionAuth actively maintained yet. All development and testing implicitly occur against the production authentication service.

### Other Services

*   Backend APIs (`apiBaseUrl`, `cloudBaseUrl`): These still retain a distinction between `localhost` for `kDebugMode` and the production URLs (`https://api.cloudtolocalllm.online`, `https://cloudtolocalllm.online`) for release builds.

## Future Plans

*   **Beta Subdomain:** Once the application reaches a more stable state, a `beta.cloudtolocalllm.online` (or similar) subdomain is planned. This will likely host beta versions of the application and potentially a separate instance or configuration for backend services, including authentication, to allow for testing new features without impacting the primary production environment.
*   **Development Branches:** Proper development branches will be utilized in Git to manage feature development and isolate changes before they are merged into a release candidate for beta or production.

## Implications

*   Developers and testers should be aware that actions performed through the application's authentication system (e.g., user registration, login) are interacting directly with the live FusionAuth instance.
*   Care should be taken with test account data. 