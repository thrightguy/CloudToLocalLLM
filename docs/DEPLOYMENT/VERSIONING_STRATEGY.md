# CloudToLocalLLM Versioning Strategy

## Overview

CloudToLocalLLM implements a granular build numbering system to maintain detailed version tracking while reducing unnecessary GitHub release proliferation.

## Version Format

**Format**: `MAJOR.MINOR.PATCH+BUILD`

### Components

- **Major Version (X)**: Significant feature releases or architecture changes
- **Minor Version (Y)**: Feature additions or notable improvements  
- **Patch Version (Z)**: Bug fixes and small updates
- **Build Number (+NNN)**: Incremental builds for the same patch version

### Examples
- `3.1.1+001` - Version 3.1.1, build 001
- `3.1.1+002` - Version 3.1.1, build 002 (patch increment)
- `3.2.0+001` - Version 3.2.0, build 001 (minor increment)
- `4.0.0+001` - Version 4.0.0, build 001 (major increment)

## Release Strategy

### GitHub Releases
- **Created ONLY for major version updates** (e.g., 3.0.0 → 4.0.0)
- Minor and patch updates do NOT create GitHub releases
- Reduces release clutter while maintaining version traceability

### Build Number Strategy
- **Major/Minor/Patch increments**: Reset build number to `001`
- **Build increments**: Increment build number (001 → 002 → 003...)
- Build numbers use 3-digit zero-padded format

## Version Progression Examples

```
Current: v3.0.3+202506031900 (old format)
↓
v3.1.1+001 (new format - minor update, no GitHub release)
↓
v3.1.1+002 (build increment, no GitHub release)
↓
v3.1.2+001 (patch increment, no GitHub release)
↓
v3.2.0+001 (minor increment, no GitHub release)
↓
v4.0.0+001 (major increment, CREATE GitHub release)
```

## Implementation

### Version Manager Script

Use `scripts/version_manager.sh` for all version operations:

```bash
# Show current version info
./scripts/version_manager.sh info

# Increment build number only
./scripts/version_manager.sh increment build

# Increment patch version (resets build to 001)
./scripts/version_manager.sh increment patch

# Increment minor version (resets build to 001)
./scripts/version_manager.sh increment minor

# Increment major version (resets build to 001, triggers GitHub release)
./scripts/version_manager.sh increment major
```

### Smart Deployment Script

Use `scripts/deploy/smart_deploy.sh` for automated deployments:

```bash
# Build increment (no GitHub release)
./scripts/deploy/smart_deploy.sh build

# Patch release (no GitHub release)
./scripts/deploy/smart_deploy.sh patch

# Minor release (no GitHub release)
./scripts/deploy/smart_deploy.sh minor

# Major release (creates GitHub release)
./scripts/deploy/smart_deploy.sh major
```

## Distribution Strategy

### Major Versions (x.0.0)
- **GitHub Releases**: Full release with binary assets
- **AUR Package**: Updated with GitHub release URLs
- **VPS Deployment**: Updated with new version
- **Documentation**: Full release notes and announcements

### Minor/Patch Versions (x.y.z)
- **GitHub Releases**: None created
- **AUR Package**: Updated with alternative distribution method
- **VPS Deployment**: Updated with new version
- **Documentation**: Changelog updates only

### Build Increments (x.y.z+nnn)
- **GitHub Releases**: None created
- **AUR Package**: Updated build number only
- **VPS Deployment**: Updated with new build
- **Documentation**: Internal tracking only

## File Updates

### Automatic Updates
- `pubspec.yaml` - Version field updated automatically
- `assets/version.json` - Version and build number updated
- `lib/config/app_config.dart` - App version constant updated (if exists)

### Manual Updates Required
- `aur-package/PKGBUILD` - Package version and source URLs
- `aur-package/.SRCINFO` - Generated from PKGBUILD
- Release documentation and changelogs

## AUR Package Handling

### Major Versions
- Source URLs point to GitHub Releases
- Full binary assets available
- Standard AUR package update process

### Minor/Patch Versions
- Alternative distribution methods used
- May use previous major version binaries temporarily
- Special handling in PKGBUILD for version mapping

### Build Increments
- Version number updated in PKGBUILD
- Same source binaries as base version
- Minimal AUR repository changes

## Benefits

### Reduced GitHub Release Clutter
- Only major versions create releases
- Cleaner release history for users
- Focus on significant updates

### Detailed Version Tracking
- Build numbers provide granular tracking
- Easy identification of incremental changes
- Better debugging and support capabilities

### Flexible Distribution
- Major versions: Full GitHub release process
- Minor versions: Streamlined distribution
- Build increments: Minimal overhead

### Development Efficiency
- Automated version management
- Clear release criteria
- Reduced manual release overhead

## Migration from Old Format

### Old Format
- `3.0.3+202506031900` (timestamp-based build numbers)
- GitHub releases for all versions
- Manual version management

### New Format
- `3.1.1+001` (sequential build numbers)
- GitHub releases only for major versions
- Automated version management with smart deployment

### Transition Process
1. Update to new format: `3.1.1+001`
2. Implement new version manager features
3. Deploy smart deployment script
4. Update AUR package handling
5. Document new process for team

## Best Practices

### For Developers
- Use version manager script for all version changes
- Test smart deployment script in development
- Follow semantic versioning principles
- Document changes appropriately for version type

### For Releases
- Major versions: Full testing and documentation
- Minor versions: Feature testing and changelog
- Patch versions: Bug fix verification
- Build increments: Basic functionality testing

### For AUR Maintenance
- Update PKGBUILD for each version change
- Test package builds locally before submission
- Maintain alternative distribution for non-major versions
- Keep AUR repository synchronized with deployments

## Troubleshooting

### Version Manager Issues
- Check `pubspec.yaml` format
- Verify script permissions
- Validate version format with `validate` command

### Deployment Issues
- Ensure all scripts are executable
- Check VPS connectivity
- Verify AUR package build process

### AUR Package Issues
- Test local package builds
- Verify source URL accessibility
- Check checksum accuracy for new versions

This versioning strategy provides a balance between detailed tracking and release management efficiency, supporting CloudToLocalLLM's development and distribution needs.
