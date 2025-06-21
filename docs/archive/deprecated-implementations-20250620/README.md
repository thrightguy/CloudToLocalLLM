# Deprecated Implementation Documentation Archive

This directory contains documentation for deprecated implementations that have been superseded by the unified Flutter-native architecture.

## Archived Documents

### TUNNEL_MANAGER_IMPLEMENTATION_SUMMARY.md
**Archived Date**: 2025-06-20
**Reason**: References deprecated multi-app architecture (apps/main/, apps/tunnel_manager/, tray_daemon/)
**Replacement**: Current unified Flutter architecture documented in:
- `docs/ARCHITECTURE/SYSTEM_ARCHITECTURE.md`
- `docs/ARCHITECTURE/ENHANCED_SYSTEM_TRAY_ARCHITECTURE.md`
- `docs/ARCHITECTURE_MODERNIZATION_v3.3.1.md`

### build_tray_daemon.sh
**Archived Date**: 2025-06-20
**Reason**: Python-based tray daemon build script no longer needed in unified Flutter architecture
**Replacement**: Flutter-native system tray using tray_manager package (no separate build required)

## Architecture Evolution

### Deprecated (v3.2.x and earlier)
- Multi-app structure with separate apps/main/ and apps/tunnel_manager/
- Python-based tray daemon (tray_daemon/)
- Separate tunnel manager application
- Complex multi-process architecture

### Current (v3.4.0+)
- Unified Flutter-native application
- Integrated system tray using tray_manager package
- Single executable with all functionality
- Simplified deployment and maintenance

## Migration Information

The multi-app architecture was consolidated in v3.3.1+ to provide:
- Simplified deployment (single executable)
- Reduced complexity (no multi-process coordination)
- Better reliability (no IPC communication failures)
- Native platform integration (Flutter-native system tray)

## Historical Reference

These documents are preserved for historical reference and understanding the evolution of the CloudToLocalLLM architecture. They should NOT be used for current development or deployment.

For current architecture documentation, refer to:
- `docs/ARCHITECTURE/` - Current system architecture
- `docs/DEVELOPMENT/` - Development guidelines
- `README.md` - Current project overview

---
*Archive created: 2025-06-20*  
*CloudToLocalLLM Architecture Modernization*
