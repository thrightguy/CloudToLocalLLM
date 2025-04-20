# GitHub Release Update Instructions for CloudToLocalLLM Windows App

This document provides instructions on how to update the version number, build the Windows app, and create a new GitHub release.

## Updating the Version Number

When making changes to the application, you should update the version number according to semantic versioning:

- **Major version (1.x.x)**: Breaking changes that are not backward compatible
- **Minor version (x.1.x)**: New features or significant changes that don't break compatibility
- **Patch version (x.x.1)**: Bug fixes and minor changes

Update the version number in the following files:

1. **pubspec.yaml**
   ```yaml
   name: cloud_to_local_llm
   description: A Flutter/Dart tunnel for CloudToLocalLLM
   version: 1.1.0  # Update this line
   ```

2. **RELEASE_DESCRIPTION.md**
   ```markdown
   # CloudToLocalLLM Windows App v1.1.0  # Update this line
   ```

## Building the Windows App

Follow these steps to build a new version of the Windows app:

1. **Update dependencies**
   ```
   flutter pub get
   ```

2. **Build the Windows app**
   ```
   flutter build windows
   ```

3. **Package the app into a ZIP file with version number**
   ```
   # Create releases directory if it doesn't exist
   if (-not (Test-Path -Path "releases")) {
       New-Item -ItemType Directory -Path "releases"
   }

   # Get version from pubspec.yaml
   $version = (Get-Content pubspec.yaml | Select-String -Pattern "version: (.+)").Matches.Groups[1].Value.Trim()

   # Create the ZIP file with version number in the releases folder
   Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "releases\CloudToLocalLLM-Windows-$version.zip" -Force
   ```

## Creating a GitHub Release

1. **Go to the GitHub Repository**
   - Open a web browser and navigate to https://github.com/thrightguy/CloudToLocalLLM

2. **Create a New Release**
   - Click on the "Releases" tab on the right side of the repository page
   - Click on the "Create a new release" button

3. **Fill in Release Information**
   - **Tag version**: Enter the updated version number (e.g., v1.1.0)
   - **Release title**: Enter a title for the release (e.g., "CloudToLocalLLM Windows App v1.1.0")
   - **Description**: Copy the content from RELEASE_DESCRIPTION.md
   - **Attach binaries**: Drag and drop the versioned ZIP file from the releases folder (e.g., releases\CloudToLocalLLM-Windows-1.1.0.zip) or click "Attach binaries by selecting them" and select the file

4. **Publish Release**
   - Click the "Publish release" button to make the release available to users

## Verifying the Release

After creating the release, verify that:

1. The release appears on the Releases page of the repository
2. The versioned ZIP file (e.g., CloudToLocalLLM-Windows-1.1.0.zip) is attached to the release
3. The download link in the README.md file points to the correct location

## Summary of Changes for v1.1.0

- Removed automatic installation of LLM providers (Ollama and LM Studio)
- Updated the app to require manual installation of Ollama or LM Studio
- Simplified the LlmProvider class by removing installation-related code
- Removed dependencies: process_run and path
- Updated installation instructions in README.md and RELEASE_DESCRIPTION.md
