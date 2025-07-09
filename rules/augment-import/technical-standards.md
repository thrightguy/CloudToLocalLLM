# CloudToLocalLLM Technical Standards

## Code Editing Standards
### Mandatory Requirements
- **NEVER** rewrite entire files
- Make targeted, surgical changes only
- Preserve existing code structure and formatting
- Maintain existing imports and dependencies
- Use `str-replace-editor` for all modifications

### Dependency Management
- **ALWAYS** use `flutter pub` commands for package management
- Never manually edit `pubspec.yaml` for dependencies
- Use `flutter pub upgrade` and `flutter pub outdated` for updates
- Avoid `dependency_overrides` in pubspec.yaml

## Platform Abstraction Requirements
- Use conditional imports with stub files for unsupported platforms
- Follow AuthServicePlatform factory pattern for platform-specific services
- Use `kIsWeb` for web-specific code detection
- Maintain single codebase across web/desktop/mobile
- Don't create platform-specific code in shared modules

## Service Implementation Standards
- Use established logging prefixes for consistency
- Follow existing error handling patterns
- Implement proper cleanup and resource management
- Maintain service isolation and independence
- Don't bypass existing service abstractions

## Authentication and Security
- Use Auth0 with platform-specific redirect URIs
- Implement JWT validation with RS256 tokens
- Follow PKCE flow for desktop authentication
- Maintain secure token storage per platform

## WebSocket and Networking
- Use correlation IDs for bidirectional communication
- Implement proper connection cleanup and timeout handling
- Follow multi-tenant isolation patterns
- Use established proxy architecture patterns

## Configuration Management
- Centralize settings in AppConfig.dart
- Use compile-time constants for feature flags
- Maintain platform-specific URLs and timeouts
- Follow established configuration patterns

## Testing Requirements
- Write unit tests using mockito for services
- Create integration tests for end-to-end workflows
- Use platform-specific test execution patterns
- Follow existing test structure and naming

## Quality Assurance Checklist
### Static Analysis
- Ensure zero `flutter analyze` issues before completion
- Follow Dart/Flutter best practices
- Maintain consistent code formatting
- Use proper null safety patterns

### Cross-Platform Compatibility
- Test changes across supported platforms
- Verify platform abstraction works correctly
- Ensure no platform-specific code leaks into shared components
- Validate authentication flows on each platform

### Documentation
- Update relevant documentation when changing behavior
- Maintain clear, descriptive commit messages
- Document any breaking changes or new requirements
- Keep inline comments accurate and helpful

## Prohibited Actions
### Manual Operations
- Don't manually edit package configuration files
- Don't create new scripts when existing ones work
- Don't bypass established build and deployment workflows
- Don't make ad-hoc fixes instead of systematic solutions

### Architecture Violations
- Don't bypass existing service abstractions
- Don't create platform-specific code in shared modules
- Don't ignore existing error handling patterns
- Don't break established dependency injection

## Version and Build Management
- Use `scripts/powershell/version_manager.ps1` for version updates
- Follow established build and deployment workflows
- Never manually edit version files
- Commit ALL related changes in comprehensive commits with descriptive messages
