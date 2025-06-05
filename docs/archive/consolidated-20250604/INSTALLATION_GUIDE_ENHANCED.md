# CloudToLocalLLM Enhanced System Tray Architecture - Installation Guide

## 📋 Overview

This guide provides comprehensive installation instructions for CloudToLocalLLM with the **Enhanced System Tray Architecture**. The enhanced architecture features independent operation, universal connection management, and improved reliability.

## 🎯 Installation Methods

### 1. 🚀 **AppImage (Recommended for Most Users)**

The AppImage provides a portable, self-contained installation that works on all Linux distributions.

#### **Download and Install**
```bash
# Download the latest AppImage
wget https://github.com/imrightguy/CloudToLocalLLM/releases/download/v3.0.0/CloudToLocalLLM-3.0.0-x86_64.AppImage

# Make executable
chmod +x CloudToLocalLLM-3.0.0-x86_64.AppImage

# Run the application
./CloudToLocalLLM-3.0.0-x86_64.AppImage
```

#### **Features Included**
- ✅ Complete Flutter application
- ✅ Enhanced tray daemon with connection broker
- ✅ Settings application for daemon configuration
- ✅ All required dependencies bundled
- ✅ No installation required - fully portable

#### **Optional: Desktop Integration**
```bash
# Create desktop entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/cloudtolocalllm.desktop << 'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Local LLM Management with Enhanced System Tray
Exec=/path/to/CloudToLocalLLM-3.0.0-x86_64.AppImage
Icon=cloudtolocalllm
Terminal=false
Type=Application
Categories=Development;Utility;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications
```

---

### 2. 📦 **Arch Linux (AUR Package)**

For Arch Linux users, install via the AUR for full system integration.

#### **Installation**
```bash
# Using yay (recommended)
yay -S cloudtolocalllm-desktop

# Using paru
paru -S cloudtolocalllm-desktop

# Manual installation
git clone https://aur.archlinux.org/cloudtolocalllm-desktop.git
cd cloudtolocalllm-desktop
makepkg -si
```

#### **Post-Installation Setup**
```bash
# Enable and start the tray daemon service
systemctl --user enable --now cloudtolocalllm-tray

# Launch the main application
cloudtolocalllm

# Configure connections (optional)
cloudtolocalllm-settings
```

#### **Features Included**
- ✅ System integration with desktop entry and icons
- ✅ Systemd user service for automatic tray daemon startup
- ✅ Command-line launchers for all components
- ✅ Automatic dependency management
- ✅ Update notifications via package manager

---

### 3. 📋 **DEB Package (Ubuntu/Debian)**

For Ubuntu and Debian-based distributions.

#### **Installation**
```bash
# Download the DEB package
wget https://github.com/imrightguy/CloudToLocalLLM/releases/download/v3.0.0/cloudtolocalllm_3.0.0_amd64.deb

# Install the package
sudo dpkg -i cloudtolocalllm_3.0.0_amd64.deb

# Fix dependencies if needed
sudo apt-get install -f
```

#### **Post-Installation Setup**
```bash
# Enable and start the tray daemon service
systemctl --user enable --now cloudtolocalllm-tray

# Launch the main application
cloudtolocalllm

# Configure connections (optional)
cloudtolocalllm-settings
```

---

### 4. 🔧 **Manual Build from Source**

For developers or users who want to build from source.

#### **Prerequisites**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install flutter git python3 python3-pip python3-venv build-essential

# Arch Linux
sudo pacman -S flutter git python python-pip base-devel

# Fedora
sudo dnf install flutter git python3 python3-pip python3-virtualenv gcc gcc-c++
```

#### **Build Process**
```bash
# Clone the repository
git clone https://github.com/imrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM

# Configure Flutter
flutter config --enable-linux-desktop
flutter pub get

# Build the enhanced tray daemon
cd tray_daemon
./start_enhanced_daemon.sh setup
cd ..

# Build the Flutter application
flutter build linux --release

