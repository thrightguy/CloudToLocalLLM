# GitHub Release Instructions for CloudToLocalLLM Windows App

This document provides instructions on how to create a GitHub release and make the Windows app downloadable from GitHub.

## Prerequisites

- A GitHub account with write access to the repository
- The CloudToLocalLLM-Windows.zip file (already created in the repository root)

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
   - **Attach binaries**: Drag and drop the CloudToLocalLLM-Windows.zip file or click "Attach binaries by selecting them" and select the file

4. **Publish Release**
   - Click the "Publish release" button to make the release available to users

## Verifying the Release

After creating the release, verify that:

1. The release appears on the Releases page of the repository
2. The CloudToLocalLLM-Windows.zip file is attached to the release
3. The download link in the README.md file points to the correct location

## Updating the README (if necessary)

The README.md file already contains instructions for downloading the app from the Releases page. If you need to update these instructions, edit the README.md file and update the following section:

```markdown
1. **Download the Application**
   - Download the latest release from the [Releases](https://github.com/thrightguy/CloudToLocalLLM/releases) page.
   - Extract the ZIP file to a location of your choice.
```

## Building the Windows App (for future releases)

If you need to build a new version of the Windows app in the future:

1. Make sure all dependencies are up to date:
   ```
   flutter pub get
   ```

2. Build the Windows app:
   ```
   flutter build windows
   ```

3. Package the app into a ZIP file:
   ```
   Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "CloudToLocalLLM-Windows.zip" -Force
   ```

4. Create a new GitHub release following the instructions above