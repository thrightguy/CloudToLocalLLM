# CloudToLocalLLM Docker-based AUR Building System

This directory contains the Docker-based solution for building AUR (Arch User Repository) packages on Ubuntu systems. The solution containerizes an Arch Linux environment with all necessary build dependencies, enabling AUR package creation from non-Arch systems.

## 🎯 Overview

The Docker-based AUR building system solves the problem of creating AUR packages on Ubuntu development environments. Since AUR packages require Arch Linux tools like `makepkg` and specific dependencies, this solution provides:

- **Arch Linux Container**: Complete Arch Linux environment with base-devel tools
- **Flutter SDK**: Pre-installed Flutter SDK for building CloudToLocalLLM
- **Universal Wrapper**: Automatic platform detection and Docker usage
- **File Permissions**: Proper handling of file ownership between container and host
- **Integration**: Seamless integration with existing deployment workflows

## 📁 Directory Structure

```
scripts/docker/
├── README.md                    # This documentation
├── build-aur-docker.sh         # Main Docker wrapper script
└── aur-builder/
    ├── Dockerfile              # Arch Linux container definition
    └── entrypoint.sh           # Container initialization script
```

## 🚀 Quick Start

### Prerequisites

1. **Docker Installation** (Ubuntu):
   ```bash
   sudo apt update
   sudo apt install docker.io
   sudo systemctl start docker
   sudo usermod -aG docker $USER
   # Logout and login again
   ```

2. **Project Setup**:
   ```bash
   cd /path/to/CloudToLocalLLM
   ```

### Basic Usage

1. **Build AUR Package**:
   ```bash
   ./scripts/docker/build-aur-docker.sh build
   ```

2. **Test AUR Package**:
   ```bash
   ./scripts/docker/build-aur-docker.sh test
   ```

3. **Submit AUR Package**:
   ```bash
   ./scripts/docker/build-aur-docker.sh submit
   ```

4. **Interactive Shell** (for debugging):
   ```bash
   ./scripts/docker/build-aur-docker.sh shell
   ```

### Universal Builder (Recommended)

The universal builder automatically detects your platform and uses the appropriate method:

```bash
# Auto-detect platform (Docker on Ubuntu, native on Arch)
./scripts/packaging/build_aur_universal.sh

# Force Docker usage (even on Arch Linux)
./scripts/packaging/build_aur_universal.sh --force-docker

# Verbose output
./scripts/packaging/build_aur_universal.sh --verbose
```

## 🔧 Detailed Usage

### Docker Wrapper Script

The `build-aur-docker.sh` script provides comprehensive Docker-based AUR building:

```bash
# Build Docker image and create AUR package
./scripts/docker/build-aur-docker.sh build [options]

# Available options:
--force-rebuild     # Force rebuild of Docker image
--no-cleanup        # Don't cleanup container after build
--verbose           # Enable detailed logging
--dry-run           # Simulate operations without execution
```

### Commands

| Command | Description | Example |
|---------|-------------|---------|
| `build` | Build AUR package using Docker | `./build-aur-docker.sh build` |
| `test` | Test AUR package installation | `./build-aur-docker.sh test` |
| `submit` | Submit AUR package to repository | `./build-aur-docker.sh submit` |
| `shell` | Open interactive shell in container | `./build-aur-docker.sh shell` |
| `clean` | Clean up Docker images and containers | `./build-aur-docker.sh clean` |

### Platform Detection

The universal builder (`build_aur_universal.sh`) automatically detects your platform:

1. **Arch Linux**: Uses native `scripts/packaging/build_aur.sh` if available
2. **Ubuntu/Other**: Uses Docker-based building automatically
3. **Force Docker**: Use `--force-docker` to use Docker even on Arch Linux

## 🐳 Docker Container Details

### Base Image
- **Image**: `archlinux:latest`
- **User**: Non-root `builder` user (required for makepkg)
- **Working Directory**: `/home/builder/workspace`

### Installed Packages
- **Build Tools**: base-devel, git, curl, wget, unzip
- **Flutter SDK**: Latest stable Flutter SDK
- **System Tools**: sudo, nano, vim, openssh, rsync, jq
- **Graphics**: imagemagick, gtk3, libayatana-appindicator

