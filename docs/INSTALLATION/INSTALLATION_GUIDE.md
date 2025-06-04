# CloudToLocalLLM Installation Guide

## 📋 Overview

This comprehensive guide covers installation of CloudToLocalLLM across all supported platforms with the Enhanced System Tray Architecture. Choose the installation method that best fits your environment.

**Supported Platforms:**
- **Linux**: AppImage, AUR (Arch), DEB (Ubuntu/Debian), Manual Build
- **Windows**: Installer, Manual Build
- **Self-Hosting**: VPS deployment for cloud features

---

## 🐧 **Linux Installation**

### **Method 1: AppImage (Recommended)**

The AppImage provides a portable, self-contained installation that works on all Linux distributions.

#### **Quick Installation**
```bash
# Download the latest AppImage
wget https://github.com/imrightguy/CloudToLocalLLM/releases/download/v3.1.3/CloudToLocalLLM-3.1.3-x86_64.AppImage

# Make executable
chmod +x CloudToLocalLLM-3.1.3-x86_64.AppImage

# Run the application
./CloudToLocalLLM-3.1.3-x86_64.AppImage
```

#### **Features Included**
- ✅ Complete Flutter application
- ✅ Enhanced tray daemon with connection broker
- ✅ Settings application for daemon configuration
- ✅ All required dependencies bundled
- ✅ No installation required - fully portable

#### **Desktop Integration (Optional)**
```bash
# Create desktop entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/cloudtolocalllm.desktop << 'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Local LLM Management with Enhanced System Tray
Exec=/path/to/CloudToLocalLLM-3.1.3-x86_64.AppImage
Icon=cloudtolocalllm
Terminal=false
Type=Application
Categories=Development;Utility;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications
```

### **Method 2: AUR Package (Arch Linux)**

For Arch Linux users, install via the AUR for full system integration.

#### **Installation**
```bash
# Using yay (recommended)
yay -S cloudtolocalllm

# Using paru
paru -S cloudtolocalllm

# Manual installation
git clone https://aur.archlinux.org/cloudtolocalllm.git
cd cloudtolocalllm
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

### **Method 3: DEB Package (Ubuntu/Debian)**

For Ubuntu and Debian-based distributions.

#### **Installation**
```bash
# Download the DEB package
wget https://github.com/imrightguy/CloudToLocalLLM/releases/download/v3.1.3/cloudtolocalllm_3.1.3_amd64.deb

# Install the package
sudo dpkg -i cloudtolocalllm_3.1.3_amd64.deb

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

### **Method 4: Manual Build from Source**

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

# Build the Flutter application
flutter build linux --release

# Build the enhanced tray daemon
cd tray_daemon
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..
```

---

## 🪟 **Windows Installation**

### **Method 1: Windows Installer (Recommended)**

The Windows installer provides automated setup with optional Docker and Ollama configuration.

#### **Installation Steps**

1. **Download the Installer**
   - Download from [Releases](https://github.com/imrightguy/CloudToLocalLLM/releases)
   - File: `CloudToLocalLLM-Windows-3.1.3-Setup.exe`

2. **Run the Installer**
   - Double-click the installer file
   - Click "Yes" if prompted by User Account Control

3. **Select Installation Type**
   - Current user only (no admin rights required)
   - All users (requires admin privileges)

4. **Choose Components**
   - ✅ Desktop Icon
   - ✅ Install Ollama Docker container
   - ✅ Start application at Windows startup
   - ✅ Enable GPU acceleration (NVIDIA only)

5. **Configure Ollama** (if selected)
   - Specify Ollama API port (default: 11434)
   - Choose custom data directory for models

6. **Complete Installation**
   - Click "Install" to begin
   - Launch application when complete

#### **Post-Installation**
- **CloudToLocalLLM Application**: Main executable and supporting files
- **Docker and Ollama**: Docker Desktop and Ollama container (if selected)
- **Registry Settings**: Configuration stored in Windows registry

### **Method 2: Manual Build (Windows)**

For developers building from source on Windows.

#### **Prerequisites**
- Windows 10/11
- Flutter SDK
- Git
- Python 3.8+
- Visual Studio Build Tools

#### **Build Process**
```powershell
# Clone the repository
git clone https://github.com/imrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM

