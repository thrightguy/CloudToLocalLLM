# CloudToLocalLLM Release Management

This document describes the release management process for CloudToLocalLLM, particularly how we handle installer files and versioning.

## Release Cleanup Process

To prevent accumulation of old or unused installer files in the releases directory, we implement automatic cleanup during the build process. This ensures only the most recent working builds are retained.

### How It Works

1. When a new build is created, the script automatically cleans up old/unused installer files
2. Files are sorted by timestamp, and only the most recent ones are kept
3. Separate cleanup rules apply for regular and admin installers
4. The cleanup script can be run in "dry run" mode to see what would be deleted without actually removing files

### Using the Cleanup Script

The `clean_releases.ps1` script can be used standalone:

```powershell
# Basic usage - removes all but the latest builds
.\clean_releases.ps1

# Dry run - shows what would be deleted without making changes
.\clean_releases.ps1 -DryRun

# Keep only regular installers (remove all admin installers)
.\clean_releases.ps1 -PreserveRegular

# Keep only admin installers (remove all regular installers)
.\clean_releases.ps1 -PreserveAdmin
```

### Build Parameters

Both build scripts (`build_windows_with_license.ps1` and `build_windows_admin_installer.ps1`) support parameters to control the cleanup process:

```powershell
# Build without cleaning up old releases
.\build_windows_with_license.ps1 -KeepAllReleases

# Build and perform a dry run of the cleanup
.\build_windows_with_license.ps1 -CleanupDryRun
```

## Versioning Strategy

The versioning strategy for CloudToLocalLLM follows these rules:

1. **Version Number**: We use semantic versioning (MAJOR.MINOR.PATCH)
2. **Build Timestamp**: Each build includes a timestamp (YYYYMMDDHHMM) in the filename
3. **File Naming**:
   - Regular installers: `CloudToLocalLLM-Windows-VERSION-TIMESTAMP-Setup.exe`
   - Admin installers: `CloudToLocalLLM-Admin-TIMESTAMP.exe`
   - ZIP packages: `CloudToLocalLLM-Windows-VERSION.zip` (regular) or `CloudToLocalLLM-Windows-Admin-TIMESTAMP.zip` (admin)

## Release Candidate Selection

When determining which build should be marked as a release candidate:

1. Build all versions using the standard build scripts
2. Test each build thoroughly
3. When a candidate is identified:
   - Rename the file to remove the timestamp for final distribution
   - Use `clean_releases.ps1` to remove other builds that are no longer needed

## Making a Release

To create a new official release:

1. Update the version number in:
   - `CloudToLocalLLM.iss`
   - `CloudToLocalLLM_AdminOnly.iss`
   - `pubspec.yaml`
   
2. Build both regular and admin installers:
   ```powershell
   .\build_windows_with_license.ps1
   .\build_windows_admin_installer.ps1
   ```

3. Test both installers thoroughly

4. When ready to release:
   ```powershell
   # Clean up all but the latest candidate
   .\clean_releases.ps1 -KeepLatestBuild
   ```

5. Push all changes to GitHub with appropriate version tags 