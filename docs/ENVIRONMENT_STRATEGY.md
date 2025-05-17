# Environment Strategy

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