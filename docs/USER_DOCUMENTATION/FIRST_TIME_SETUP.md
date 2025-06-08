# CloudToLocalLLM First Time Setup Guide

## 🚀 Welcome to CloudToLocalLLM!

This guide will walk you through setting up CloudToLocalLLM v3.4.0+ for the first time. The unified Flutter-native architecture makes setup simple and straightforward.

**What You'll Accomplish:**
- ✅ Complete initial application setup
- ✅ Configure local Ollama connection
- ✅ Set up system tray functionality
- ✅ Test your first chat session
- ✅ Optional: Configure web access

---

## 📋 **Prerequisites Check**

Before starting, ensure you have:

### **Required**
- [ ] **CloudToLocalLLM installed** - See [Installation Guide](INSTALLATION_GUIDE.md)
- [ ] **Ollama installed and running** - Local LLM backend
- [ ] **Internet connection** - For model downloads and optional web features

### **Optional**
- [ ] **Auth0 account** - For web interface access
- [ ] **Modern web browser** - For web interface testing

---

## 🔧 **Step 1: Initial Application Launch**

### **Start CloudToLocalLLM**
```bash
# Launch the application
cloudtolocalllm

# Or from desktop menu
# Applications → Development → CloudToLocalLLM
```

### **First Launch Behavior**
- **System Tray Icon**: Application icon appears in system tray
- **Main Window**: Application window opens automatically
- **Connection Status**: Initially shows "Disconnected" (red indicator)

### **System Tray Verification**
1. **Locate Tray Icon**: Look for CloudToLocalLLM icon in system tray
2. **Right-click Menu**: Verify context menu appears with options:
   - Show CloudToLocalLLM
   - Hide to Tray
   - Connection Status
   - Settings
   - Quit

---

## 🦙 **Step 2: Ollama Setup and Configuration**

### **Install Ollama (if not already installed)**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
systemctl --user enable --now ollama

# Verify Ollama is running
systemctl --user status ollama
```

### **Download Your First Model**
```bash
# Download a lightweight model for testing
ollama pull llama3.2:1b

# Or download a more capable model (larger download)
ollama pull llama3.2:3b

# List available models
ollama list
```

### **Test Ollama Connection**
```bash
# Test Ollama API directly
curl http://localhost:11434/api/version

# Expected response:
# {"version":"0.x.x"}

