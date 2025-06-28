# CloudToLocalLLM GitHub Actions Setup Guide

This guide will help you set up the GitHub Actions workflows for CloudToLocalLLM in under 15 minutes.

## 🚀 Quick Start

### Step 1: Enable GitHub Actions (1 minute)

1. Go to your repository on GitHub
2. Click on the **Actions** tab
3. If prompted, click **"I understand my workflows, go ahead and enable them"**

### Step 2: Configure Secrets (5 minutes)

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Click **"New repository secret"** and add the following:

#### Required Secrets

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `VPS_SSH_PRIVATE_KEY` | SSH private key for VPS access | Generate with `ssh-keygen -t ed25519` |

#### Optional Secrets

| Secret Name | Default Value | Description |
|-------------|---------------|-------------|
| `VPS_HOST` | `cloudtolocalllm.online` | VPS hostname |
| `VPS_USER` | `cloudllm` | VPS username |
| `STAGING_SSH_PRIVATE_KEY` | - | SSH key for staging environment |

### Step 3: Generate SSH Key (3 minutes)

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/cloudtolocalllm_deploy -C "github-actions@cloudtolocalllm"

# Copy public key to VPS
ssh-copy-id -i ~/.ssh/cloudtolocalllm_deploy.pub cloudllm@cloudtolocalllm.online

# Display private key (copy this to GitHub secrets)
cat ~/.ssh/cloudtolocalllm_deploy
```

### Step 4: Set Up Environments (3 minutes)

1. Go to **Settings** > **Environments**
2. Click **"New environment"**
3. Create `production` environment:
   - **Environment name**: `production`
   - **Protection rules**: 
     - ✅ Required reviewers: 1
     - ✅ Wait timer: 5 minutes
   - **Deployment branches**: Only protected branches

4. Optionally create `staging` environment with similar settings

### Step 5: Test the Setup (3 minutes)

1. Go to **Actions** tab
2. Click **"Manual Release"** workflow
3. Click **"Run workflow"**
4. Configure:
   - **Version increment**: `build`
   - **Create GitHub release**: `false`
   - **Deploy to VPS**: `false`
   - **Skip tests**: `true`
5. Click **"Run workflow"**

If the workflow completes successfully, your setup is working! ✅

## 🔧 Advanced Configuration

### Custom VPS Configuration

If you're using a different VPS setup:

1. **Custom hostname**:
   ```bash
   # Add VPS_HOST secret with your hostname
   your-custom-domain.com
   ```

2. **Custom username**:
   ```bash
   # Add VPS_USER secret with your username
   your-username
   ```

3. **Custom deployment script**:
   ```yaml
   # Modify the deployment_script input in workflows
   deployment_script: './scripts/deploy/your-custom-script.sh --flags'
   ```

### Notification Setup

Add webhook notifications for workflow results:

1. **Slack Integration**:
   ```bash
   # Add SLACK_WEBHOOK secret with your Slack webhook URL
   https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
   ```

2. **Discord Integration**:
   ```bash
   # Add DISCORD_WEBHOOK secret with your Discord webhook URL
   https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK
   ```

### Custom Build Matrix

Modify the build matrix in workflows to add/remove platforms:

```yaml
# In .github/workflows/ci-cd-main.yml
strategy:
  matrix:
    include:
      - os: ubuntu-latest
        platform: linux
      - os: ubuntu-latest
        platform: web
      - os: windows-latest
        platform: windows
      # Add macOS if needed
      - os: macos-latest
        platform: macos
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. SSH Connection Failed

**Error**: `Permission denied (publickey)`

**Solution**:
```bash
# Verify SSH key is correctly formatted
cat ~/.ssh/cloudtolocalllm_deploy | head -1
# Should start with: -----BEGIN OPENSSH PRIVATE KEY-----

# Test SSH connection manually
ssh -i ~/.ssh/cloudtolocalllm_deploy cloudllm@cloudtolocalllm.online
```

#### 2. VPS Directory Not Found

**Error**: `cd: /opt/cloudtolocalllm: No such file or directory`

**Solution**:
```bash
# SSH to VPS and create directory
ssh cloudllm@cloudtolocalllm.online
sudo mkdir -p /opt/cloudtolocalllm
sudo chown cloudllm:cloudllm /opt/cloudtolocalllm
cd /opt/cloudtolocalllm
git clone https://github.com/imrightguy/CloudToLocalLLM.git .
```

#### 3. Flutter Build Failed

**Error**: `Flutter SDK not found`

**Solution**: The workflow automatically installs Flutter. If this fails:
- Check if the Flutter version in workflows matches your project requirements
- Update `flutter_version` in workflow files if needed

#### 4. Package Build Failed

**Error**: `Docker not available` or `Package build script not found`

**Solution**:
```bash
# Verify scripts exist and are executable
ls -la scripts/packaging/
chmod +x scripts/packaging/*.sh
```

### Debug Mode

Enable debug logging for detailed troubleshooting:

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Add repository secret:
   - **Name**: `ACTIONS_STEP_DEBUG`
   - **Value**: `true`

This will show detailed logs for all workflow steps.

### Manual Verification

Test individual components manually:

```bash
# Test version management
./scripts/version_manager.sh info

# Test deployment script
./scripts/deploy/update_and_deploy.sh --dry-run

# Test package building
./scripts/packaging/build_aur_universal.sh --verbose
```

## 📋 Workflow Checklist

Use this checklist to verify your setup:

- [ ] GitHub Actions enabled
- [ ] `VPS_SSH_PRIVATE_KEY` secret added
- [ ] SSH key added to VPS authorized_keys
- [ ] Production environment created
- [ ] Test workflow run successful
- [ ] VPS directory structure exists
- [ ] All required scripts are executable
- [ ] Docker is available on VPS (for package building)

## 🎯 Next Steps

After setup is complete:

1. **Test Full Pipeline**: Push a small change to master branch
2. **Create First Release**: Use Manual Release workflow with version increment
3. **Monitor Nightly Builds**: Check that nightly builds run automatically
4. **Set Up Notifications**: Configure Slack/Discord webhooks for alerts
5. **Review Logs**: Familiarize yourself with workflow logs and outputs

## 📞 Getting Help

If you encounter issues:

1. **Check Workflow Logs**: Go to Actions tab and review failed job logs
2. **Enable Debug Mode**: Add `ACTIONS_STEP_DEBUG: true` secret
3. **Test Components**: Run individual scripts manually to isolate issues
4. **Review Documentation**: Check the main README.md in workflows directory
5. **Create Issue**: If problems persist, create a GitHub issue with logs

## 🔄 Maintenance

Regular maintenance tasks:

- **Monthly**: Rotate SSH keys
- **Quarterly**: Update Flutter version in workflows
- **As Needed**: Update package dependencies
- **Before Major Releases**: Test full pipeline in staging environment

Your CloudToLocalLLM GitHub Actions setup is now complete! 🎉
