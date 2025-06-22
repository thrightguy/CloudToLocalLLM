# CloudToLocalLLM Flutter SDK and Package Management

## Overview

The CloudToLocalLLM VPS deployment pipeline has been enhanced to automatically update Flutter SDK and package dependencies to their latest versions during deployment. This ensures the web interface always uses the latest Flutter SDK and packages for security updates, performance improvements, and new features while maintaining compatibility.

## Updated Deployment Process

### Automatic Updates

The deployment pipeline now includes the following automatic updates:

1. **Flutter SDK Update**: Updates to the latest stable Flutter version
2. **Package Dependencies**: Updates all packages in `pubspec.yaml` to their latest compatible versions
3. **Compatibility Verification**: Checks for version compatibility and potential issues
4. **Web Platform Support**: Ensures web platform support is enabled

### Deployment Scripts

#### Bash Script (`scripts/deploy/update_and_deploy.sh`)

**New Functions:**
- `update_flutter_environment()`: Updates Flutter SDK and dependencies
- `verify_flutter_compatibility()`: Verifies compatibility with the codebase

**Updated Flow:**
```bash
create_backup
pull_latest_changes
update_flutter_environment    # NEW
build_flutter_web
update_distribution_files
manage_containers
perform_health_checks
display_summary
```

#### PowerShell Script (`scripts/powershell/deploy_vps.ps1`)

**New Functions:**
- `Update-FlutterEnvironment`: Updates Flutter SDK and dependencies
- `Test-FlutterCompatibility`: Verifies compatibility with the codebase
- `Build-FlutterWeb`: Builds Flutter web application with verification

**Updated Flow:**
```powershell
Update-GitRepository
Update-FlutterEnvironment     # NEW
Build-FlutterWeb             # NEW
Stop-Containers
Start-Containers
```

## Version Requirements

### Minimum Flutter Version
- **Required**: Flutter 3.16.0 or higher
- **Recommended**: Latest stable Flutter version
- **Web Support**: Must have web platform enabled

### Package Compatibility
- All packages are updated to latest compatible versions using `flutter pub upgrade`
- Compatibility verification checks for known problematic combinations
- Desktop-specific packages are verified for web compatibility

## Docker Integration

### Flutter Builder Container

A new Docker container (`Dockerfile.flutter-builder`) provides a consistent Flutter build environment:

**Features:**
- Latest stable Flutter SDK
- Automatic SDK updates via `/home/flutter/update-flutter.sh`
- Web build automation via `/home/flutter/build-web.sh`
- Persistent caches for faster builds

**Usage:**
```bash
# Build the Flutter builder image
docker-compose -f docker-compose.flutter-builder.yml build flutter-builder

# Run automated build with updates
docker-compose -f docker-compose.flutter-builder.yml run --rm flutter-build-runner
```

### Volume Management
- `flutter-sdk-cache`: Persistent Flutter SDK cache
- `flutter-pub-cache`: Persistent pub cache for faster builds

## Testing

### Test Scripts

**PowerShell Test Script:**
```powershell
.\scripts\deploy\Test-DeploymentPipeline.ps1 -TestMode Local -DryRun -VerboseOutput
```

**Bash Test Script:**
```bash
bash scripts/deploy/test_deployment_pipeline.sh --mode local --dry-run --verbose
```

### Test Modes
1. **Local**: Test Flutter updates and build locally
2. **Docker**: Test using Docker Flutter builder
3. **VPS**: Test VPS deployment pipeline (requires SSH access)

## Compatibility Verification

### Automatic Checks

The deployment pipeline automatically verifies:

1. **Flutter Version**: Ensures minimum version requirements are met
2. **Web Platform Support**: Verifies web platform is enabled
3. **Package Dependencies**: Checks for dependency conflicts
4. **Build Capability**: Tests Flutter web build functionality

### Version Constraints

**Minimum Requirements:**
- Flutter SDK: 3.16.0+
- Dart SDK: 3.2.0+ (included with Flutter)
- Web renderer: HTML (default for compatibility)

**Breaking Changes to Monitor:**
- Flutter web renderer changes (CanvasKit vs HTML)
- Package API changes in major version updates
- Dart language feature changes

## Deployment Commands

### Standard VPS Deployment

**VPS deployment must use WSL/Linux environment:**
```bash
# From WSL or Linux terminal
cd /opt/cloudtolocalllm
bash scripts/deploy/update_and_deploy.sh --force --verbose
```

**Windows users should use WSL:**
```powershell
# From Windows PowerShell, access WSL
wsl -d archlinux
# Then run the bash deployment script
cd /opt/cloudtolocalllm
bash scripts/deploy/update_and_deploy.sh --force --verbose
```

### Docker-based Build

```bash
# Build with automatic updates
docker-compose -f docker-compose.flutter-builder.yml run --rm flutter-build-runner

# Interactive builder environment
docker-compose -f docker-compose.flutter-builder.yml run --rm flutter-builder
```

