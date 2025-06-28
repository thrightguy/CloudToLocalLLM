# CloudToLocalLLM GitHub Actions Workflows

This directory contains comprehensive GitHub Actions workflows for automated CI/CD, release management, and deployment of CloudToLocalLLM.

## 📋 Overview

The workflow system is designed with modularity, reusability, and reliability in mind:

- **Main CI/CD Pipeline**: Automated builds and deployments on push to master
- **Manual Release Workflow**: Controlled release creation with version management
- **Nightly Builds**: Automated testing and package creation
- **Reusable Components**: Modular workflows for common operations
- **Error Handling**: Comprehensive retry logic and failure recovery

## 🚀 Workflows

### 1. Main CI/CD Pipeline (`ci-cd-main.yml`)

**Trigger**: Push to master branch, manual dispatch

**Purpose**: Automated continuous integration and deployment

**Features**:
- Automatic version management with timestamp-based build numbers
- Cross-platform builds (Windows, Linux, Web)
- Linux package creation (AUR, DEB)
- VPS deployment with verification
- Comprehensive error handling and retry logic

**Usage**:
```yaml
# Automatically triggered on push to master
# Manual trigger with options:
workflow_dispatch:
  inputs:
    skip_tests: false
    skip_deployment: false
    force_rebuild: false
```

### 2. Manual Release Workflow (`manual-release.yml`)

**Trigger**: Manual dispatch only

**Purpose**: Create official releases with proper versioning and asset management

**Features**:
- Version increment options (patch, minor, major, build)
- Custom version setting
- GitHub release creation with assets
- Cross-platform package building
- VPS deployment
- Release notes generation

**Usage**:
```yaml
workflow_dispatch:
  inputs:
    version_increment: 'patch'  # patch, minor, major, build
    custom_version: ''          # Optional: override increment
    create_github_release: true
    deploy_to_vps: true
    prerelease: false
```

### 3. Nightly Builds (`nightly-builds.yml`)

**Trigger**: Scheduled (2:00 AM UTC daily), manual dispatch

**Purpose**: Automated testing and package creation for development builds

**Features**:
- Smart build triggering (only if changes detected)
- Extended testing suite
- Cross-platform nightly builds
- Package creation and verification
- Automatic cleanup of old builds

**Usage**:
```yaml
# Automatically runs at 2:00 AM UTC if changes detected
# Manual trigger with options:
workflow_dispatch:
  inputs:
    build_all_packages: true
    run_extended_tests: true
    deploy_to_staging: false
```

## 🔧 Reusable Workflows

### Version Management (`reusable-version-management.yml`)

Handles version increment, synchronization, and validation across all project files.

**Inputs**:
- `increment_type`: Version increment type (patch, minor, major, build)
- `custom_version`: Custom version to set
- `commit_changes`: Whether to commit version changes
- `use_timestamp_build`: Use timestamp for build number

**Outputs**:
- `version`: Semantic version (x.y.z)
- `build_number`: Build number
- `full_version`: Full version (x.y.z+build)
- `previous_version`: Previous semantic version
- `is_major_release`: Whether this is a major release

### Flutter Build (`reusable-flutter-build.yml`)

Handles cross-platform Flutter application building with testing.

**Inputs**:
- `flutter_version`: Flutter version to use
- `platforms`: Platforms to build (comma-separated)
- `build_mode`: Build mode (release, debug, profile)
- `version`: Version string for artifact naming
- `skip_tests`: Skip running tests

### Package Build (`reusable-package-build.yml`)

Handles Linux package creation (AUR, DEB, AppImage, Snap).

**Inputs**:
- `package_types`: Package types to build (comma-separated)
- `version`: Version string for package naming
- `fail_fast`: Fail fast on first package build failure

### VPS Deployment (`reusable-vps-deployment.yml`)

Handles deployment to VPS with verification and rollback capabilities.

**Inputs**:
- `environment`: Deployment environment (production, staging)
- `version`: Version being deployed
- `deployment_script`: Deployment script to run on VPS
- `skip_backup`: Skip backup creation
- `dry_run`: Perform dry run deployment

**Secrets**:
- `ssh_private_key`: SSH private key for VPS access
- `vps_host`: VPS hostname (optional, defaults to cloudtolocalllm.online)
- `vps_user`: VPS username (optional, defaults to cloudllm)

## 🔐 Required Secrets

Configure these secrets in your GitHub repository settings:

