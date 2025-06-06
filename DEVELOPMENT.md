# CloudToLocalLLM Developer Documentation

This document contains comprehensive technical information for developers working on CloudToLocalLLM.

## 🏗️ 3-App Modular Flutter-Only Architecture

CloudToLocalLLM features a **unified Flutter-only architecture** with three independent applications for optimal modularity and system integration:

### Directory Structure
```
apps/
├── chat/                     # Main ChatGPT-like interface
│   ├── lib/                  # Flutter app source code
│   ├── pubspec.yaml         # App-specific dependencies
│   └── assets/              # Chat app assets
├── tray/                     # System tray service
│   ├── lib/                  # Flutter tray implementation
│   ├── pubspec.yaml         # Tray dependencies (tray_manager)
│   └── assets/              # Monochrome tray icons
├── settings/                 # Connection management & Ollama testing
│   ├── lib/                  # Flutter settings UI
│   ├── pubspec.yaml         # Settings dependencies
│   └── assets/              # Settings app assets
└── shared/                   # Shared library
    ├── lib/                  # Common models and utilities
    └── pubspec.yaml         # Shared dependencies
```

### **MANDATORY: Context7 Documentation Requirement**

**Before implementing any external libraries, frameworks, or APIs:**
1. **ALWAYS** use `resolve-library-id_context7` to find the correct library ID
2. **ALWAYS** use `get-library-docs_context7` to get current documentation
3. This ensures proper usage, correct parameters, and current best practices
4. **NO EXCEPTIONS** - this prevents implementation errors and deprecated usage

### Key Benefits
- **Separation of Concerns**: App-specific vs shared functionality
- **Code Reusability**: Shared models and services across applications
- **Independent Development**: Teams can work on different apps simultaneously
- **Better Maintainability**: Easier to locate and modify specific functionality

### Import Conventions
```dart
// Local imports (within same app)
import '../models/conversation.dart';
import '../services/chat_service.dart';

// Shared library imports
import 'package:cloudtolocalllm_shared/cloudtolocalllm_shared.dart';
```

## 🔗 TCP IPC Communication Protocol

### Overview
The three applications communicate via TCP socket JSON protocol:

- **Tray Service**: Runs IPC server on auto-assigned port
- **Chat App**: Connects as IPC client to tray service
- **Settings App**: Connects as IPC client to tray service

### Protocol Specification

#### Port Discovery
- Tray service writes port number to `~/.cloudtolocalllm/tray_port`
- Client apps read this file to discover connection port
- Automatic reconnection with exponential backoff

#### Message Format
```json
{
  "command": "COMMAND_NAME",
  "type": "message_type",
  "data": { /* command-specific data */ }
}
```

#### Supported Commands

**From Tray Service to Apps:**
- `SHOW` - Show main window
- `HIDE` - Hide main window  
- `SETTINGS` - Open settings
- `QUIT` - Quit application

**From Apps to Tray Service:**
- `UPDATE_AUTH_STATUS` - Update authentication state
- `UPDATE_CONNECTION_STATE` - Update connection status (idle/connected/error)
- `PING` - Heartbeat message

#### Connection Management
- Heartbeat every 30 seconds
- Automatic reconnection on connection loss
- Maximum 3-5 reconnection attempts
- Graceful degradation when tray service unavailable

## 🖥️ System Tray Implementation

### Flutter-Only Architecture
- Uses `tray_manager` package for cross-platform system tray
- Monochrome icons for Linux desktop environment compatibility
- Authentication-aware menu updates
- Independent operation from main applications

### Icon States
- **Idle**: Default monochrome icon
- **Connected**: Connected state indicator
- **Error**: Error state indicator

### Menu Structure
```
├── Show Window
├── Hide Window
├── ─────────────
├── Settings
├── [Authentication-dependent items]
├── ─────────────
└── Quit
```

## 🔧 Build System

### Build Script: `scripts/build_all.sh`

Builds all three applications in dependency order:
1. Shared library
2. Chat application
3. Tray service
4. Settings application

