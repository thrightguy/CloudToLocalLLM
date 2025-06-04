# CloudToLocalLLM Update Feature Documentation

This document describes the update feature added to CloudToLocalLLM, which allows the application to check for updates on GitHub and install them automatically.

## Overview

The update feature consists of the following components:

1. A PowerShell script (`check_for_updates.ps1`) that checks for updates on GitHub and installs them if available
2. Registry entries to store user preferences for automatic updates
3. A shortcut in the Start menu to manually check for updates
4. A scheduled task to automatically check for updates at logon

## How It Works

### Update Checker Script

The `check_for_updates.ps1` script performs the following functions:

1. Gets the current version of the application from the `version.txt` file or by parsing the executable name
2. Queries the GitHub API to get the latest release information
3. Compares the current version with the latest version
4. If a newer version is available, downloads and installs it (with user confirmation in interactive mode)

The script can be run in two modes:

- **Interactive Mode**: Shows a UI with release notes and prompts the user to confirm installation
- **Silent Mode**: Runs in the background and only shows a UI if an update is available

### Registry Settings

The installer creates the following registry entries:

- `HKCU\Software\CloudToLocalLLM\Updates\CheckForUpdatesAtStartup`: Controls whether the application checks for updates at startup (default: 1 = enabled)
- `HKCU\Software\CloudToLocalLLM\Updates\AutoInstallUpdates`: Controls whether the application automatically installs updates without user confirmation (default: 0 = disabled)

### Start Menu Shortcut

The installer creates a shortcut in the Start menu called "Check for Updates" that runs the update checker script in interactive mode. This allows users to manually check for updates at any time.

### Scheduled Task

The installer creates a scheduled task that runs the update checker script in silent mode at logon. This task only runs if a network connection is available and respects the user's preferences for automatic updates.

## User Experience

### First Run

When the user first installs the application, the following happens:

1. The installer creates the registry entries with default values (check at startup enabled, auto-install disabled)
2. The installer creates a scheduled task to check for updates at logon
3. The installer creates a shortcut in the Start menu to manually check for updates

### Checking for Updates

The application checks for updates in the following scenarios:

1. At logon, if the "Check for updates at startup" option is enabled
2. When the user clicks the "Check for Updates" shortcut in the Start menu

### Update Available

When an update is available, the following happens:

1. If running in interactive mode, the script shows the release notes and prompts the user to confirm installation
2. If running in silent mode with auto-install enabled, the script automatically downloads and installs the update
3. If running in silent mode with auto-install disabled, the script shows a notification that an update is available

### Installing Updates

When installing an update, the following happens:

1. The script downloads the installer for the new version
2. The script runs the installer with the `/SILENT` parameter to install the update without user interaction
3. The script notifies the user that the update has been installed and that they should restart the application

## Customizing Update Settings

Users can customize the update settings by modifying the registry entries:

- To disable automatic update checks at startup, set `HKCU\Software\CloudToLocalLLM\Updates\CheckForUpdatesAtStartup` to 0
- To enable automatic installation of updates, set `HKCU\Software\CloudToLocalLLM\Updates\AutoInstallUpdates` to 1

## Technical Details

### Version Comparison

The script compares versions using the .NET `[version]` type, which correctly handles semantic versioning (e.g., 1.0.0 < 1.1.0 < 1.1.1).

### GitHub API

The script uses the GitHub API to get information about the latest release. It looks for assets with names matching "*Windows*Setup.exe" to find the Windows installer.

### Scheduled Task

The scheduled task is configured to:

- Run at logon
- Run only if a network connection is available
- Run even if the computer is on battery power
- Not stop if the computer goes on battery power
- Run as the current user