### Required
- `VPS_SSH_PRIVATE_KEY`: SSH private key for VPS deployment
- `GITHUB_TOKEN`: Automatically provided by GitHub

### Optional
- `STAGING_SSH_PRIVATE_KEY`: SSH private key for staging deployment
- `VPS_HOST`: Custom VPS hostname (defaults to cloudtolocalllm.online)
- `VPS_USER`: Custom VPS username (defaults to cloudllm)

## 🛠️ Setup Instructions

### 1. Repository Configuration

1. **Enable GitHub Actions**: Ensure Actions are enabled in repository settings
2. **Configure Secrets**: Add required secrets in Settings > Secrets and variables > Actions
3. **Set up Environments**: Create `production` and `staging` environments with protection rules

### 2. VPS Configuration

1. **SSH Key Setup**:
   ```bash
   # Generate SSH key pair
   ssh-keygen -t ed25519 -C "github-actions@cloudtolocalllm"
   
   # Add public key to VPS authorized_keys
   ssh-copy-id -i ~/.ssh/id_ed25519.pub cloudllm@cloudtolocalllm.online
   
   # Add private key to GitHub secrets as VPS_SSH_PRIVATE_KEY
   ```

2. **VPS Directory Structure**:
   ```
   /opt/cloudtolocalllm/          # Main project directory
   /opt/backups/                  # Backup directory
   ```

### 3. First Run

1. **Test Manual Release**:
   - Go to Actions tab
   - Select "Manual Release"
   - Run with `version_increment: build` and `deploy_to_vps: false`

2. **Verify CI/CD**:
   - Make a small change and push to master
   - Monitor the CI/CD pipeline execution

## 📊 Monitoring and Troubleshooting

### Workflow Status

Monitor workflow status through:
- GitHub Actions tab
- Commit status checks
- Email notifications (if configured)

### Common Issues

1. **SSH Connection Failures**:
   - Verify SSH key is correctly added to secrets
   - Check VPS SSH configuration
   - Ensure firewall allows SSH connections

2. **Build Failures**:
   - Check Flutter version compatibility
   - Verify dependencies are up to date
   - Review build logs for specific errors

3. **Deployment Failures**:
   - Check VPS disk space
   - Verify Docker is running on VPS
   - Review deployment script logs

### Debugging

Enable verbose logging by:
1. Adding `ACTIONS_STEP_DEBUG: true` to repository secrets
2. Using manual dispatch with verbose options
3. Checking individual job logs

## 🔄 Integration with Existing Scripts

The workflows integrate seamlessly with existing CloudToLocalLLM scripts:

- **Version Management**: Uses `scripts/version_manager.sh`
- **Deployment**: Uses `scripts/deploy/complete_automated_deployment.sh`
- **Package Building**: Uses `scripts/packaging/build_*.sh`
- **Synchronization**: Uses `scripts/deploy/sync_versions.sh`

## 📈 Best Practices

1. **Version Management**:
   - Use semantic versioning
   - Always test before major releases
   - Keep build numbers timestamp-based

2. **Deployment**:
   - Always backup before deployment
   - Verify deployment after completion
   - Use staging environment for testing

3. **Security**:
   - Rotate SSH keys regularly
   - Use environment protection rules
   - Limit secret access to necessary workflows

## ⚙️ Configuration Examples

### Environment-Specific Configuration

Create environment-specific configurations in `.github/environments/`:

```yaml
# .github/environments/production.yml
name: production
protection_rules:
  required_reviewers: 1
  wait_timer: 5
deployment_branch_policy:
  protected_branches: true
```

### Custom Workflow Triggers

```yaml
# Custom trigger for hotfix releases
on:
  push:
    branches: [ hotfix/* ]
  workflow_dispatch:
    inputs:
      hotfix_version:
        description: 'Hotfix version'
        required: true
```

### Matrix Strategy Customization

```yaml
# Custom build matrix
strategy:
  matrix:
    include:
      - os: ubuntu-latest
        flutter: '3.32.2'
        platform: linux
      - os: windows-latest
        flutter: '3.32.2'
        platform: windows
      - os: macos-latest
        flutter: '3.32.2'
        platform: macos
```

## 🆘 Support

For issues with GitHub Actions workflows:

1. Check workflow logs in the Actions tab
2. Review this documentation
3. Check existing deployment scripts
4. Create an issue with workflow logs attached

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)
- [CloudToLocalLLM Deployment Guide](../../docs/DEPLOYMENT/)
