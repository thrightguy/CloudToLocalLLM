# CloudToLocalLLM Documentation

Welcome to the CloudToLocalLLM documentation! This directory contains comprehensive guides for users, developers, and system administrators.

## 📚 Documentation Structure

### 🚀 User Documentation
- **[User Guide](USER_DOCUMENTATION/USER_GUIDE.md)** - Complete user manual
- **[Installation Guide](USER_DOCUMENTATION/INSTALLATION_GUIDE.md)** - Step-by-step installation
- **[First Time Setup](USER_DOCUMENTATION/FIRST_TIME_SETUP.md)** - Getting started guide
- **[Features Guide](USER_DOCUMENTATION/FEATURES_GUIDE.md)** - Feature overview
- **[Troubleshooting Guide](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)** - Common issues and solutions

### 🏗️ Architecture Documentation
- **[System Architecture](ARCHITECTURE/SYSTEM_ARCHITECTURE.md)** - Overall system design
- **[Streaming Proxy Architecture](ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)** - Multi-tenant proxy system
- **[Multi-Container Architecture](ARCHITECTURE/MULTI_CONTAINER_ARCHITECTURE.md)** - Container orchestration
- **[Enhanced System Tray](ARCHITECTURE/ENHANCED_SYSTEM_TRAY_ARCHITECTURE.md)** - Desktop integration
- **[Unified Flutter Web](ARCHITECTURE/UNIFIED_FLUTTER_WEB.md)** - Web platform architecture

### 🔗 Tunnel Integration
- **[Zrok Tunnel System](ARCHITECTURE/TUNNEL_ARCHITECTURE.md)** - Secure tunnel management with zrok
  - Automatic fallback hierarchy
  - Platform abstraction patterns
  - Auth0 JWT validation integration
  - Cross-platform compatibility
  - Troubleshooting and support

### 🚀 Deployment Documentation
- **[Deployment Workflow](DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)** - Complete deployment process
- **[Environment Separation](DEPLOYMENT/ENVIRONMENT_SEPARATION_GUIDE.md)** - Environment management
- **[AUR Integration](DEPLOYMENT/AUR_INTEGRATION_CHANGES.md)** - Arch Linux packaging
- **[Flutter SDK Management](DEPLOYMENT/FLUTTER_SDK_MANAGEMENT.md)** - SDK version management
- **[Versioning Strategy](DEPLOYMENT/VERSIONING_STRATEGY.md)** - Version management

### 👨‍💻 Development Documentation
- **[Developer Onboarding](DEVELOPMENT/DEVELOPER_ONBOARDING.md)** - Getting started with development
- **[API Documentation](DEVELOPMENT/API_DOCUMENTATION.md)** - API reference

### 🔧 Operations Documentation
- **[Infrastructure Guide](OPERATIONS/INFRASTRUCTURE_GUIDE.md)** - Infrastructure management
- **[Self-Hosting Guide](OPERATIONS/SELF_HOSTING.md)** - Self-hosting instructions

### 📋 Release Documentation
- **[Release Notes](RELEASE/RELEASE_NOTES.md)** - Version history and changes

### ⚖️ Legal Documentation
- **[Privacy Policy](LEGAL/PRIVACY.md)** - Privacy information
- **[Terms of Service](LEGAL/TERMS.md)** - Terms and conditions

## 🔥 What's New

### Zrok Tunnel Integration
CloudToLocalLLM features a robust zrok-based tunnel system:
- **Automatic Fallback**: Local Ollama → Cloud proxy → Zrok tunnel → Local Ollama
- **Secure Access**: Auth0 JWT validation for all tunnel access
- **Platform Abstraction**: Desktop-only with proper stub implementations
- **Zero Configuration**: Works with free zrok accounts
- **Production Ready**: Full tunnel lifecycle management

## 📖 Quick Navigation

### For End Users
1. Start with [Installation Guide](USER_DOCUMENTATION/INSTALLATION_GUIDE.md)
2. Follow [First Time Setup](USER_DOCUMENTATION/FIRST_TIME_SETUP.md)
3. Configure tunnel settings in the application
4. Refer to [User Guide](USER_DOCUMENTATION/USER_GUIDE.md) for daily usage
5. Check [Troubleshooting](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md) if issues arise

### For Developers
1. Review [System Architecture](ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
2. Understand [Streaming Proxy Architecture](ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)
3. Learn about tunnel management and platform abstraction patterns
4. Follow [Developer Onboarding](DEVELOPMENT/DEVELOPER_ONBOARDING.md)
5. Reference [API Documentation](DEVELOPMENT/API_DOCUMENTATION.md)

### For System Administrators
1. Study [Infrastructure Guide](OPERATIONS/INFRASTRUCTURE_GUIDE.md)
2. Review [Deployment Workflow](DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)
3. Configure [Environment Separation](DEPLOYMENT/ENVIRONMENT_SEPARATION_GUIDE.md)
4. Set up monitoring and maintenance procedures

## 🆘 Getting Help

### Common Issues
- **Installation Problems**: Check [Installation Guide](USER_DOCUMENTATION/INSTALLATION_GUIDE.md)
- **Connection Issues**: See [Troubleshooting Guide](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)
- **Tunnel Problems**: Review connection fallback hierarchy and zrok configuration
- **Performance Issues**: Monitor connection status and tunnel health

### Support Channels
- **GitHub Issues**: [Report bugs and request features](https://github.com/imrightguy/CloudToLocalLLM/issues)
- **Documentation**: Search this documentation for answers
- **Community**: Participate in repository discussions

### Contributing to Documentation
We welcome contributions to improve documentation:
1. **Corrections**: Fix typos, errors, or outdated information
2. **Additions**: Add missing information or new guides
3. **Examples**: Provide real-world usage examples
4. **Translations**: Help translate documentation

## 📊 Documentation Status

| Section | Status | Last Updated |
|---------|--------|--------------|
| User Documentation | ✅ Complete | 2024-06-28 |
| Architecture | ✅ Complete | 2024-06-28 |
| **Zrok Integration** | ✅ **Complete** | 2024-06-29 |
| Deployment | ✅ Complete | 2024-06-28 |
| Development | ✅ Complete | 2024-06-28 |
| Operations | ✅ Complete | 2024-06-28 |

## 🔄 Recent Updates

### 2024-06-29: Zrok-Only Tunnel System
- Completed transition from ngrok to zrok tunnel management
- Implemented production-ready zrok service with platform abstraction
- Enhanced fallback hierarchy: Local Ollama → Cloud proxy → Zrok tunnel → Local Ollama
- Integrated Auth0 JWT validation for secure tunnel access
- Added comprehensive error handling and logging with 🌐 [ZrokService] prefix

---

*For the most current information, always refer to the official repository and documentation.*
