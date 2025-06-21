# CloudToLocalLLM Installation Guide

## 📋 Overview

This guide covers installation of CloudToLocalLLM v3.6.2+ with the unified Flutter-native architecture. The application features integrated system tray functionality and requires no external daemon processes.

**Supported Platforms:**
- **Linux**: AUR (Arch), Static Package, Manual Build
- **Windows**: Planned for future releases
- **Web**: Access via [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)

---

## 🐧 **Linux Installation**

### **Method 1: AUR Package (Recommended for Arch Linux)**

The AUR package provides full system integration with automatic updates.

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

#### **Post-Installation**
```bash
# Launch the application
cloudtolocalllm

# The application includes integrated system tray functionality
# No separate daemon setup required
```

#### **Features Included**
- ✅ Unified Flutter application with integrated system tray
- ✅ Desktop integration with menu entry and icons
- ✅ Command-line launcher
- ✅ Automatic dependency management
- ✅ Update notifications via package manager

### **Method 2: Static Package (All Linux Distributions)**

Download the pre-built static package for any Linux distribution.

#### **Installation**
```bash
# Download the latest package
wget https://cloudtolocalllm.online/download/cloudtolocalllm-3.6.2-x86_64.tar.gz

# Verify checksum (optional but recommended)
wget https://cloudtolocalllm.online/download/cloudtolocalllm-3.6.2-x86_64.tar.gz.sha256
sha256sum -c cloudtolocalllm-3.6.2-x86_64.tar.gz.sha256

# Extract the package
tar -xzf cloudtolocalllm-3.6.2-x86_64.tar.gz

# Move to installation directory
sudo mv cloudtolocalllm-3.6.2-x86_64 /opt/cloudtolocalllm

# Create symlink for easy access
sudo ln -s /opt/cloudtolocalllm/bin/cloudtolocalllm /usr/local/bin/cloudtolocalllm
```

#### **Desktop Integration (Optional)**
```bash
# Create desktop entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/cloudtolocalllm.desktop << 'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Local LLM Management with Cloud Interface
Exec=/opt/cloudtolocalllm/bin/cloudtolocalllm
Icon=cloudtolocalllm
Terminal=false
Type=Application
Categories=Development;Utility;Network;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications
```

### **Method 3: Manual Build from Source**

For developers or users who want to build from source.

#### **Prerequisites**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install flutter git build-essential

# Arch Linux
sudo pacman -S flutter git base-devel

# Fedora
sudo dnf install flutter git gcc gcc-c++
```

#### **Build Process**
```bash
# Clone the repository
git clone https://github.com/imrightguy/CloudToLocalLLM.git
cd CloudToLocalLLM

# Configure Flutter
flutter config --enable-linux-desktop
flutter pub get

# Build the unified Flutter application
flutter build linux --release

# The built application will be in build/linux/x64/release/bundle/
```

---

## 🌐 **Web Access**

CloudToLocalLLM is available as a web application for immediate use without installation.

### **Access the Web App**
1. **Visit**: [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)
2. **Authenticate**: Log in with Auth0 (Google, GitHub, or email)
3. **Connect**: Set up tunnel to your local Ollama instance
4. **Chat**: Start using your local LLMs through the web interface

### **Web Features**
- ✅ Full chat interface with streaming responses
- ✅ Model selection and management
- ✅ Real-time connection status monitoring
- ✅ Secure tunnel to local Ollama instance
- ✅ Cross-platform compatibility (any modern browser)

---

## ⚙️ **Configuration**

### **Local Ollama Setup**

CloudToLocalLLM requires Ollama for local LLM functionality.

#### **Install Ollama**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
systemctl --user enable --now ollama

# Pull a model (example)
ollama pull llama3.2

# Test connection
curl http://localhost:11434/api/version
```

### **System Tray Configuration**

The unified Flutter application includes integrated system tray functionality.

#### **System Tray Features**
- **Real-time Status**: Visual indicators for connection status
- **Context Menu**: Show/Hide, Settings, Connection Status, Quit
- **Platform Integration**: Native behavior on Linux, Windows, macOS
- **Auto-start**: Minimize to tray on startup (configurable)

#### **Desktop Environment Requirements**
```bash
# For GNOME users (if tray not visible)
sudo apt install gnome-shell-extension-appindicator

# For KDE users (usually works out of the box)
# No additional setup required

# For other desktop environments
# Ensure system tray support is enabled
```

---

## 🔍 **Verification**

### **Check Installation**
```bash
# Verify application
cloudtolocalllm --version
# Expected output: CloudToLocalLLM v3.4.0+001

# Test system tray functionality
cloudtolocalllm
# Application should start with system tray icon
```

### **Test Local Connection**
1. **Start Ollama**: Ensure Ollama is running (`systemctl --user status ollama`)
2. **Launch CloudToLocalLLM**: Start the application
3. **Check Connection**: Look for green connection indicator in system tray
4. **Test Chat**: Open the application and try sending a message

### **Test Web Connection** (Optional)
1. **Visit Web App**: Go to [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)
2. **Authenticate**: Log in with your preferred method
3. **Configure Tunnel**: Set up connection to your local Ollama
4. **Test Chat**: Send a message through the web interface

---

## 🐛 **Troubleshooting**

### **Common Issues**

#### **Application Won't Start**
```bash
# Check Flutter dependencies
flutter doctor

# Check for missing libraries
ldd /opt/cloudtolocalllm/bin/cloudtolocalllm

# Run with debug output
cloudtolocalllm --verbose
```

#### **System Tray Not Visible**
```bash
# Install system tray support (Ubuntu/Debian)
sudo apt install libayatana-appindicator3-1

# For GNOME
sudo apt install gnome-shell-extension-appindicator

# Restart the application
cloudtolocalllm
```

#### **Connection Issues**
```bash
# Check Ollama status
systemctl --user status ollama

# Test Ollama directly
curl http://localhost:11434/api/version

# Check application logs
cloudtolocalllm --verbose
```

### **Log Files**
- **Application Logs**: Console output when running with `--verbose`
- **System Logs**: `journalctl --user -f` (if using systemd)
- **Ollama Logs**: `journalctl --user -u ollama -f`

---

## 🎉 **Next Steps**

After successful installation:

1. **🚀 Launch CloudToLocalLLM**: Start the unified application
2. **🦙 Verify Ollama**: Ensure local LLM access is working
3. **🌐 Try Web Access**: Test the web interface (optional)
4. **⚙️ Configure Settings**: Customize preferences and connections
5. **💬 Start Chatting**: Begin using your local LLMs

For detailed usage instructions, see the [User Guide](USER_GUIDE.md).

---

**The unified Flutter-native architecture provides a streamlined, reliable CloudToLocalLLM experience with integrated system tray functionality and no external dependencies.**
