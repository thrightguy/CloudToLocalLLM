# CloudToLocalLLM User Troubleshooting Guide

## 🔧 Overview

This guide helps you resolve common issues with CloudToLocalLLM v3.6.2+. The unified Flutter-native architecture simplifies troubleshooting by eliminating external daemon dependencies.

**Quick Help:**
- 🚨 **Critical Issues**: [Connection Problems](#connection-problems)
- 🖥️ **System Tray Issues**: [System Tray Troubleshooting](#system-tray-troubleshooting)
- 🌐 **Web Interface**: [Web Access Problems](#web-access-problems)
- 🔐 **Authentication**: [Auth Issues](#authentication-issues)

---

## 🚨 **Connection Problems**

### **Ollama Not Detected**

#### **Symptoms**
- "No local Ollama connection" message
- Empty model list
- Connection timeout errors

#### **Solutions**
```bash
# 1. Check if Ollama is running
systemctl --user status ollama
# or
ps aux | grep ollama

# 2. Verify Ollama is listening on correct port
netstat -ln | grep 11434
# Should show: tcp 127.0.0.1:11434

# 3. Test Ollama directly
curl http://localhost:11434/api/version

# 4. Restart Ollama if needed
systemctl --user restart ollama
# or
ollama serve
```

#### **Alternative Ports**
If Ollama runs on a different port:
1. Open CloudToLocalLLM Settings
2. Navigate to "Connection Settings"
3. Update "Local Ollama URL" to match your configuration
4. Test connection

### **Cloud Proxy Connection Failed**

#### **Symptoms**
- "Cloud proxy unavailable" status
- Authentication errors in web interface
- Tunnel connection timeouts

#### **Solutions**
```bash
# 1. Check internet connectivity
ping app.cloudtolocalllm.online

# 2. Verify DNS resolution
nslookup app.cloudtolocalllm.online

# 3. Test HTTPS connectivity
curl -I https://app.cloudtolocalllm.online

# 4. Check firewall settings
sudo ufw status
# Ensure ports 80, 443 are allowed outbound
```

---

## 🖥️ **System Tray Troubleshooting**

### **System Tray Not Visible**

#### **Linux (Most Common)**
```bash
# Install tray support packages
# Ubuntu/Debian:
sudo apt install libayatana-appindicator3-1

# GNOME users:
sudo apt install gnome-shell-extension-appindicator

# Arch Linux:
sudo pacman -S libayatana-appindicator

# Restart CloudToLocalLLM after installation
```

#### **GNOME Desktop**
```bash
# Enable AppIndicator extension
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com

# If extension not installed:
sudo apt install gnome-shell-extension-appindicator
# Then log out and back in
```

#### **KDE Plasma**
```bash
# Enable system tray widget
# Right-click panel → Add Widgets → System Tray
# Or check if "Status and Notifications" is enabled
```

### **System Tray Shows Wrong Status**

#### **Force Status Refresh**
1. Right-click system tray icon
2. Select "Refresh Status"
3. Wait 5-10 seconds for update

#### **Reset Tray Service**
```bash
# Close CloudToLocalLLM completely
pkill cloudtolocalllm

# Clear tray cache (if exists)
rm -rf ~/.cache/cloudtolocalllm/tray

# Restart application
cloudtolocalllm
```

---

## 🌐 **Web Access Problems**

### **Cannot Access Web Interface**

#### **Check Service Status**
```bash
# If self-hosting, verify containers are running
docker compose ps

# Check if web service is accessible
curl -I https://app.cloudtolocalllm.online
```

#### **Browser Issues**
1. **Clear Browser Cache**: Ctrl+Shift+Delete
2. **Disable Extensions**: Try incognito/private mode
3. **Check JavaScript**: Ensure JavaScript is enabled
4. **Try Different Browser**: Test with Chrome, Firefox, Safari

### **Authentication Loops**

#### **Clear Auth Data**
```bash
# Clear browser data for cloudtolocalllm.online
# In browser: Settings → Privacy → Clear browsing data

# Or manually clear localStorage:
# F12 → Console → localStorage.clear()
```

#### **Check Auth0 Status**
1. Visit [status.auth0.com](https://status.auth0.com)
2. Verify no ongoing incidents
3. Try authentication in incognito mode

---

## 🔐 **Authentication Issues**

### **Login Fails Repeatedly**

#### **Desktop Application**
```bash
# Clear stored authentication
rm -rf ~/.local/share/cloudtolocalllm/auth

# Reset secure storage
rm -rf ~/.local/share/cloudtolocalllm/secure_storage

# Restart application
cloudtolocalllm
```

#### **Web Interface**
1. Clear all cookies for `*.cloudtolocalllm.online`
2. Clear localStorage and sessionStorage
3. Disable ad blockers temporarily
4. Try different network (mobile hotspot)

### **Token Validation Errors**

#### **Symptoms**
- "Invalid token" messages
- Automatic logouts
- API authentication failures

#### **Solutions**
1. **Check System Time**: Ensure system clock is accurate
   ```bash
   # Sync system time
   sudo ntpdate -s time.nist.gov
   # or
   sudo systemctl restart systemd-timesyncd
   ```

2. **Clear Token Cache**:
   - Desktop: Settings → Account → "Sign Out" → "Clear Cache"
   - Web: Clear browser data

---

## 📱 **Application Issues**

### **Application Won't Start**

#### **Check Dependencies**
```bash
# Verify Flutter runtime dependencies
ldd $(which cloudtolocalllm)

# Check for missing libraries
flutter doctor

# Install missing dependencies (Ubuntu/Debian)
sudo apt install libc6 libstdc++6 libgcc-s1
```

#### **Permission Issues**
```bash
# Check executable permissions
ls -la $(which cloudtolocalllm)

# Fix permissions if needed
chmod +x /usr/bin/cloudtolocalllm

# Check home directory permissions
ls -la ~/.local/share/cloudtolocalllm/
```

### **Application Crashes**

#### **Get Crash Information**
```bash
# Run with verbose logging
cloudtolocalllm --verbose

# Check system logs
journalctl --user -u cloudtolocalllm

# Check application logs
tail -f ~/.local/share/cloudtolocalllm/logs/app.log
```

#### **Common Crash Causes**
1. **Insufficient Memory**: Close other applications
2. **Corrupted Config**: Reset to defaults in Settings
3. **Plugin Conflicts**: Disable system tray temporarily
4. **Graphics Issues**: Update graphics drivers

---

## 🔧 **Performance Issues**

### **High CPU Usage**

#### **Identify Cause**
```bash
# Monitor CloudToLocalLLM processes
top -p $(pgrep cloudtolocalllm)

# Check for runaway processes
ps aux | grep cloudtolocalllm
```

#### **Solutions**
1. **Reduce Polling Frequency**: Settings → Advanced → "Status Check Interval"
2. **Disable Animations**: Settings → Appearance → "Reduce Motion"
3. **Close Unused Connections**: Disconnect from cloud proxy if not needed

### **High Memory Usage**

#### **Memory Optimization**
1. **Clear Chat History**: Settings → Chat → "Clear All Conversations"
2. **Reduce Cache Size**: Settings → Advanced → "Cache Limit"
3. **Restart Application**: Close and reopen to clear memory leaks

---

## 🆘 **Getting Additional Help**

### **Diagnostic Information**
When reporting issues, include:

```bash
# System information
uname -a
flutter --version

# Application version
cloudtolocalllm --version

# Connection status
cloudtolocalllm --test-connections

# Recent logs
tail -n 50 ~/.local/share/cloudtolocalllm/logs/app.log
```

### **Support Channels**
- **GitHub Issues**: [Report bugs](https://github.com/imrightguy/CloudToLocalLLM/issues)
- **GitHub Discussions**: [Community support](https://github.com/imrightguy/CloudToLocalLLM/discussions)
- **Documentation**: [Complete guides](https://github.com/imrightguy/CloudToLocalLLM/tree/main/docs)

### **Before Reporting**
1. ✅ Check this troubleshooting guide
2. ✅ Search existing GitHub issues
3. ✅ Try basic solutions (restart, clear cache)
4. ✅ Gather diagnostic information
5. ✅ Use appropriate issue template

---

**Most issues can be resolved with the solutions above. For persistent problems, the community and maintainers are here to help!**
