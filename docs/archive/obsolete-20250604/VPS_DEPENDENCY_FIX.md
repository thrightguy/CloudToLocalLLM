# VPS Dependency Fix Guide

This document provides instructions for fixing the dependency conflicts affecting the VPS deployment of CloudToLocalLLM.

## Problem Summary

The VPS deployment is failing with the following error:

```
Because device_info_plus_windows >=4.1.0 depends on win32 >=2.7.0 <4.0.0 and device_info_plus_windows >=3.0.0 <4.1.0 depends on win32 ^2.7.0, device_info_plus_windows >=3.0.0 requires win32 >=2.7.0 <4.0.0.
And because device_info_plus ^4.1.2 depends on device_info_plus_windows ^4.0.0, device_info_plus ^4.1.2 requires win32 >=2.7.0 <4.0.0.
So, because cloudtolocalllm depends on both win32 ^4.1.4 and device_info_plus ^4.1.3, version solving failed.
```

This conflict occurs because:
1. The project is specifying `win32: ^4.1.4`
2. However, `device_info_plus: ^4.1.3` requires `win32 >=2.7.0 <4.0.0`
3. These constraints cannot be satisfied simultaneously

## Fix Instructions

### 1. Update the pubspec.yaml File

SSH into the VPS and update the pubspec.yaml file:

```bash
# SSH to the server
ssh root@server1.cloudtolocalllm.online

# Navigate to the project directory
cd /opt/cloudtolocalllm

# Edit pubspec.yaml
nano pubspec.yaml
```

Make the following changes to the pubspec.yaml file:

1. Change `win32` version from `^4.1.4` to `^2.7.0`
2. Change `device_info_plus` version from `^4.1.3` to `^8.2.2`
3. Update `path` dependency from `>=1.8.2 <1.9.0` to `>=1.8.2 <2.0.0`

Example of changes:
```yaml
# Before
win32: ^4.1.4
device_info_plus: ^4.1.3
path: '>=1.8.2 <1.9.0'

# After
win32: ^2.7.0
device_info_plus: ^8.2.2
path: '>=1.8.2 <2.0.0'
```

Save the file.

### 2. Update Dependencies

```bash
# Run flutter pub get to update dependencies
cd /opt/cloudtolocalllm
flutter pub get
```

### 3. Rebuild and Restart Services

```bash
# Trigger a full rebuild and restart of services
bash scripts/setup/startup_vps.sh
```

## Verification

After applying the fix:

1. Check that all services have started successfully:
```bash
curl -X GET http://localhost:9001/status
```

2. Verify the webapp is accessible:
```bash
curl -I https://webapp.cloudtolocalllm.online
```

## Troubleshooting

If issues persist:

1. Check Flutter version on the VPS:
```bash
flutter --version
```

2. Examine the Docker build logs:
```bash
docker logs webapp-service
```

3. Try rebuilding just the webapp:
```bash
curl -X POST http://localhost:9001/deploy/webapp
```

## Long-term Solution

To prevent similar issues in the future:

1. Document specific dependency constraints in the DEPENDENCY_MANAGEMENT.md file
2. Add automated checks in CI/CD to verify dependency compatibility
3. Test all builds in an environment similar to the VPS before deployment

## Related Documentation

See [DEPENDENCY_MANAGEMENT.md](DEPENDENCY_MANAGEMENT.md) for more details on managing dependencies in this project. 