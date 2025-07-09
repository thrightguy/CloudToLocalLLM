# Code Modification Guidelines

## Before Making Any Edits

### 1. Comprehensive Information Gathering
- **MANDATORY**: Call `codebase-retrieval` with detailed, specific requests
- Ask for ALL symbols involved: classes, methods, properties, dependencies
- Include context about how components interact
- Get information about platform-specific implementations
- Understand existing patterns before proposing changes

### 2. Respect Existing Architecture
- Follow established platform abstraction patterns
- Use existing service factories and dependency injection
- Maintain separation between platform-specific and shared code
- Preserve existing error handling and logging patterns

## Code Editing Rules

### 1. Use str-replace-editor Only
- **NEVER** rewrite entire files
- Make targeted, surgical changes
- Preserve existing code structure and formatting
- Maintain existing imports and dependencies

### 2. Platform Abstraction Compliance
- Use conditional imports with stub files for unsupported platforms
- Follow AuthServicePlatform factory pattern for platform-specific services
- Use `kIsWeb` for web-specific code detection
- Maintain single codebase across web/desktop/mobile

### 3. Dependency Management
- **ALWAYS** use `flutter pub` commands for package management
- Never manually edit `pubspec.yaml` for dependencies
- Use `flutter pub upgrade` and `flutter pub outdated` for updates
- Avoid `dependency_overrides` in pubspec.yaml

### 4. Service Implementation Standards
- Use established logging prefixes for consistency
- Follow existing error handling patterns
- Implement proper cleanup and resource management
- Maintain service isolation and independence

## Specific Technical Guidelines

### 1. Authentication and Security
- Use Auth0 with platform-specific redirect URIs
- Implement JWT validation with RS256 tokens
- Follow PKCE flow for desktop authentication
- Maintain secure token storage per platform

### 2. WebSocket and Networking
- Use correlation IDs for bidirectional communication
- Implement proper connection cleanup and timeout handling
- Follow multi-tenant isolation patterns
- Use established proxy architecture patterns

### 3. Configuration Management
- Centralize settings in AppConfig.dart
- Use compile-time constants for feature flags
- Maintain platform-specific URLs and timeouts
- Follow established configuration patterns

### 4. Testing Integration
- Write unit tests using mockito for services
- Create integration tests for end-to-end workflows
- Use platform-specific test execution patterns
- Follow existing test structure and naming

## Quality Assurance

### 1. Static Analysis
- Ensure zero `flutter analyze` issues before completion
- Follow Dart/Flutter best practices
- Maintain consistent code formatting
- Use proper null safety patterns

### 2. Cross-Platform Compatibility
- Test changes across supported platforms
- Verify platform abstraction works correctly
- Ensure no platform-specific code leaks into shared components
- Validate authentication flows on each platform

### 3. Documentation and Comments
- Update relevant documentation when changing behavior
- Maintain clear, descriptive commit messages
- Document any breaking changes or new requirements
- Keep inline comments accurate and helpful

## Anti-Patterns to Avoid

### 1. Feature Creep
- Don't add new features when fixing bugs
- Don't suggest "improvements" unless requested
- Focus on the specific issue at hand
- Ask for clarification if scope is unclear

### 2. Architecture Violations
- Don't bypass existing service abstractions
- Don't create platform-specific code in shared modules
- Don't ignore existing error handling patterns
- Don't break established dependency injection

### 3. Manual Operations
- Don't manually edit package configuration files
- Don't create new scripts when existing ones work
- Don't bypass established build and deployment workflows
- Don't make ad-hoc fixes instead of systematic solutions
