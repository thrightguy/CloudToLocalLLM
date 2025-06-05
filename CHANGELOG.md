# Changelog

All notable changes to CloudToLocalLLM will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.2.0] - 2025-01-27

### Added - Multi-App Architecture with Tunnel Manager
- **NEW: Tunnel Manager v1.0.0** - Independent Flutter desktop application for tunnel management
  - Dedicated connection broker handling local Ollama and cloud services
  - HTTP REST API server on localhost:8765 for external application integration
  - Real-time WebSocket support for status updates
  - Comprehensive health monitoring with configurable intervals (5-300 seconds)
  - Performance metrics collection (latency percentiles, throughput, error rates)
  - Secure authentication token management with Flutter secure storage
  - Material Design 3 GUI for configuration and diagnostics
  - Background service operation with optional minimal GUI
  - Automatic startup integration via systemd user service
  - Connection pooling and request routing optimization
  - Graceful shutdown handling with state persistence

- **Enhanced System Tray Daemon v2.0.0** - Major upgrade with tunnel integration
  - Real-time tunnel status monitoring with dynamic icons
  - Enhanced menu structure with connection quality indicators
  - Intelligent alert system with configurable thresholds
  - Version compatibility checking across all components
  - Migration support from v1.x with automated upgrade paths
  - Improved IPC communication with HTTP REST API primary and TCP fallback
  - Comprehensive tooltip information with latency and model counts
  - Context-aware menu items based on authentication state

- **Shared Library v3.2.0** - Common utilities and version management
  - Centralized version constants and compatibility checking
  - Cross-component version validation during build process
  - Shared models and services for consistent behavior
  - Build timestamp and Git commit tracking

- **Multi-App Build System** - Comprehensive build pipeline
  - Version consistency validation across all components
  - Unified distribution packaging with launcher scripts
  - Platform-specific build optimization for Linux desktop
  - Automated desktop integration with .desktop entries
  - Build information generation with dependency tracking

### Enhanced
- **Main Application v3.2.0** - Integration with tunnel manager
  - Tunnel manager integration for improved connection reliability
  - Version display in persistent bottom-right corner overlay
  - Enhanced connection status reporting via tunnel API
  - Backward compatibility with existing tray daemon v1.x
  - Improved error handling and graceful degradation

- **Version Management System** - Comprehensive versioning
  - Semantic versioning across all components with compatibility matrix
  - Build timestamp and Git commit hash tracking
  - Version display in all user interfaces with hover tooltips
  - Cross-component dependency validation during builds
  - Migration support for configuration and data formats

- **Documentation Updates** - Complete architecture documentation
  - Tunnel Manager README with API reference and troubleshooting
  - Updated main README with multi-app architecture section
  - Version compatibility matrix and migration guides
  - Deployment documentation with multi-service configuration
  - API reference documentation with OpenAPI specification

### Technical Improvements
- **Architecture Refactoring** - Modular multi-app design
  - Independent application lifecycle management
  - Service isolation to prevent cascade failures
  - Centralized configuration management with hot-reloading
  - Hierarchical service dependency resolution
  - Enhanced error handling with specific error codes

- **Performance Optimization** - System-wide improvements
  - Connection pooling with concurrent request handling
  - Request queuing and routing optimization
  - Memory usage optimization (<50MB per service)
  - CPU usage optimization (<5% idle, <15% active)
  - Latency optimization (<100ms tunnel, <10ms API responses)

- **Security Enhancements** - Comprehensive security model
  - No root privileges required for any component
  - Proper sandboxing and process isolation
  - Secure credential storage with encryption
  - HTTPS-only cloud connections with certificate validation
  - Configurable CORS policies for API server

### Breaking Changes
- **Tray Daemon API v2.0** - Updated IPC protocol
  - New HTTP REST API primary communication method
  - Enhanced status reporting with connection quality metrics
  - Updated menu structure and tooltip format
  - Migration required from v1.x configurations

