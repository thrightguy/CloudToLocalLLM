# Dependency Management

This document outlines important considerations for managing dependencies in the CloudToLocalLLM project.

## Critical Dependencies

The following dependencies have specific version requirements to ensure compatibility across platforms:

| Package | Version Constraint | Reason |
|---------|-------------------|--------|
| `win32` | ^2.7.0 (must be <3.0.0) | Versions 3.0.0+ contain breaking changes (UnmodifiableUint8ListView) that conflict with device_info_plus |
| `device_info_plus` | ^8.2.2 | Requires win32 <3.0.0; newer versions have more stringent requirements |
| `path` | >=1.8.2 <2.0.0 | Must be <2.0.0 for compatibility with flutter_test |

## Known Conflicts

- **win32 vs device_info_plus**: The device_info_plus package (≥4.1.2) requires win32 ≥2.7.0 <4.0.0, while newer versions of some packages may try to pull in win32 ≥4.0.0.
- **path version constraints**: Flutter SDK's flutter_test package pins the path package to a specific version, requiring careful version constraint management.

## Dependency Resolution Strategy

When updating dependencies, follow these guidelines:

1. **Incremental Updates**: Update one dependency at a time and test thoroughly
2. **Version Locking**: Use explicit version constraints when necessary
3. **Compatibility Testing**: Test across all platforms before committing changes
4. **CI/CD Verification**: Ensure CI/CD pipeline includes dependency compatibility checks

## Common Issues and Solutions

### Build Fails Due to "win32" Dependencies

If you encounter errors related to win32 package compatibility (e.g., UnmodifiableUint8ListView errors):

```
Solution: Pin win32 to ^2.7.0 in pubspec.yaml to ensure compatibility with device_info_plus
```

### Version Solving Failed

If pub get reports "version solving failed" due to conflicting constraints:

```
Solution: Review the pubspec.yaml and adjust version constraints to be more compatible
```

### Device Info Plugin Issues on VPS/Cloud Deployment

If device_info_plus causes issues during cloud builds:

```
Solution: Ensure win32 is pinned to an appropriate version (^2.7.0) and consider conditionally importing platform-specific plugins
```

## Dependency Upgrade Procedure

1. Run `flutter pub outdated` to identify outdated packages
2. Research compatibility of newer versions
3. Update one dependency or related group at a time
4. Run `flutter pub get` to verify resolution
5. Test on all platforms (Windows, macOS, Linux, web)
6. Commit changes with detailed notes on version constraints

## Continuous Monitoring

Regularly check for security updates and critical fixes in dependencies:

```bash
flutter pub outdated
```

Document any intentional version pinning in code comments for future maintenance. 