# Build the enhanced tray daemon executables
./scripts/build/build_tray_daemon.sh
```

#### **Installation**
```bash
# Install to /opt (requires sudo)
sudo mkdir -p /opt/cloudtolocalllm
sudo cp -r build/linux/x64/release/bundle/* /opt/cloudtolocalllm/
sudo cp -r dist/tray_daemon /opt/cloudtolocalllm/

# Create launcher scripts
sudo tee /usr/local/bin/cloudtolocalllm << 'EOF'
#!/bin/bash
cd /opt/cloudtolocalllm
exec ./cloudtolocalllm "$@"
EOF
sudo chmod +x /usr/local/bin/cloudtolocalllm

# Create tray daemon launcher
sudo tee /usr/local/bin/cloudtolocalllm-tray << 'EOF'
#!/bin/bash
cd /opt/cloudtolocalllm/tray_daemon
exec ./cloudtolocalllm-enhanced-tray "$@"
EOF
sudo chmod +x /usr/local/bin/cloudtolocalllm-tray
```

---

## ⚙️ **Configuration**

### **Enhanced Tray Daemon Setup**

#### **1. Start the Daemon**
```bash
# Automatic startup (systemd)
systemctl --user enable --now cloudtolocalllm-tray

# Manual startup
cloudtolocalllm-tray

# Debug mode
cloudtolocalllm-tray --debug
```

#### **2. Configure Connections**
```bash
# Launch settings GUI
cloudtolocalllm-settings

# Or edit configuration file directly
nano ~/.cloudtolocalllm/connection_config.json
```

#### **3. Test Connections**
```bash
# Test local Ollama
curl http://localhost:11434/api/version

# Check daemon status
systemctl --user status cloudtolocalllm-tray

# View daemon logs
journalctl --user -u cloudtolocalllm-tray -f
```

### **Connection Configuration**

#### **Local Ollama Setup**
```bash
# Install Ollama (if not already installed)
# Ubuntu/Debian
curl -fsSL https://ollama.ai/install.sh | sh

# Arch Linux
sudo pacman -S ollama

# Start Ollama service
systemctl --user enable --now ollama

# Pull a model
ollama pull llama2
```

#### **Cloud Proxy Setup**
1. **Authenticate**: Log in to your CloudToLocalLLM account in the main application
2. **Token Management**: The enhanced daemon will automatically receive and manage your authentication token
3. **Automatic Failover**: The system will automatically switch between local and cloud connections

---

## 🔍 **Verification**

### **Check Installation**
```bash
# Verify main application
cloudtolocalllm --version

# Verify tray daemon
cloudtolocalllm-tray --version

# Verify settings app
cloudtolocalllm-settings --help

# Check systemd service
systemctl --user status cloudtolocalllm-tray
```

### **Test System Tray**
1. **Start Daemon**: `cloudtolocalllm-tray`
2. **Check Tray Icon**: Look for CloudToLocalLLM icon in system tray
3. **Right-click Menu**: Verify context menu appears with options
4. **Launch Main App**: Click "Launch CloudToLocalLLM" from tray menu

### **Test Connection Management**
1. **Open Settings**: `cloudtolocalllm-settings`
2. **Test Local Ollama**: Click "Test Connections" button
3. **Check Status**: Verify connection status in the Status tab
4. **Launch Main App**: Start the main application and verify it connects through the daemon

---

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Daemon Won't Start**
```bash
# Check Python dependencies
pip install -r ~/.cloudtolocalllm/requirements.txt

# Check Python version
python3 --version  # Should be 3.8+

# Start in debug mode
cloudtolocalllm-tray --debug
```

#### **System Tray Not Visible**
```bash
# Check if system tray is supported
echo $XDG_CURRENT_DESKTOP

# Install system tray support (Ubuntu/Debian)
sudo apt install libayatana-appindicator3-1

# Restart the daemon
systemctl --user restart cloudtolocalllm-tray
```

#### **Connection Issues**
```bash
# Check Ollama status
systemctl --user status ollama

# Test Ollama directly
curl http://localhost:11434/api/version

# Check daemon logs
journalctl --user -u cloudtolocalllm-tray -f

# Reset configuration
rm ~/.cloudtolocalllm/connection_config.json
cloudtolocalllm-settings
```

### **Log Files**
- **Daemon Logs**: `~/.cloudtolocalllm/tray.log`
- **Systemd Logs**: `journalctl --user -u cloudtolocalllm-tray`
- **Flutter Logs**: Console output when running the main application

### **Getting Help**
- **Documentation**: [Enhanced Architecture Guide](ENHANCED_ARCHITECTURE.md)
- **GitHub Issues**: [Report bugs and request features](https://github.com/imrightguy/CloudToLocalLLM/issues)
- **Community**: Join our community discussions for support and tips

---

## 🎉 **Next Steps**

After successful installation:

1. **🚀 Launch the Application**: Start CloudToLocalLLM from your applications menu or command line
2. **🔐 Authenticate**: Log in to your CloudToLocalLLM account for cloud features
3. **🦙 Set Up Ollama**: Install and configure Ollama for local LLM access
4. **⚙️ Configure Settings**: Use the settings app to customize connection preferences
5. **💬 Start Chatting**: Begin using local and cloud LLMs through the unified interface

The Enhanced System Tray Architecture provides the most reliable and feature-rich CloudToLocalLLM experience yet!

---

*For technical details about the architecture, see [Enhanced Architecture Documentation](ENHANCED_ARCHITECTURE.md)*