- **Configuration Format Changes** - Unified configuration
  - New tunnel manager configuration in `~/.cloudtolocalllm/tunnel_config.json`
  - Updated tray daemon configuration format
  - Shared library configuration validation
  - Backward compatibility with automatic migration

### Deployment
- **AUR Package Updates** - Enhanced Linux packaging
  - Multi-app binary distribution with ~125MB unified package
  - Systemd service templates for all components
  - Desktop integration with proper icon installation
  - Version consistency validation in package scripts

- **Build Pipeline** - Automated multi-component builds
  - Cross-component version validation
  - Unified distribution archive creation
  - Checksum generation and integrity verification
  - Platform-specific optimization for Linux x64

### Version Compatibility Matrix
- Main Application v3.2.0 ↔ Tunnel Manager v1.0.0 ✅
- Main Application v3.2.0 ↔ Tray Daemon v2.0.0 ✅
- Main Application v3.2.0 ↔ Shared Library v3.2.0 ✅
- Tunnel Manager v1.0.0 ↔ Tray Daemon v2.0.0 ✅
- Backward compatibility: Main App v3.2.0 ↔ Tray Daemon v1.x ⚠️ (limited)

### Migration Guide
For users upgrading from v3.1.x:
1. Stop existing tray daemon: `pkill cloudtolocalllm-enhanced-tray`
2. Install new multi-app package
3. Run configuration migration: `./cloudtolocalllm-tray --migrate-config`
4. Install system integration: `./install-system-integration.sh`
5. Start services: `systemctl --user start cloudtolocalllm-tunnel.service`

### Known Issues
- Tunnel manager WebSocket connections may require firewall configuration
- System tray icons may not display correctly on some Wayland compositors
- Configuration migration from v1.x requires manual verification

### Future Roadmap
- v1.1.0: Advanced load balancing and plugin system
- v2.0.0: Multi-user support and distributed tunnel management
- Cross-platform support for Windows and macOS

## [3.1.3] - 2025-01-26

### Fixed
- Enhanced tray daemon stability improvements
- Connection broker error handling
- Flutter web build compatibility

### Changed
- Updated dependencies to latest versions
- Improved logging and debugging output

## [3.1.2] - 2025-01-25

### Added
- Enhanced system tray daemon with connection broker
- Universal connection management for local and cloud
- Improved authentication flow

### Fixed
- System tray integration issues on Linux
- Connection stability improvements
- Memory usage optimization

## [3.1.1] - 2025-01-24

### Fixed
- Critical authentication bug fixes
- Improved error handling for connection failures
- UI responsiveness improvements

## [3.1.0] - 2025-01-23

### Added
- System tray integration with independent daemon
- Enhanced connection management
- Improved authentication with Auth0 integration
- Material Design 3 dark theme implementation

### Changed
- Migrated from system_tray package to Python-based daemon
- Improved connection reliability and error handling
- Enhanced UI with modern design patterns

### Fixed
- Connection timeout issues
- Authentication token management
- System tray icon display on various Linux environments

## [3.0.3] - 2025-01-20

### Fixed
- AUR package installation issues
- Binary distribution optimization
- Desktop integration improvements

## [3.0.2] - 2025-01-19

### Added
- AUR package support for Arch Linux
- Improved binary distribution
- Enhanced build scripts

### Fixed
- Package size optimization
- Dependency management improvements

## [3.0.1] - 2025-01-18

### Added
- SourceForge binary distribution
- Enhanced deployment workflow
- Improved documentation

### Fixed
- Build process optimization
- Distribution file management

## [3.0.0] - 2025-01-17

### Added
- Multi-container Docker architecture
- Independent service deployments
- Enhanced security with non-root containers
- Comprehensive documentation structure

### Changed
- Major architecture refactoring
- Improved scalability and maintainability
- Enhanced deployment processes

### Breaking Changes
- Docker configuration format changes
- Service communication protocol updates
- Configuration file structure modifications

---

For more information about each release, visit our [GitHub Releases](https://github.com/imrightguy/CloudToLocalLLM/releases) page.
