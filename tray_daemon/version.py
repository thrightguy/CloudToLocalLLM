#!/usr/bin/env python3
"""
CloudToLocalLLM Tray Daemon Version Management

Provides version constants and compatibility checks for the tray daemon
"""


from typing import Dict, Any, Optional, List

# Version constants
TRAY_DAEMON_VERSION = "2.0.0"
TRAY_DAEMON_BUILD = 1
COMPATIBLE_MAIN_APP_VERSIONS = ["3.2.0", "3.1.3"]  # Backward compatibility
COMPATIBLE_TUNNEL_MANAGER_VERSIONS = ["1.0.0"]
MIN_PYTHON_VERSION = (3, 7)

# Build information (updated during build process)
BUILD_TIMESTAMP = "2025-01-27T00:00:00Z"
GIT_COMMIT_HASH = "development"

# API version for IPC communication
IPC_API_VERSION = "2.0"


class TrayDaemonVersion:
    """Tray daemon version management and compatibility checking"""

    @staticmethod
    def get_version_info() -> Dict[str, Any]:
        """Get comprehensive version information"""
        return {
            "version": TRAY_DAEMON_VERSION,
            "build": TRAY_DAEMON_BUILD,
            "full_version": f"{TRAY_DAEMON_VERSION}+{TRAY_DAEMON_BUILD}",
            "api_version": IPC_API_VERSION,
            "build_timestamp": BUILD_TIMESTAMP,
            "git_commit": GIT_COMMIT_HASH,
            "python_version": (
                f"{sys.version_info.major}.{sys.version_info.minor}."
                f"{sys.version_info.micro}"
            ),
            "compatible_apps": {
                "main_app": COMPATIBLE_MAIN_APP_VERSIONS,
                "tunnel_manager": COMPATIBLE_TUNNEL_MANAGER_VERSIONS,
            }
        }

    @staticmethod
    def is_app_compatible(app_version: str, app_type: str = "main_app") -> bool:
        """Check if an application version is compatible with this tray daemon"""
        if app_type == "main_app":
            compatible_versions = COMPATIBLE_MAIN_APP_VERSIONS
        elif app_type == "tunnel_manager":
            compatible_versions = COMPATIBLE_TUNNEL_MANAGER_VERSIONS
        else:
            return False

        # Extract major.minor from version string
        try:
            app_major_minor = ".".join(app_version.split(".")[:2])
            return any(
                app_major_minor == ".".join(compatible.split(".")[:2])
                for compatible in compatible_versions
            )
        except (ValueError, IndexError):
            return False

    @staticmethod
    def check_python_compatibility() -> bool:
        """Check if current Python version is compatible"""
        return sys.version_info >= MIN_PYTHON_VERSION

    @staticmethod
    def get_compatibility_report(
            app_version: Optional[str] = None, app_type: str = "main_app"
    ) -> Dict[str, Any]:
        """Get detailed compatibility report"""

        report = {
            "tray_daemon": {
                "version": TRAY_DAEMON_VERSION,
                "build": TRAY_DAEMON_BUILD,
                "api_version": IPC_API_VERSION,
            },
            "python": {
                "version": (
                    f"{sys.version_info.major}.{sys.version_info.minor}."
                    f"{sys.version_info.micro}"
                ),
                "compatible": TrayDaemonVersion.check_python_compatibility(),
                "required": f"{MIN_PYTHON_VERSION[0]}.{MIN_PYTHON_VERSION[1]}+",
            },
            "build_info": {
                "timestamp": BUILD_TIMESTAMP,
                "git_commit": GIT_COMMIT_HASH,
            }
        }

        if app_version:
            report["app_compatibility"] = {
                "app_version": app_version,
                "app_type": app_type,
                "compatible": TrayDaemonVersion.is_app_compatible(
                    app_version, app_type
                ),
                "supported_versions": (
                    COMPATIBLE_MAIN_APP_VERSIONS if app_type == "main_app"
                    else COMPATIBLE_TUNNEL_MANAGER_VERSIONS
                ),
            }

        return report

    @staticmethod
    def format_version_for_display() -> str:
        """Format version for UI display"""
        return (
            f"Tray Daemon v{TRAY_DAEMON_VERSION}+{TRAY_DAEMON_BUILD}"
        )

    @staticmethod
    def format_detailed_version() -> str:
        """Format detailed version with build info"""
        return (
            f"Tray Daemon v{TRAY_DAEMON_VERSION}+{TRAY_DAEMON_BUILD} "
            f"({BUILD_TIMESTAMP})"
        )

    @staticmethod
    def get_tooltip_version() -> str:
        """Get version string for system tray tooltip"""
        return f"CloudToLocalLLM Tray v{TRAY_DAEMON_VERSION}"

