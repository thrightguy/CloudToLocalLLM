# CloudToLocalLLM Docker Development Environment

## Overview

This Docker-based development environment provides a complete, containerized Flutter setup for CloudToLocalLLM v3.5.0+ development. It eliminates the need for local Flutter installation while supporting all CloudToLocalLLM features including system tray integration and web deployment.

## Features

- **Complete Flutter Environment**: Pre-configured Flutter 3.32.2+ with Dart SDK
- **Platform Support**: Linux desktop and web development enabled
- **System Dependencies**: All required libraries for system tray and window management
- **Security**: Non-root user development environment
- **Persistence**: Cached dependencies and build artifacts
- **Testing Support**: Chrome for web testing, X11 forwarding for GUI testing
- **Health Monitoring**: Built-in health checks and validation

## Quick Start

### 1. Build Development Environment

```bash
# Build the development container
docker build -f Dockerfile.dev -t cloudtolocalllm:dev .

# Or use Docker Compose (recommended)
docker compose -f docker-compose.dev.yml build
```

### 2. Start Development Environment

```bash
# Using Docker Compose (recommended)
docker compose -f docker-compose.dev.yml up -d

# Enter the development container
docker compose -f docker-compose.dev.yml exec flutter bash

# Or using Docker directly
docker run -it --rm -v $(pwd):/workspace cloudtolocalllm:dev
```

### 3. Verify Environment

```bash
# Run health check
flutter-health

# Check Flutter configuration
flutter doctor

# Verify CloudToLocalLLM dependencies
flutter pub get
flutter analyze
```

## Development Workflow

### Basic Commands

```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Build for Linux desktop
flutter build linux --release

# Build for web
flutter build web --release

# Clean build artifacts
flutter clean
```

### Using Convenience Aliases

The container includes helpful aliases:

```bash
flutter-health    # Run comprehensive health check
flutter-build     # Build for Linux desktop
flutter-web       # Build for web
flutter-test      # Run tests
flutter-analyze   # Analyze code
flutter-clean     # Clean build artifacts
```

### System Tray Development

For testing system tray functionality with GUI support:

```bash
# Enable X11 forwarding (Linux/macOS)
xhost +local:docker

# Run with GUI support
docker run -it --rm \
  -v $(pwd):/workspace \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  cloudtolocalllm:dev

# Test system tray
flutter run -d linux
```

## Docker Compose Profiles

### Default Profile
- Flutter development environment
- Basic port forwarding

### Testing Profile
```bash
# Start with testing services
docker compose -f docker-compose.dev.yml --profile testing up -d

# Includes:
# - Ollama service (localhost:11434)
# - Nginx web server (localhost:8081)
```

## Environment Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLUTTER_ROOT` | `/opt/flutter` | Flutter SDK location |
| `PUB_CACHE` | `/home/flutter/.pub-cache` | Pub package cache |
| `FLUTTER_WEB_USE_SKIA` | `true` | Enable Skia for web rendering |
| `CHROME_EXECUTABLE` | `/usr/bin/google-chrome-stable` | Chrome for web testing |

### Volumes

| Volume | Purpose |
|--------|---------|
| `.:/workspace` | Source code mounting |
| `flutter-pub-cache` | Persistent package cache |
| `flutter-build-cache` | Persistent Flutter cache |

### Ports

| Port | Service |
|------|---------|
| 8080 | Flutter web dev server |
| 3000 | Alternative web port |
| 4000 | API development |
| 5000 | Additional services |
| 11434 | Ollama (testing profile) |
| 8081 | Nginx web server (testing profile) |

## Troubleshooting

### Common Issues

#### 1. Permission Issues
```bash
# Fix file permissions
sudo chown -R $(id -u):$(id -g) .
```

#### 2. X11 Display Issues
```bash
# Enable X11 forwarding
xhost +local:docker

# Check DISPLAY variable
echo $DISPLAY
```

#### 3. Build Failures
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build linux --release
```

#### 4. System Tray Not Working
```bash
# Verify GTK3 libraries
pkg-config --exists gtk+-3.0

# Check system tray dependencies
dpkg -l | grep libayatana-appindicator
```

### Health Check

The container includes a comprehensive health check:

```bash
# Manual health check
/home/flutter/health-check.sh

# Check container health
docker compose -f docker-compose.dev.yml ps
```

## Advanced Usage

### Custom Flutter Channel

```dockerfile
# Modify Dockerfile.dev to use different Flutter channel
FROM ghcr.io/cirruslabs/flutter:beta
# or
FROM ghcr.io/cirruslabs/flutter:master
```

### Additional System Dependencies

```dockerfile
# Add to Dockerfile.dev
RUN apt-get update && apt-get install -y \
    your-additional-package \
    && rm -rf /var/lib/apt/lists/*
```

### IDE Integration

#### VS Code with Remote Containers

1. Install "Remote - Containers" extension
2. Create `.devcontainer/devcontainer.json`:

```json
{
  "name": "CloudToLocalLLM Development",
  "dockerComposeFile": "../docker-compose.dev.yml",
  "service": "flutter",
  "workspaceFolder": "/workspace",
  "extensions": [
    "Dart-Code.flutter",
    "Dart-Code.dart-code"
  ]
}
```

## Performance Optimization

### Build Cache Optimization

```bash
# Pre-warm build cache
docker compose -f docker-compose.dev.yml exec flutter flutter precache

# Use build cache volume
docker volume create flutter-build-cache
```

### Memory Configuration

```yaml
# In docker-compose.dev.yml
services:
  flutter:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

## Security Considerations

- Container runs as non-root user (`flutter:1000`)
- Limited sudo access for development needs
- Isolated network environment
- Read-only volume mounts where appropriate

## Contributing

When contributing to the Docker environment:

1. Test changes with both Docker and Docker Compose
2. Verify health checks pass
3. Ensure all CloudToLocalLLM features work
4. Update documentation for any new features
5. Test on multiple platforms (Linux, macOS, Windows with WSL2)

## Support

For issues with the Docker development environment:

1. Run health check: `flutter-health`
2. Check container logs: `docker compose logs flutter`
3. Verify host system requirements
4. Consult CloudToLocalLLM documentation
5. Report issues with environment details