### Volume Mounting
The container mounts your project directory to `/home/builder/workspace`:
```bash
# Automatic mounting (handled by wrapper script)
docker run -v "$PROJECT_ROOT:/home/builder/workspace" cloudtolocalllm-aur-builder
```

### File Permissions
The wrapper script handles file permissions automatically:
- Uses your current user ID and group ID
- Ensures generated files are owned by your user
- Prevents permission issues with Docker-generated files

## 🔄 Integration with Deployment Workflow

The Docker-based AUR building is integrated into the main deployment workflow:

### Automatic Integration
The `scripts/deploy/complete_automated_deployment.sh` automatically:
1. Detects the platform (Arch Linux vs Ubuntu)
2. Uses appropriate build method (native vs Docker)
3. Builds AUR packages during Phase 3 (Multi-Platform Build)
4. Continues deployment even if AUR build fails

### Manual Integration
You can also integrate AUR building into custom scripts:

```bash
# Check if universal builder exists and use it
if [[ -f "scripts/packaging/build_aur_universal.sh" ]]; then
    ./scripts/packaging/build_aur_universal.sh --verbose
else
    echo "Universal AUR builder not available"
fi
```

## 🧪 Testing and Verification

### Build Testing
```bash
# Test Docker environment
./scripts/docker/build-aur-docker.sh shell
# Inside container:
flutter doctor
makepkg --version
```

### Package Testing
```bash
# Test AUR package (requires yay on Arch Linux)
./scripts/docker/build-aur-docker.sh test

# Test with specific options
./scripts/docker/build-aur-docker.sh test --verbose --skip-install
```

### Dry Run Testing
```bash
# Simulate all operations without execution
./scripts/packaging/build_aur_universal.sh --dry-run
./scripts/docker/build-aur-docker.sh build --dry-run
```

## 🔍 Troubleshooting

### Common Issues

1. **Docker Permission Denied**:
   ```bash
   sudo usermod -aG docker $USER
   # Logout and login again
   ```

2. **Container Build Fails**:
   ```bash
   # Force rebuild Docker image
   ./scripts/docker/build-aur-docker.sh build --force-rebuild
   ```

3. **File Permission Issues**:
   ```bash
   # Check file ownership
   ls -la dist/
   # Fix if needed
   sudo chown -R $USER:$USER dist/
   ```

4. **Flutter Issues in Container**:
   ```bash
   # Open shell and check Flutter
   ./scripts/docker/build-aur-docker.sh shell
   flutter doctor -v
   ```

### Debug Mode

For detailed debugging, use verbose mode and interactive shell:

```bash
# Verbose build
./scripts/docker/build-aur-docker.sh build --verbose

# Interactive debugging
./scripts/docker/build-aur-docker.sh shell
cd /home/builder/workspace
./scripts/packaging/build_aur.sh --verbose
```

### Log Analysis

Check Docker logs for container issues:
```bash
# List containers
docker ps -a

# Check logs
docker logs <container-id>
```

## 🔧 Customization

### Modifying the Docker Image

Edit `aur-builder/Dockerfile` to customize the container:
- Add additional packages
- Change Flutter version
- Modify user configuration

After changes, force rebuild:
```bash
./scripts/docker/build-aur-docker.sh build --force-rebuild
```

### Custom Build Scripts

The container can run any script in your project:
```bash
# Run custom script in container
docker run -v "$PWD:/home/builder/workspace" cloudtolocalllm-aur-builder bash -c "cd /home/builder/workspace && ./my-custom-script.sh"
```

## 📋 Best Practices

1. **Use Universal Builder**: Always use `build_aur_universal.sh` for automatic platform detection
2. **Regular Cleanup**: Periodically clean Docker resources with `./build-aur-docker.sh clean`
3. **Version Control**: Don't commit Docker-generated files to git
4. **Testing**: Always test AUR packages before submission
5. **Permissions**: Let the wrapper script handle file permissions automatically

## 🔗 Related Documentation

- [AUR Package Building](../packaging/README.md)
- [Deployment Workflow](../deploy/README.md)
- [Version Management](../version_manager.sh)
- [Flutter Build Process](../flutter_build_with_timestamp.sh)

## 📞 Support

For issues with the Docker-based AUR building system:
1. Check this documentation
2. Review troubleshooting section
3. Test with verbose mode and dry-run
4. Check Docker logs and container status
5. Verify project structure and dependencies