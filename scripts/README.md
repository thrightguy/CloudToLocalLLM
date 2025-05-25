# CloudToLocalLLM Scripts Directory

**For a categorized list and explanation of all scripts (including which are for main deployment, maintenance, or setup), see [`SCRIPTS_OVERVIEW.md`](../SCRIPTS_OVERVIEW.md).**

This README contains general notes about script usage and organization.

This directory contains various scripts organized by function for the CloudToLocalLLM application.

## Directory Structure

- **build/** - Scripts for building the application for different platforms
- **deploy/** - Scripts for deploying the application to different environments
- **release/** - Scripts for release management and version control
- **auth0/** - Scripts for Auth0 integration and authentication
- **utils/** - Utility scripts for various tasks

## Organization Scripts

Two special scripts help manage the script organization:

- **organize_scripts.ps1** - Moves scripts from the root directory into appropriate subfolders
- **update_references.ps1** - Updates references to scripts in other files after reorganization

## Script Categories

### Build Scripts
Build scripts handle the compilation and packaging of the application for different platforms:
- Windows installers (admin and regular)
- Android builds
- Preparation for cloud builds

### Deploy Scripts
Deploy scripts handle the deployment of the application to different environments:
- VPS deployment
- Docker container setup
- Web deployment
- Cloud environment deployment

### Release Scripts
Release scripts handle version management and release processes:
- Cleaning up old releases
- Checking for updates
- Release candidate selection

### Auth0 Scripts
Auth0 scripts handle authentication integration:
- Auth0 setup and configuration
- Authentication flow integration
- API authentication

### Utility Scripts
Utility scripts provide various helper functions:
- SSL certificate management
- Nginx configuration
- Container setup
- UI adjustments

## Running Scripts

Most scripts should be run from the project root directory. Some scripts require administrative privileges and will prompt for elevation if needed.

Example:
```powershell
# From the project root
.\scripts\build\build_windows_with_license.ps1
```

## Contributing New Scripts

When adding new scripts to the project:

1. Place the script in the appropriate subdirectory based on its function
2. Update this README if adding a new category of scripts
3. Follow the naming convention of existing scripts
4. Include comments at the top of the script describing its purpose and usage

## Generate Icons Script

The `generate_icons.ps1` script generates app icons for Windows, Android, and iOS platforms from a source image.

### Prerequisites

- Windows operating system
- PowerShell 5.1 or higher
- [ImageMagick](https://imagemagick.org/script/download.php) installed

### Usage

1. Ensure you have a logo image at `assets\images\CloudToLocalLLM_logo.jpg`
2. Run the script from the project root directory:

```powershell
.\scripts\generate_icons.ps1
```

### Features

- Automatically finds ImageMagick installation across different common paths
- Creates all required output directories if they don't exist
- Generates icons in all required sizes for Windows, Android, and iOS
- Provides detailed progress information and error handling
- Color-coded output for better visibility

### Icon Sizes Generated

#### Windows
- 256x256
- 64x64
- 32x32
- 16x16

#### Android
- xxxhdpi (192x192)
- xxhdpi (144x144)
- xhdpi (96x96)
- hdpi (72x72)
- mdpi (48x48)

#### iOS
- 1024x1024
- 180x180
- 120x120
- 87x87
- 80x80
- 60x60
- 58x58
- 40x40
- 29x29

### Troubleshooting

If you encounter any issues:

1. Ensure ImageMagick is properly installed
2. Check that your logo image exists at the specified path
3. Make sure you have write permissions to the output directories

If ImageMagick is installed in a non-standard location, you may need to modify the script to add the path to the `$possiblePaths` array in the `Find-ImageMagick` function. 