#### Usage
```bash
# Full build (release)
./scripts/build_all.sh

# Debug build
./scripts/build_all.sh debug

# Verbose output
./scripts/build_all.sh release true

# Skip tests
./scripts/build_all.sh release false --skip-tests
```

#### Build Constraints
- Total package size: ~125MB maximum
- AUR package compatibility maintained
- SourceForge distribution method
- AppImage, DEB, and AUR package formats

### Validation Script: `scripts/validate_flutter_architecture.sh`

Comprehensive validation of the Flutter-only architecture:
- App structure validation
- Python component removal verification
- IPC implementation checks
- System tray validation
- Build system verification
- Context7 requirement validation

## 🏛️ Multi-Container Architecture

### Container Structure
```
Internet → Nginx Proxy → Static Site (docs.cloudtolocalllm.online)
                      → Flutter App (app.cloudtolocalllm.online)
                      → API Backend (WebSocket + REST)
```

### Key Features
- **Independent Deployments**: Update components separately
- **Zero-Downtime Updates**: Rolling updates with health checks
- **Scalability**: Individual container scaling
- **Security**: Container isolation and non-root execution

### Deployment Commands
```bash
# Full deployment with SSL setup
./scripts/deploy/deploy-multi-container.sh --build --ssl-setup

# Deploy specific services
./scripts/deploy/deploy-multi-container.sh flutter-app
./scripts/deploy/update-service.sh static-site --no-downtime
```

## 📋 Versioning Strategy

**Format**: `MAJOR.MINOR.PATCH+BUILD`

- **Major (x.0.0)**: Creates GitHub releases - significant changes
- **Minor (x.y.0)**: No GitHub release - feature additions
- **Patch (x.y.z)**: No GitHub release - bug fixes
- **Build (x.y.z+nnn)**: No GitHub release - incremental builds

**Examples**: `3.1.1+001` → `3.1.1+002` → `3.1.2+001` → `4.0.0+001`

## 🔒 Security Requirements

### Container Security
- All containers run as non-root users (UID/GID 1000)
- No privilege escalation in production
- Container isolation maintained
- Secure volume mounting

### Authentication
- Auth0 integration with PKCE support
- JWT token management
- Secure session handling
- Multi-tenant isolation

## 🧪 Testing & Validation

### Architecture Validation
Run the validation script to ensure proper implementation:
```bash
./scripts/validate_flutter_architecture.sh
```

Expected: 48/48 checks pass

### Build Testing
```bash
# Test individual app builds
cd apps/chat && flutter build linux --release
cd apps/tray && flutter build linux --release
cd apps/settings && flutter build linux --release

# Test full build pipeline
./scripts/build_all.sh release false --skip-tests
```

### IPC Testing
1. Start tray service
2. Verify port file creation
3. Test client connections
4. Validate command handling

## 📁 Project Structure

### Core Directories
- `apps/` - Flutter applications (chat, tray, settings, shared)
- `api-backend/` - Node.js backend server
- `web/` - Web-specific Flutter assets
- `scripts/` - Build, deployment, and utility scripts
- `docs/` - Comprehensive project documentation
- `packaging/` - Platform-specific packaging configurations

### Development Tools
- `.vscode/` - VS Code workspace configuration
- `scripts/validate_flutter_architecture.sh` - Architecture validation
- `scripts/build_all.sh` - Unified build system

## 🚀 Development Workflow

1. **Setup**: Install Flutter SDK and dependencies
2. **Context7**: Use documentation tools for external libraries
3. **Development**: Work on individual apps with shared library
4. **Testing**: Run validation scripts and build tests
5. **Build**: Use unified build system for all platforms
6. **Deployment**: Follow multi-container deployment process

## 📚 Additional Documentation

For detailed information on specific topics:
- [System Architecture](docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
- [Deployment Workflow](docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Self-Hosting Guide](docs/OPERATIONS/SELF_HOSTING.md)
- [Features Guide](docs/USER_DOCUMENTATION/FEATURES_GUIDE.md)