# Version validation functions


def validate_version_format(version: str) -> bool:
    """Validate semantic version format (x.y.z)"""
    try:
        parts = version.split(".")
        if len(parts) != 3:
            return False

        for part in parts:
            int(part)  # Check if each part is a valid integer

        return True
    except (ValueError, AttributeError):
        return False


def compare_versions(version1: str, version2: str) -> int:
    """Compare two semantic versions

    Returns:
        -1 if version1 < version2
         0 if version1 == version2
         1 if version1 > version2
    """
    try:
        v1_parts = [int(x) for x in version1.split(".")]
        v2_parts = [int(x) for x in version2.split(".")]

        # Pad shorter version with zeros
        max_len = max(len(v1_parts), len(v2_parts))
        v1_parts.extend([0] * (max_len - len(v1_parts)))
        v2_parts.extend([0] * (max_len - len(v2_parts)))

        for v1, v2 in zip(v1_parts, v2_parts):
            if v1 < v2:
                return -1
            elif v1 > v2:
                return 1

        return 0
    except (ValueError, AttributeError):
        return 0


def is_version_newer(current: str, target: str) -> bool:
    """Check if target version is newer than current version"""
    return compare_versions(target, current) > 0

# Migration support
class VersionMigration:
    """Handle version migrations for tray daemon"""

    @staticmethod
    def get_migration_path(from_version: str, to_version: str) -> List[str]:
        """Get list of migration steps needed"""
        migrations = []

        # Define migration paths
        migration_map = {
            ("1.0.0", "2.0.0"): ["migrate_config_format", "migrate_ipc_protocol"],
            ("1.1.0", "2.0.0"): ["migrate_ipc_protocol"],
        }

        # Find applicable migration
        for (from_ver, to_ver), steps in migration_map.items():
            if (from_version.startswith(from_ver.rsplit(".", 1)[0])
                    and to_version.startswith(to_ver.rsplit(".", 1)[0])):
                migrations.extend(steps)

        return migrations

    @staticmethod
    def needs_migration(from_version: str) -> bool:
        """Check if migration is needed from given version"""
        return compare_versions(from_version, TRAY_DAEMON_VERSION) < 0

    @staticmethod
    def get_migration_info(from_version: str) -> Dict[str, Any]:
        """Get information about required migration"""
        if not VersionMigration.needs_migration(from_version):
            return {"needs_migration": False}

        migration_steps = VersionMigration.get_migration_path(
            from_version, TRAY_DAEMON_VERSION
        )

        return {
            "needs_migration": True,
            "from_version": from_version,
            "to_version": TRAY_DAEMON_VERSION,
            "migration_steps": migration_steps,
            "backup_recommended": True,
        }

# Export main version info for easy access
__version__ = TRAY_DAEMON_VERSION
__build__ = TRAY_DAEMON_BUILD
__api_version__ = IPC_API_VERSION

if __name__ == "__main__":
    import sys
    import json

    # Command line version info
    if len(sys.argv) > 1:
        if sys.argv[1] == "--version":
            print(f"{TRAY_DAEMON_VERSION}+{TRAY_DAEMON_BUILD}")
        elif sys.argv[1] == "--detailed":
            print(TrayDaemonVersion.format_detailed_version())
        elif sys.argv[1] == "--json":
            print(json.dumps(TrayDaemonVersion.get_version_info(), indent=2))
        elif sys.argv[1] == "--compatibility":
            app_version = sys.argv[2] if len(sys.argv) > 2 else None
            app_type = sys.argv[3] if len(sys.argv) > 3 else "main_app"
            print(json.dumps(
                TrayDaemonVersion.get_compatibility_report(
                    app_version, app_type
                ), indent=2
            ))
    else:
        print(TrayDaemonVersion.format_version_for_display())