# Configure Flutter
flutter config --enable-windows-desktop
flutter pub get

# Build the Flutter application
flutter build windows --release

# Build the tray daemon
cd tray_daemon
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
cd ..
```

---

## 🌐 **Self-Hosting Setup**

For deploying CloudToLocalLLM on your own VPS to enable cloud features.

### **Prerequisites**
- Linux VPS (Ubuntu 20.04/22.04 recommended)
- Minimum 2 CPU cores, 4GB RAM, 20GB disk
- Domain name with DNS control
- Static IP address

### **Quick Setup**
```bash
# Create dedicated user
curl -o setup_cloudllm_user.sh https://raw.githubusercontent.com/imrightguy/CloudToLocalLLM/main/scripts/setup_cloudllm_user.sh
chmod +x setup_cloudllm_user.sh
./setup_cloudllm_user.sh cloudllm your_public_ssh_key

# Switch to cloudllm user
su - cloudllm

# Clone repository
git clone https://github.com/imrightguy/CloudToLocalLLM.git /opt/cloudtolocalllm
cd /opt/cloudtolocalllm

# Run deployment script
./scripts/deploy_vps.sh
```

### **SSL Certificate Setup**
```bash
# Configure wildcard SSL certificate
./scripts/manual_staging_wildcard.sh yourdomain.com youremail@example.com

# Follow DNS challenge instructions
# Deploy TXT records as prompted
# Wait for certificate issuance
```

### **Start Services**
```bash
# Start all services
docker compose up -d

# Verify deployment
docker compose ps
curl -I https://yourdomain.com
```

**For detailed self-hosting instructions, see [SELF_HOSTING.md](../OPERATIONS/SELF_HOSTING.md)**

---

## ⚙️ **Configuration**

### **Enhanced Tray Daemon Setup**

#### **Start the Daemon**
```bash
# Automatic startup (systemd)
systemctl --user enable --now cloudtolocalllm-tray

# Manual startup
cloudtolocalllm-tray

# Debug mode
cloudtolocalllm-tray --debug
```

#### **Configure Connections**
```bash
# Launch settings GUI
cloudtolocalllm-settings

# Or edit configuration file directly
nano ~/.cloudtolocalllm/connection_config.json
```

### **Local Ollama Setup**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
systemctl --user enable --now ollama

# Pull a model
ollama pull llama2

# Test connection
curl http://localhost:11434/api/version
```

---

## 🔍 **Verification**

### **Check Installation**
```bash
# Verify main application
cloudtolocalllm --version

# Verify tray daemon
cloudtolocalllm-tray --version

# Check systemd service
systemctl --user status cloudtolocalllm-tray
```

### **Test System Tray**
1. Start daemon: `cloudtolocalllm-tray`
2. Check tray icon in system tray
3. Right-click for context menu
4. Launch main app from tray menu

### **Test Connections**
1. Open settings: `cloudtolocalllm-settings`
2. Test local Ollama connection
3. Verify connection status
4. Launch main app and test chat

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
```

### **Log Files**
- **Daemon Logs**: `~/.cloudtolocalllm/tray.log`
- **Systemd Logs**: `journalctl --user -u cloudtolocalllm-tray`
- **Flutter Logs**: Console output when running main application

---

## 🎉 **Next Steps**

After successful installation:

1. **🚀 Launch the Application**: Start CloudToLocalLLM
2. **🔐 Authenticate**: Log in for cloud features
3. **🦙 Set Up Ollama**: Configure local LLM access
4. **⚙️ Configure Settings**: Customize connection preferences
5. **💬 Start Chatting**: Begin using local and cloud LLMs

The Enhanced System Tray Architecture provides the most reliable CloudToLocalLLM experience yet!
