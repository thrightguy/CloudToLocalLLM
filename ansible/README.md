# CloudToLocalLLM Ansible Automation

This directory contains Ansible playbooks and configuration for automating the CloudToLocalLLM deployment pipeline, replacing the existing PowerShell and bash script-based workflow with a unified, maintainable automation solution.

## Overview

The Ansible automation provides:

- **Unified deployment pipeline** across Windows, Linux, and VPS environments
- **Cross-platform package building** (Windows, AUR, AppImage, Flatpak, .deb)
- **Version management** with timestamp-based build numbers
- **GitHub release automation** with asset uploading
- **VPS deployment** with Docker container management
- **Multi-tenant streaming proxy** architecture automation

## Quick Start

### Prerequisites

1. **Ansible Installation**:
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install ansible
   
   # Arch Linux
   sudo pacman -S ansible
   
   # macOS
   brew install ansible
   
   # Windows (WSL)
   sudo apt update && sudo apt install ansible
   ```

2. **Required Tools**:
   - Flutter SDK (stable channel)
   - Docker and Docker Compose
   - GitHub CLI (`gh`) for release management
   - Git with SSH key access to the repository

3. **Authentication Setup**:
   ```bash
   # GitHub CLI authentication
   gh auth login
   
   # SSH key for VPS access
   ssh-copy-id cloudllm@app.cloudtolocalllm.online
   ```

### Basic Usage

1. **Complete Deployment Pipeline**:
   ```bash
   # Run full deployment (version, build, release, deploy)
   ansible-playbook site.yml
   
   # With version increment
   ansible-playbook site.yml -e increment=minor
   
   # Force rebuild and recreate release
   ansible-playbook site.yml -e force=true
   ```

2. **Individual Operations**:
   ```bash
   # Version management only
   ansible-playbook site.yml --tags version-only -e increment=patch
   
   # Build packages only
   ansible-playbook site.yml --tags build-only
   
   # GitHub release only
   ansible-playbook site.yml --tags release-only
   
   # VPS deployment only
   ansible-playbook site.yml --tags deploy-only
   ```

3. **Platform-Specific Builds**:
   ```bash
   # Windows packages only
   ansible-playbook playbooks/build-packages.yml -e platforms='["windows"]'
   
   # Linux packages only
   ansible-playbook playbooks/build-packages.yml -e platforms='["linux"]'
   
   # Web build only
   ansible-playbook playbooks/build-packages.yml -e platforms='["web"]'
   ```

## Architecture

### Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── site.yml                   # Main deployment playbook
├── inventory/
│   └── hosts.yml              # Inventory configuration
├── group_vars/
│   └── all.yml                # Global variables
├── playbooks/
│   ├── version-management.yml  # Version synchronization
│   ├── build-packages.yml     # Cross-platform builds
│   ├── build-docker.yml       # Docker image builds
│   ├── github-release.yml     # GitHub release management
│   ├── deploy-vps.yml         # VPS deployment
│   └── tasks/                 # Reusable task files
├── templates/
│   ├── release-notes.j2       # Release notes template
│   └── docker-compose.override.yml.j2
└── logs/                      # Ansible execution logs
```

### Playbook Overview

1. **Version Management** (`version-management.yml`):
   - Increments semantic versions (major.minor.patch)
   - Generates timestamp-based build numbers
   - Synchronizes versions across multiple files
   - Validates version consistency

2. **Package Building** (`build-packages.yml`):
   - Cross-platform Flutter builds (Windows, Linux, Web)
   - Package creation (ZIP, AUR, AppImage, Flatpak, .deb)
   - Checksum generation and verification
   - Platform abstraction handling

3. **Docker Management** (`build-docker.yml`):
   - Multi-container image builds
   - Security configuration and testing
   - Resource limit enforcement
   - Registry push capabilities

4. **GitHub Releases** (`github-release.yml`):
   - Automated release creation
   - Asset uploading and verification
   - Release notes generation
   - Tag management

5. **VPS Deployment** (`deploy-vps.yml`):
   - Remote deployment to cloudllm@app.cloudtolocalllm.online
   - Docker container orchestration
   - Health checks and verification
   - Backup and rollback capabilities

## Configuration

### Inventory Configuration

The inventory defines build hosts and deployment targets:

