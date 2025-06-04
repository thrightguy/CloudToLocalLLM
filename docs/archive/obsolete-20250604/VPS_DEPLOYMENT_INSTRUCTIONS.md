# CloudToLocalLLM VPS Deployment Instructions

## Current Status
- ✅ Local build completed successfully (Enhanced Architecture v3.0.0)
- ✅ All components built and tested locally
- ✅ Git changes committed locally (pending push due to large file issues)
- ⏳ VPS deployment required

## VPS Deployment Steps

### 1. SSH to VPS
```bash
ssh cloudllm@app.cloudtolocalllm.online
```

### 2. Navigate to Project Directory
```bash
cd /opt/cloudtolocalllm
```

### 3. Backup Current Deployment
```bash
sudo cp -r /opt/cloudtolocalllm /opt/cloudtolocalllm-backup-$(date +%Y%m%d-%H%M%S)
```

### 4. Pull Latest Changes (when Git push is resolved)
```bash
git pull origin master
```

### 5. Upload Built Binaries
Since the large binary files cannot be pushed to Git, they need to be uploaded separately:

**Upload the following files to VPS:**
- `dist/CloudToLocalLLM-3.0.0-x86_64.AppImage` (138M)
- `dist/tray_daemon/linux-x64/cloudtolocalllm-enhanced-tray` (112M)
- `dist/tray_daemon/linux-x64/cloudtolocalllm-settings` (12M)

**Upload locations on VPS:**
```bash
# Create distribution directory
sudo mkdir -p /opt/cloudtolocalllm/dist/tray_daemon/linux-x64/

# Upload AppImage
scp dist/CloudToLocalLLM-3.0.0-x86_64.AppImage cloudllm@app.cloudtolocalllm.online:/opt/cloudtolocalllm/dist/

# Upload tray daemon executables
scp dist/tray_daemon/linux-x64/* cloudllm@app.cloudtolocalllm.online:/opt/cloudtolocalllm/dist/tray_daemon/linux-x64/

# Set proper permissions
sudo chmod +x /opt/cloudtolocalllm/dist/CloudToLocalLLM-3.0.0-x86_64.AppImage
sudo chmod +x /opt/cloudtolocalllm/dist/tray_daemon/linux-x64/cloudtolocalllm-enhanced-tray
sudo chmod +x /opt/cloudtolocalllm/dist/tray_daemon/linux-x64/cloudtolocalllm-settings
```

### 6. Run VPS Deployment Script
```bash
cd /opt/cloudtolocalllm
sudo ./scripts/deploy/update_and_deploy.sh
```

### 7. Verify Docker Containers
```bash
# Check container status
sudo docker ps

# Check container health
sudo docker-compose -f docker-compose.multi.yml ps

# View logs if needed
sudo docker-compose -f docker-compose.multi.yml logs
```

### 8. Test HTTPS Accessibility
```bash
# Test main application
curl -I https://app.cloudtolocalllm.online

# Test API backend
curl -I https://app.cloudtolocalllm.online/api/health

# Test downloads page
curl -I https://cloudtolocalllm.online/downloads
```

### 9. Update Downloads Page
Update the downloads page to include the new v3.0.0 packages:

**Add to downloads page:**
- CloudToLocalLLM-3.0.0-x86_64.AppImage (138M)
- Enhanced tray daemon documentation
- Installation instructions for v3.0.0

### 10. Verify Three-Component Synchronization

**Git Repository:**
- ✅ Enhanced architecture code committed locally
- ⏳ Large files need separate handling (Git LFS or releases)
- ⏳ Push to GitHub when file size issues resolved

**VPS Deployment:**
- ⏳ Deploy latest code to /opt/cloudtolocalllm
- ⏳ Upload built binaries
- ⏳ Run update_and_deploy.sh
- ⏳ Verify HTTPS accessibility

**AUR Repository:**
- ✅ PKGBUILD updated to v3.0.0
- ⏳ Test AUR package build
- ⏳ Submit to AUR repository

## Expected Results

### Container Status
All containers should be running:
- `cloudtolocalllm-webapp` (Flutter web app)
- `cloudtolocalllm-api` (Node.js backend)
- `cloudtolocalllm-nginx` (Reverse proxy)
- `cloudtolocalllm-docs` (Static documentation)

### HTTPS Accessibility
- ✅ https://app.cloudtolocalllm.online (Main application)
- ✅ https://cloudtolocalllm.online (Homepage)
- ✅ https://cloudtolocalllm.online/downloads (Downloads page)

### Downloads Available
- CloudToLocalLLM-3.0.0-x86_64.AppImage
- AUR package (cloudtolocalllm v3.0.0)
- Installation documentation

## Troubleshooting

### If Containers Fail to Start
```bash
# Check Docker logs
sudo docker-compose -f docker-compose.multi.yml logs

# Restart containers
sudo docker-compose -f docker-compose.multi.yml down
sudo docker-compose -f docker-compose.multi.yml up -d

# Check system resources
df -h
free -h
```

### If HTTPS Access Fails
```bash
# Check nginx configuration
sudo docker exec cloudtolocalllm-nginx nginx -t

# Check SSL certificates
sudo certbot certificates

# Restart nginx
sudo docker-compose -f docker-compose.multi.yml restart nginx
```

### If Downloads Page Needs Updates
```bash
# Update static homepage
cd /opt/cloudtolocalllm/static_homepage
# Edit downloads.html to include v3.0.0 packages
# Restart docs container
sudo docker-compose -f docker-compose.multi.yml restart docs
```

## Post-Deployment Verification

1. **Test Enhanced Architecture Components:**
   - Download and test AppImage on different Linux distributions
   - Verify tray daemon functionality
   - Test settings application

2. **Monitor System Performance:**
   - Check container resource usage
   - Monitor application logs
   - Verify system tray integration works

3. **Update Documentation:**
   - Update installation guides
   - Add v3.0.0 release notes
   - Document new enhanced architecture features

## Next Steps After VPS Deployment

1. **Resolve Git Repository Issues:**
   - Set up Git LFS for large files
   - Push code changes to GitHub
   - Create GitHub release with binaries

2. **Complete AUR Package:**
   - Test AUR package build
   - Submit to AUR repository
   - Verify installation from AUR

3. **Announce Release:**
   - Update project documentation
   - Announce v3.0.0 release
   - Share enhanced architecture features

## Security Notes

- Always use `cloudllm` user for VPS operations
- Never run Docker containers as root
- Maintain non-root container architecture
- Verify file permissions after uploads
- Test security isolation between components