## Troubleshooting

### Common Issues

**Flutter Upgrade Failures:**
- Check internet connectivity
- Verify Flutter installation permissions
- Clear Flutter cache: `flutter clean`

**Package Dependency Conflicts:**
- Review `pubspec.yaml` for version constraints
- Check for deprecated packages
- Use `flutter pub deps` to analyze dependencies

**Web Build Failures:**
- Ensure web platform is enabled: `flutter config --enable-web`
- Check for platform-specific code in web builds
- Verify web renderer compatibility

### Recovery Procedures

**Rollback Flutter Version:**
```bash
# Switch to specific Flutter version
flutter version <version-number>
flutter pub get
```

**Reset Package Dependencies:**
```bash
# Reset to pubspec.yaml versions
flutter pub get --offline
flutter clean
flutter pub get
```

## Monitoring and Maintenance

### Version Tracking

The deployment process logs:
- Current Flutter version before update
- Updated Flutter version after update
- Package dependency changes
- Build verification results

### Regular Maintenance

**Weekly:**
- Review deployment logs for warnings
- Check for new Flutter stable releases
- Monitor package security advisories

**Monthly:**
- Review package dependencies for updates
- Test deployment pipeline in staging
- Update documentation for any breaking changes

## Security Considerations

### Automatic Updates

**Benefits:**
- Latest security patches
- Performance improvements
- Bug fixes

**Risks:**
- Potential breaking changes
- Compatibility issues
- Build failures

### Mitigation Strategies

1. **Backup Creation**: Automatic backups before deployment
2. **Compatibility Verification**: Automated checks for known issues
3. **Rollback Capability**: Quick rollback to previous versions
4. **Testing Pipeline**: Comprehensive testing before production deployment

## Configuration Options

### Environment Variables

```bash
# Flutter configuration
FLUTTER_HOME=/opt/flutter
PUB_CACHE=/opt/flutter/.pub-cache
FLUTTER_WEB_USE_SKIA=false
FLUTTER_WEB_AUTO_DETECT=true
```

### Deployment Flags

```bash
# Bash script options
--force              # Skip confirmation prompts
--verbose            # Enable verbose output
--dry-run           # Perform dry run without changes

# PowerShell script options
-VerboseOutput      # Enable verbose output
-AutoInstall        # Automatically install dependencies
-SkipDependencyCheck # Skip dependency verification
```

This enhanced deployment pipeline ensures CloudToLocalLLM always runs on the latest stable Flutter version while maintaining compatibility and providing robust error handling and recovery mechanisms.

## Summary of Changes

### Files Modified

1. **`scripts/powershell/deploy_vps.ps1`**
   - Added `Update-FlutterEnvironment` function
   - Added `Test-FlutterCompatibility` function
   - Added `Build-FlutterWeb` function
   - Updated deployment flow to include Flutter updates

2. **`scripts/deploy/update_and_deploy.sh`**
   - Added `update_flutter_environment` function
   - Added `verify_flutter_compatibility` function
   - Updated deployment flow to include Flutter updates

### Files Created

1. **`config/docker/Dockerfile.flutter-builder`**
   - Docker container for consistent Flutter builds
   - Automatic SDK updates and web build scripts

2. **`docker-compose.flutter-builder.yml`**
   - Docker Compose configuration for Flutter builder
   - Persistent caches and automated build services

3. **`scripts/deploy/Test-DeploymentPipeline.ps1`**
   - PowerShell test script for deployment pipeline
   - Local, Docker, and VPS testing modes

4. **`scripts/deploy/test_deployment_pipeline.sh`**
   - Bash test script for deployment pipeline
   - Comprehensive testing with dry-run support

5. **`docs/DEPLOYMENT/FLUTTER_SDK_MANAGEMENT.md`**
   - Complete documentation for the updated deployment process
   - Troubleshooting guides and best practices

### Key Features Added

- **Automatic Flutter SDK Updates**: Latest stable version during deployment
- **Package Dependency Updates**: `flutter pub upgrade` for latest compatible versions
- **Compatibility Verification**: Automated checks for version compatibility
- **Docker Build Environment**: Consistent, containerized Flutter builds
- **Comprehensive Testing**: Test scripts for all deployment scenarios
- **Detailed Documentation**: Complete guides and troubleshooting information

### Breaking Changes

- **Minimum Flutter Version**: Now requires Flutter 3.16.0 or higher
- **Deployment Time**: Increased due to SDK updates (first run only)
- **Docker Dependencies**: New Docker images for containerized builds

### Migration Guide

For existing deployments:

1. **Update Deployment Scripts**: Use the updated scripts with Flutter SDK management
2. **Verify Flutter Version**: Ensure Flutter 3.16.0+ is installed on VPS
3. **Test Pipeline**: Run test scripts before production deployment
4. **Monitor First Deployment**: First deployment will take longer due to SDK updates
5. **Review Logs**: Check deployment logs for any compatibility warnings
