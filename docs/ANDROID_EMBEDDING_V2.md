# Android Embedding V2 Migration

## Overview

This document explains the migration of the CloudToLocalLLM app to Android embedding V2, which is required by newer versions of Flutter plugins, including device_info_plus 8.2.2+.

## What is Android Embedding V2?

Flutter's Android embedding refers to how the Flutter engine is integrated into Android applications. Flutter introduced a new embedding framework (V2) with Flutter 1.12, which offers several advantages:

- Improved lifecycle integration with Android
- Better plugin architecture
- Support for Activity and Fragment embedding
- Enhanced performance and memory management

## Why Migration Was Necessary

The migration was required because:

1. **Plugin Compatibility**: Newer versions of plugins like device_info_plus (≥8.2.2) require Android embedding V2
2. **Future Compatibility**: Flutter is phasing out support for embedding V1
3. **Build Errors**: Flutter builds would fail with the error message:
   ```
   The plugin `device_info_plus` requires your app to be migrated to the Android embedding v2.
   ```

## Changes Made During Migration

1. **Updated MainActivity.java**:
   - Switched base class from `FlutterActivity` to `io.flutter.embedding.android.FlutterActivity`
   - Removed legacy initialization code

2. **AndroidManifest.xml**:
   - Added `flutterEmbedding` metadata with value "2"
   - Updated application name references

3. **Plugin Registration**:
   - Created a V2-compliant plugin registration system
   - Removed legacy plugin registration code

4. **Gradle Dependencies**:
   - Added necessary AndroidX dependencies
   - Updated Flutter embedding dependencies

## Automated Migration

The migration is handled automatically by the script `scripts/setup/migrate_android_v2.sh`, which:
- Updates critical files with V2-compliant code
- Creates necessary directories and files
- Adjusts Gradle configurations

The `update_and_deploy.sh` script checks for V2 embedding and runs the migration if needed.

## Troubleshooting

If you encounter issues with the Android embedding after migration:

1. **Plugin Registration Issues**:
   - Check that all plugins are registered in `GeneratedPluginRegistrant.java`
   - Ensure the plugin versions are compatible with embedding V2

2. **Manifest Issues**:
   - Verify that the `flutterEmbedding` metadata tag is correctly placed in AndroidManifest.xml

3. **Build Failures**:
   - Look for AndroidX dependency conflicts
   - Check that all plugins support embedding V2

## References

- [Flutter Android Embedding Migration Guide](https://github.com/flutter/flutter/wiki/Upgrading-pre-1.12-Android-projects)
- [Flutter Android Embedding V2 Documentation](https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration)
- [Flutter Plugin Migration](https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration) 