- **Windows Builders**: Local Windows environment or WSL
- **Linux Builders**: WSL Ubuntu for cross-platform builds
- **VPS Servers**: Production deployment target
- **GitHub API**: Release management endpoint

### Variables

Key configuration variables in `group_vars/all.yml`:

```yaml
# Project configuration
project:
  name: CloudToLocalLLM
  repository: https://github.com/imrightguy/CloudToLocalLLM

# Version management
version:
  format: semantic
  build_number_format: timestamp
  auto_increment: true

# Build configuration
build:
  clean_before_build: true
  parallel_builds: true
  max_parallel_jobs: 4

# Docker configuration
docker:
  registry: docker.io
  namespace: cloudtolocalllm
  security:
    user: proxyuser
    uid: 1001
    gid: 1001

# VPS configuration
vps:
  host: app.cloudtolocalllm.online
  user: cloudllm
  project_dir: /opt/cloudtolocalllm
```

## Advanced Usage

### Custom Build Configurations

```bash
# Build with custom output directory
ansible-playbook playbooks/build-packages.yml -e output_dir=/custom/path

# Skip clean build
ansible-playbook playbooks/build-packages.yml -e clean=false

# Build specific package types
ansible-playbook playbooks/build-packages.yml -e package_types='["aur","appimage"]'
```

### Docker Management

```bash
# Build and push to registry
ansible-playbook playbooks/build-docker.yml -e push=true

# Force rebuild with no cache
ansible-playbook playbooks/build-docker.yml -e force_rebuild=true

# Custom build arguments
ansible-playbook playbooks/build-docker.yml -e build_args='{"BUILD_ENV":"production"}'
```

### VPS Deployment Options

```bash
# Deploy without backup
ansible-playbook playbooks/deploy-vps.yml -e skip_backup=true

# Force container rebuild
ansible-playbook playbooks/deploy-vps.yml -e force=true

# Rolling deployment strategy
ansible-playbook playbooks/deploy-vps.yml -e strategy=rolling
```

## Migration from Scripts

### Equivalent Commands

| Script Command | Ansible Equivalent |
|----------------|-------------------|
| `.\scripts\powershell\version_manager.ps1 increment minor` | `ansible-playbook site.yml --tags version-only -e increment=minor` |
| `.\scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1` | `ansible-playbook site.yml --tags build-only` |
| `.\scripts\deploy\update_and_deploy.sh` | `ansible-playbook site.yml --tags deploy-only` |
| `.\scripts\release\create_github_release.sh` | `ansible-playbook site.yml --tags release-only` |

### Benefits Over Scripts

1. **Unified Interface**: Single command syntax across all platforms
2. **Error Handling**: Comprehensive error handling and rollback
3. **Idempotency**: Safe to run multiple times
4. **Logging**: Centralized logging and audit trails
5. **Modularity**: Reusable components and tasks
6. **Testing**: Built-in verification and health checks

## Troubleshooting

### Common Issues

1. **Flutter Build Failures**:
   ```bash
   # Check Flutter installation
   flutter doctor
   
   # Clean and retry
   ansible-playbook site.yml -e clean=true
   ```

2. **Docker Permission Issues**:
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **VPS Connection Issues**:
   ```bash
   # Test SSH connectivity
   ansible cloudtolocalllm_vps -m ping
   
   # Check SSH key
   ssh cloudllm@app.cloudtolocalllm.online
   ```

4. **GitHub Authentication**:
   ```bash
   # Re-authenticate GitHub CLI
   gh auth logout
   gh auth login
   ```

### Debug Mode

```bash
# Run with verbose output
ansible-playbook site.yml -vvv

# Check specific task
ansible-playbook site.yml --start-at-task="Task Name"

# Dry run mode
ansible-playbook site.yml --check
```

## Security Considerations

- **SSH Keys**: Use dedicated SSH keys for VPS access
- **GitHub Tokens**: Store tokens securely using Ansible Vault
- **Container Security**: Non-root containers with capability dropping
- **Network Isolation**: Multi-tenant Docker networks
- **Resource Limits**: Memory and CPU constraints for containers

## Contributing

When modifying the Ansible automation:

1. Test changes in a development environment
2. Update documentation for new variables or tasks
3. Follow Ansible best practices for playbook structure
4. Ensure backward compatibility with existing workflows
5. Add appropriate error handling and logging
