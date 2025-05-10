# GitHub Release Instructions for CloudToLocalLLM Windows App

This document provides instructions on how to create a GitHub release and make the Windows app downloadable from GitHub.

## Prerequisites

- A GitHub account with write access to the repository
- The release candidate installer file and ZIP package from the `releases` directory

## Creating a GitHub Release

1. **Go to the GitHub Repository**
   - Open a web browser and navigate to https://github.com/thrightguy/CloudToLocalLLM

2. **Create a New Release**
   - Click on the "Releases" tab on the right side of the repository page
   - Click on the "Create a new release" button

3. **Fill in Release Information**
   - **Tag version**: Enter a version number (e.g., v1.0.0)
   - **Release title**: Enter a title for the release (e.g., "CloudToLocalLLM Windows App v1.0.0")
   - **Description**: Provide a description of the release, including any new features, bug fixes, or changes
   - **Attach binaries**: Upload both the installer (.exe) and ZIP package from the `releases` directory

4. **Publish Release**
   - Click the "Publish release" button to make the release available to users

## Verifying the Release

After creating the release, verify that:

1. The release appears on the Releases page of the repository
2. Both the installer and ZIP files are attached to the release
3. The download link in the README.md file points to the correct location

## Updating the README (if necessary)

The README.md file already contains instructions for downloading the app from the Releases page. If you need to update these instructions, edit the README.md file and update the following section:

```markdown
1. **Download the Application**
   - Download the latest release from the [Releases](https://github.com/thrightguy/CloudToLocalLLM/releases) page.
   - Either run the installer or extract the ZIP file to a location of your choice.
```

## Building a New Release

Follow the instructions in [RELEASE_MANAGEMENT.md](RELEASE_MANAGEMENT.md) for creating a new release. The process generally includes:

1.  **Update Version Numbers**: In `pubspec.yaml` and any platform-specific files or installer scripts (e.g., Inno Setup `.iss` files).
2.  **Build Installers**: Use the provided build scripts for consistency and to include necessary steps like licensing or specific installer configurations.
    *   Example for regular installer: `scripts\build\build_windows_with_license.ps1`
    *   Example for admin installer: `scripts\build\build_windows_admin_installer.ps1` (If applicable)
    *   These scripts typically handle the `flutter build windows` command along with packaging, versioning, and creating the final installer/ZIP files in the `releases/` directory.
3.  **Test Builds Thoroughly**: On target platforms.
4.  **Select Release Candidate**: And clean up older builds if necessary (e.g., using `scripts\release\clean_releases.ps1 -KeepLatestBuild`).
5.  **Create GitHub Release**: Upload the final installer and ZIP files to GitHub as described in the sections above.

## Release File Naming Conventions

Release files should follow these naming conventions:

- Regular installer: `CloudToLocalLLM-Windows-VERSION-Setup.exe`
- Admin installer: `CloudToLocalLLM-Admin.exe`
- Regular ZIP package: `CloudToLocalLLM-Windows-VERSION.zip`
- Admin ZIP package: `CloudToLocalLLM-Windows-Admin.zip`

For more details on the release process including automated cleanup, see [RELEASE_MANAGEMENT.md](RELEASE_MANAGEMENT.md).

## Building the Windows App (Manual Steps for Reference / Troubleshooting)

While the build scripts mentioned in [RELEASE_MANAGEMENT.md](RELEASE_MANAGEMENT.md) (and summarized above) are the **recommended way to create official release builds**, the following outlines the basic manual steps involved if you need to build directly for testing or troubleshooting:

1. Make sure all dependencies are up to date:
   ```
   flutter pub get
   ```

2. Build the Windows app:
   ```
   flutter build windows
   ```

3. Move the newly built .exe files to the `releases` folder:
   - Copy or move any new `.exe` files from `build\windows\x64\runner\Release\` to the `releases` folder in your repository root. This ensures all release executables are organized and easy to find.

4. Package the app into a versioned ZIP file:
   - The ZIP file name must include the version number, e.g., `CloudToLocalLLM-Windows-1.1.0.zip`.
   ```
   Compress-Archive -Path "releases\*" -DestinationPath "CloudToLocalLLM-Windows-1.1.0.zip" -Force
   ```

5. Ensure the Windows installer filename also includes the version number, e.g., `CloudToLocalLLM-Windows-1.1.0-Setup.exe`.

6. Create a new GitHub release following the instructions above
