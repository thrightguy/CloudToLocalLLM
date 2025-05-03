# CloudToLocalLLM Scripts

This directory contains utility scripts for the CloudToLocalLLM project.

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