# Test model availability
curl http://localhost:11434/api/tags
```

---

## 🔗 **Step 3: Configure CloudToLocalLLM Connection**

### **Automatic Connection Detection**
CloudToLocalLLM automatically detects local Ollama instances:

1. **Launch CloudToLocalLLM** (if not already running)
2. **Check System Tray**: Icon should change to green (connected)
3. **Connection Status**: Should show "Connected to Local Ollama"

### **Manual Connection Configuration** (if needed)
If automatic detection fails:

1. **Open Settings**: Right-click tray icon → Settings
2. **Navigate to Connections**: Select "Local Ollama" tab
3. **Configure Connection**:
   - **Host**: `localhost`
   - **Port**: `11434`
   - **Protocol**: `HTTP`
4. **Test Connection**: Click "Test Connection" button
5. **Save Settings**: Click "Save" if test succeeds

### **Verify Connection Status**
- **System Tray**: Green icon indicates successful connection
- **Tooltip**: Hover over tray icon to see connection details
- **Settings Panel**: Connection status shows "Connected"

---

## 💬 **Step 4: Your First Chat Session**

### **Start a New Conversation**
1. **Open Main Window**: Click tray icon or right-click → "Show CloudToLocalLLM"
2. **Select Model**: Choose from available models in dropdown
3. **Start Chatting**: Type your first message and press Enter

### **Test Messages**
Try these example prompts:

```
Hello! Can you introduce yourself?
```

```
What's the weather like today? (Note: I don't have internet access)
```

```
Write a short poem about local AI
```

### **Expected Behavior**
- **Streaming Response**: Text appears progressively as the model generates
- **Model Information**: Model name displayed in chat header
- **Response Time**: Varies based on model size and hardware
- **System Tray**: May show activity indicator during generation

---

## ⚙️ **Step 5: Customize Settings**

### **Access Settings**
- **From Tray**: Right-click tray icon → Settings
- **From App**: Main menu → Settings
- **Keyboard**: `Ctrl+,` (when main window is focused)

### **Key Settings to Configure**

#### **General Settings**
- **Theme**: Light, Dark, or System
- **Startup Behavior**: Start with system, minimize to tray
- **Notifications**: Enable/disable system notifications

#### **Connection Settings**
- **Default Model**: Set preferred model for new conversations
- **Connection Timeout**: Adjust for slower systems
- **Auto-reconnect**: Enable automatic reconnection on failure

#### **System Tray Settings**
- **Show Tray Icon**: Enable/disable system tray functionality
- **Minimize to Tray**: Hide window instead of closing
- **Tray Notifications**: Show connection status changes

#### **Advanced Settings**
- **Debug Logging**: Enable for troubleshooting
- **Performance Mode**: Optimize for low-resource systems
- **Update Checking**: Automatic update notifications

---

## 🌐 **Step 6: Optional Web Interface Setup**

### **Access Web Interface**
1. **Visit**: [app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)
2. **Authenticate**: Choose login method (Google, GitHub, Email)
3. **Grant Permissions**: Allow necessary permissions for Auth0

### **Configure Cloud Tunnel**
1. **Navigate to Settings**: In web interface
2. **Tunnel Configuration**: Set up connection to local instance
3. **Connection Details**:
   - **Local Host**: Your computer's local IP
   - **Port**: 11434 (Ollama default)
   - **Authentication**: Use provided tunnel key

### **Test Web Connection**
1. **Start Chat**: Create new conversation in web interface
2. **Select Model**: Choose from your local models
3. **Send Message**: Test that responses come from your local Ollama

---

## ✅ **Step 7: Verification Checklist**

### **Desktop Application**
- [ ] Application starts successfully
- [ ] System tray icon appears and is functional
- [ ] Connection to local Ollama established (green indicator)
- [ ] Chat interface responds to messages
- [ ] Settings can be accessed and modified
- [ ] Application minimizes to tray correctly

### **Local Ollama**
- [ ] Ollama service is running
- [ ] At least one model is downloaded
- [ ] API responds to direct curl requests
- [ ] Models appear in CloudToLocalLLM interface

### **Optional Web Interface**
- [ ] Web interface loads successfully
- [ ] Authentication completes without errors
- [ ] Tunnel connection established
- [ ] Chat works through web interface
- [ ] Responses come from local Ollama instance

---

## 🐛 **Common First-Time Issues**

### **System Tray Not Visible**
```bash
# Install tray support (Ubuntu/Debian)
sudo apt install libayatana-appindicator3-1

# For GNOME users
sudo apt install gnome-shell-extension-appindicator

# Restart application
cloudtolocalllm
```

### **Ollama Connection Failed**
```bash
# Check Ollama status
systemctl --user status ollama

# Restart Ollama if needed
systemctl --user restart ollama

# Verify port is open
netstat -ln | grep 11434
```

### **No Models Available**
```bash
# Download a model
ollama pull llama3.2:1b

# Verify model downloaded
ollama list

# Restart CloudToLocalLLM
cloudtolocalllm
```

### **Application Won't Start**
```bash
# Check for missing dependencies
ldd $(which cloudtolocalllm)

# Run with debug output
cloudtolocalllm --verbose

# Check system requirements
flutter doctor
```

---

## 🎉 **You're All Set!**

Congratulations! You've successfully set up CloudToLocalLLM. Here's what you can do next:

### **Explore Features**
- **Try Different Models**: Download and test various Ollama models
- **Customize Interface**: Explore themes and layout options
- **Web Access**: Use the web interface for remote access
- **Advanced Settings**: Fine-tune performance and behavior

### **Get Help**
- **Documentation**: Browse other guides in `docs/USER_DOCUMENTATION/`
- **Community**: Join discussions on GitHub
- **Issues**: Report bugs or request features on GitHub Issues

### **Stay Updated**
- **Check for Updates**: Enable automatic update notifications
- **Follow Releases**: Watch the GitHub repository for new versions
- **Read Changelogs**: Stay informed about new features and fixes

---

**Welcome to the CloudToLocalLLM community! Enjoy your local AI experience with cloud convenience.**
