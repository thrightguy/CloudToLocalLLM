#!/usr/bin/env python3
"""
CloudToLocalLLM Enhanced System Tray Daemon

Independent system tray daemon that acts as a universal connection broker.
Provides:
- System tray functionality with independent operation
- Universal connection management (local Ollama + cloud proxy)
- Separate settings interface
- IPC communication with main Flutter app
- Authentication management
- Connection state monitoring
"""

import sys
import os
import json
import socket
import threading
import time
import logging
import argparse
import signal
import base64
import subprocess
import psutil
import asyncio
from pathlib import Path
from typing import Optional, Dict, Any

try:
    import pystray
    from pystray import MenuItem as Item
    from PIL import Image
    import io
except ImportError as e:
    print(f"Required dependencies not found: {e}")
    print("Please install: pip install pystray pillow aiohttp")
    sys.exit(1)

from connection_broker import ConnectionBroker, ConnectionType
from version import TrayDaemonVersion


class EnhancedTrayDaemon:
    """Enhanced system tray daemon with connection broker"""

    def __init__(self, port: int = 0, debug: bool = False):
        self.port = port
        self.debug = debug
        self.server_socket = None  # type: Optional[socket.socket]
        self.tray = None  # type: Optional[pystray.Icon]
        self.running = False
        self.client_connections = []

        # Setup logging
        log_level = logging.DEBUG if debug else logging.INFO
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self._get_log_path()),
                logging.StreamHandler() if debug else logging.NullHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

        # State management
        self.tooltip = TrayDaemonVersion.get_tooltip_version()
        self.icon_state = "idle"  # idle, connected, error

        # Application management
        self.app_process = None
        self.app_monitoring_thread = None
        self.app_is_running = False
        self.app_is_authenticated = False
        self.app_executable_path = None

        # Connection broker
        self.connection_broker = None  # type: Optional[ConnectionBroker]
        self.broker_loop = None  # type: Optional[asyncio.AbstractEventLoop]
        self.broker_thread = None  # type: Optional[threading.Thread]

        # Settings app management
        self.settings_process = None

        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _get_config_dir(self) -> Path:
        """Get the configuration directory for CloudToLocalLLM"""
        home = Path.home()
        if sys.platform == "win32":
            config_dir = home / "AppData" / "Local" / "CloudToLocalLLM"
        elif sys.platform == "darwin":
            config_dir = home / "Library" / "Application Support" / "CloudToLocalLLM"
        else:  # Linux and other Unix-like
            config_dir = home / ".cloudtolocalllm"

        config_dir.mkdir(parents=True, exist_ok=True)
        return config_dir

    def _get_log_path(self) -> Path:
        """Get the log file path"""
        return self._get_config_dir() / "tray.log"

    def _get_port_file_path(self) -> Path:
        """Get the port file path"""
        return self._get_config_dir() / "tray_port"

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.shutdown()

    async def _init_connection_broker(self):
        """Initialize the connection broker"""
        self.connection_broker = ConnectionBroker(
            config_dir=self._get_config_dir(),
            logger=self.logger
        )

        # Add status change callback
        self.connection_broker.add_status_callback(self._on_connection_status_change)

        # Start the broker
        await self.connection_broker.start()
        self.logger.info("Connection broker initialized")

    def _start_broker_thread(self):
        """Start the connection broker in a separate thread"""
        def run_broker():
            self.broker_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.broker_loop)

            try:
                self.broker_loop.run_until_complete(self._init_connection_broker())
                self.broker_loop.run_forever()
            except Exception as e:
                self.logger.error(f"Connection broker error: {e}")
            finally:
                if self.connection_broker:
                    self.broker_loop.run_until_complete(self.connection_broker.stop())

        self.broker_thread = threading.Thread(target=run_broker, daemon=True)
        self.broker_thread.start()
        self.logger.info("Connection broker thread started")

    def _on_connection_status_change(self, connection_type: ConnectionType, status):
        """Handle connection status changes"""
        self.logger.info(
            f"Connection {connection_type.value} status: {status.state.value}"
        )

        # Update icon state based on best available connection
        if self.connection_broker:
            best_connection = self.connection_broker.get_best_connection()
            if best_connection:
                self.icon_state = "connected"
            else:
                self.icon_state = "idle"

            # Update tray icon
            if self.tray:
                self.tray.icon = self._create_icon_image(self.icon_state)

        # Notify connected Flutter apps
        self._send_to_clients({
            "command": "CONNECTION_STATUS_CHANGED",
            "connection_type": connection_type.value,
            "status": {
                "state": status.state.value,
                "error_message": status.error_message,
                "version": status.version,
                "models": status.models
            }
        })

    def _find_app_executable(self) -> Optional[str]:
        """Find the CloudToLocalLLM executable"""
        possible_paths = []

        if sys.platform == "linux":
            possible_paths = [
                "/usr/bin/cloudtolocalllm",
                "/usr/local/bin/cloudtolocalllm",
                str(Path.home() / ".local/bin/cloudtolocalllm"),
                "./cloudtolocalllm",
                "./build/linux/x64/release/bundle/cloudtolocalllm",
            ]
        elif sys.platform == "win32":
            possible_paths = [
                str(Path(os.environ.get('PROGRAMFILES', ''))
                    / "CloudToLocalLLM" / "cloudtolocalllm.exe"),
                "./cloudtolocalllm.exe",
                "./build/windows/x64/runner/Release/cloudtolocalllm.exe",
            ]
        elif sys.platform == "darwin":
            possible_paths = [
                "/Applications/CloudToLocalLLM.app/Contents/MacOS/cloudtolocalllm",
                "./cloudtolocalllm",
                ("./build/macos/Build/Products/Release/"
                 "cloudtolocalllm.app/Contents/MacOS/cloudtolocalllm"),
            ]

        for path in possible_paths:
            if Path(path).exists():
                self.logger.info(f"Found app executable at: {path}")
                return path

        self.logger.warning("CloudToLocalLLM executable not found")
        return None

    def _find_settings_executable(self) -> Optional[str]:
        """Find the CloudToLocalLLM settings executable"""
        # For now, we'll use the same executable with a settings flag
        # In the future, this could be a separate settings app
        return self._find_app_executable()

    def _is_app_running(self) -> bool:
        """Check if CloudToLocalLLM application is currently running"""
        try:
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    # Check if process name contains cloudtolocalllm
                    if 'cloudtolocalllm' in proc.info['name'].lower():
                        return True
                    # Also check command line for Flutter apps
                    if proc.info['cmdline']:
                        cmdline = ' '.join(proc.info['cmdline']).lower()
                        if 'cloudtolocalllm' in cmdline:
                            return True
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            return False
        except Exception as e:
            self.logger.warning(f"Error checking if app is running: {e}")
            return False

    def _is_app_authenticated(self) -> bool:
        """Check if the CloudToLocalLLM application is authenticated"""
        try:
            # Check if we have any active client connections
            active_connections = [
                conn for conn in self.client_connections if not conn._closed
            ]
            if active_connections:
                # If we have active connections, the app is likely authenticated
                return True
            return False
        except Exception as e:
            self.logger.warning(f"Error checking app authentication status: {e}")
            return False

    def _launch_app(self) -> bool:
        """Launch the CloudToLocalLLM application"""
        if self.app_executable_path is None:
            self.app_executable_path = self._find_app_executable()

        if self.app_executable_path is None:
            self.logger.error("Cannot launch app: executable not found")
            return False

        try:
            self.logger.info(
                f"Launching CloudToLocalLLM: {self.app_executable_path}"
            )

            # Launch the application as a detached process
            if sys.platform == "win32":
                # Windows
                self.app_process = subprocess.Popen(
                    [self.app_executable_path],
                    creationflags=(subprocess.DETACHED_PROCESS
                                   | subprocess.CREATE_NEW_PROCESS_GROUP)
                )
            else:
                # Linux/macOS
                self.app_process = subprocess.Popen(
                    [self.app_executable_path],
                    start_new_session=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            self.logger.info(f"App launched with PID: {self.app_process.pid}")
            return True

        except Exception as e:
            self.logger.error(f"Failed to launch app: {e}")
            return False

    def _launch_settings(self) -> bool:
        """Launch the CloudToLocalLLM settings interface"""
        settings_executable = self._find_settings_executable()

        if settings_executable is None:
            self.logger.error("Cannot launch settings: executable not found")
            return False

        try:
            self.logger.info(
                f"Launching CloudToLocalLLM settings: {settings_executable}"
            )

            # Launch settings with a flag to open settings directly
            if sys.platform == "win32":
                # Windows
                self.settings_process = subprocess.Popen(
                    [settings_executable, "--settings"],
                    creationflags=(subprocess.DETACHED_PROCESS
                                   | subprocess.CREATE_NEW_PROCESS_GROUP)
                )
            else:
                # Linux/macOS
                self.settings_process = subprocess.Popen(
                    [settings_executable, "--settings"],
                    start_new_session=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )

            self.logger.info(f"Settings launched with PID: {self.settings_process.pid}")
            return True

        except Exception as e:
            self.logger.error(f"Failed to launch settings: {e}")
            return False

    def _get_icon_data(self, state: str = "idle") -> bytes:
        """Get base64 encoded icon data for different states"""
        # Base64 encoded monochrome icons (16x16 PNG)
        idle_icon = (
            "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAAmJLR0QA/4ePzL8AAAAHdElNRQfpBgEO"  # noqa: E501
            "GAvVNB70AAAAgElEQVQoz83RMQ6CUBAE0PfRBgItFzDxVh7DeA8bGo9lSW04ApCYtYBGBGqn3VdMdhJh"  # noqa: E501
            "O0maz7X8SyajTnAEFzfVAgwad28h6njGWl5xDhly1WqBQkmG2OgZYgK7+ReQpK0/T2A0rIJRP72607gq"  # noqa: E501
            "frZ4aM1jHZyUC9BrjaT9ufkAKf46eVLyT+wAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYtMDFUMTM6"  # noqa: E501
            "MjI6MzkrMDA6MDAT6q3EAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjIyOjM5KzAwOjAw"  # noqa: E501
            "YrcVeAAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxNDoyNDoxMSswMDowMDQFC6IAAAAA"  # noqa: E501
            "SUVORK5CYII="
        )
        connected_icon = (
            "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWEAQAAAA+LXjzAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1"  # noqa: E501
            "MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRP//FKsxzQAAAAd0SU1FB+kGAQ0KAtZaaNoAAAFBSURBVDjL"  # noqa: E501
            "7ZOxSwJhGMZ/BE3ieNNFS4ZDoxE4JCTBQS1tDSJNbeV04L8Rrm5BkARRDU1CWncIWY2dzrVoqzQFT8Nx"  # noqa: E501
            "pxdGlzaFD3zw8X3v++N5X94XZvrPMu7BvgYvD3oFbwfsCzAaU0ALKZC+PwVzEuhyAMhvSfsL0vuT5JxI"  # noqa: E501
            "K0cReOo35beDxMqZVCpJg4EiqjyMwo3mV8LcePDeG4C1BovzYJqQSEQjDjNg5cL4j5iOvQ3wyy4WpXZb"  # noqa: E501
            "Y+VcBY699ZhgvYCkGymdlvp9fathO2K1onMA4PYhmQTXHfnpQK/n3916+Lob07F9CZKVlWo1yTSlclmq"  # noqa: E501
            "VqVud+jW2gzc2udxp6IRTsXp+BZUbiNTcRcTDP7w+4nWtuS4kh4l51iyVqdfkqUfNi8zATRsSxPsOng5"  # noqa: E501
            "0DN4WbBbYLSmgM70B/oE5jIou4+gv28AAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYtMDFUMTM6MTA6"  # noqa: E501
            "MDIrMDA6MDACdUjhAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjEwOjAyKzAwOjAwcyjw"  # noqa: E501
            "XQAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxMzoxMDowMiswMDowMCQ90YIAAAAASUVO"  # noqa: E501
            "RK5CYII="
        )
        error_icon = (
            "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAAmJLR0QA/4ePzL8AAAAHdElNRQfpBgEO"  # noqa: E501
            "GQRckDIkAAAAhklEQVQoz82RsQ2DQAxFnxN0MAL0dKyVhiZ7oIzBVCkyALQgqKKfwkFK4HQ1z4Ul+9mF"  # noqa: E501
            "bRJJsm8eWbGfugiU2Cb0dEw7IaflzhVJgxoRiUpPKQNWJv7GfQULM1wAO3Qdw1xIchZBxM8t5JcM5MSc"  # noqa: E501
            "QOFCScuD5fCLGzWYBLx5Me+EgpqwCQk+v2IykhHf6oIAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYt"  # noqa: E501
            "MDFUMTM6MjI6MzkrMDA6MDAT6q3EAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjIyOjM5"  # noqa: E501
            "KzAwOjAwYrcVeAAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxNDoyNTowNCswMDowMEVV"  # noqa: E501
            "T6UAAAAASUVORK5CYII="
        )
        icons = {
            "idle": idle_icon,
            "connected": connected_icon,
            "error": error_icon,
        }

        icon_b64 = icons.get(state, icons["idle"])
        return base64.b64decode(icon_b64)

    def _create_icon_image(self, state: str = "idle") -> Image.Image:
        """Create PIL Image from icon data"""
        try:
            icon_data = self._get_icon_data(state)
            return Image.open(io.BytesIO(icon_data))
        except Exception as e:
            self.logger.error(f"Failed to create icon image: {e}")
            # Create a simple fallback icon
            img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
            return img

    def _create_menu(self) -> pystray.Menu:
        """Create the system tray context menu"""
        menu_items = []

        # Connection status section - prioritize Flutter app status
        flutter_status_shown = False
        if (hasattr(self, 'flutter_connection_status')
                and self.flutter_connection_status):
            # Show Flutter app connection status first
            for conn_type, status in self.flutter_connection_status.items():
                connected = status.get('connected', False)
                if connected:
                    if conn_type == 'ollama':
                        version = status.get('version', 'Unknown')
                        model_count = len(status.get('models', []))
                        menu_items.extend([
                            Item(
                                f"✅ Ollama {version} ({model_count} models)",
                                None, enabled=False
                            ),
                            pystray.Menu.SEPARATOR,
                        ])
                    elif conn_type == 'cloud':
                        endpoint = status.get('endpoint', 'Unknown')
                        menu_items.extend([
                            Item(f"✅ Cloud ({endpoint})", None, enabled=False),
                            pystray.Menu.SEPARATOR,
                        ])
                    flutter_status_shown = True
                    break

            # If no connected status found, show disconnected
            if not flutter_status_shown:
                for conn_type, status in self.flutter_connection_status.items():
                    menu_items.extend([
                        Item(f"❌ {conn_type.title()} Disconnected",
                             None, enabled=False),
                        pystray.Menu.SEPARATOR,
                    ])
                    flutter_status_shown = True
                    break

        # Fallback to connection broker status if no Flutter status
        if not flutter_status_shown and self.connection_broker:
            best_connection = self.connection_broker.get_best_connection()
            if best_connection:
                status = self.connection_broker.connection_status[best_connection]
                menu_items.extend([
                    Item(f"Connected via {best_connection.value}", None, enabled=False),
                    Item(f"Version: {status.version}", None, enabled=False),
                    pystray.Menu.SEPARATOR,
                ])
            else:
                menu_items.extend([
                    Item("No connections available", None, enabled=False),
                    pystray.Menu.SEPARATOR,
                ])

        # App management section
        if self.app_is_running:
            menu_items.extend([
                Item("Show CloudToLocalLLM", self._on_show_window),
                Item("Hide to Tray", self._on_hide_window),
                pystray.Menu.SEPARATOR,
            ])

            if self.app_is_authenticated:
                menu_items.extend([
                    Item("Ollama Test", self._on_ollama_test),
                    pystray.Menu.SEPARATOR,
                ])

            menu_items.append(Item("Quit Application", self._on_quit_app))
        else:
            menu_items.extend([
                Item("Launch CloudToLocalLLM", self._on_launch_app),
                pystray.Menu.SEPARATOR,
            ])

        # Daemon settings and management
        menu_items.extend([
            Item("Daemon Settings", self._on_daemon_settings),
            Item("Connection Status", self._on_connection_status),
            pystray.Menu.SEPARATOR,
            Item("Quit Tray Daemon", self._on_quit_daemon)
        ])

        return pystray.Menu(*menu_items)

    def _update_menu_for_status(self, status):
        """Update the tray menu to reflect new connection status"""
        # Store the status for menu generation
        if not hasattr(self, 'flutter_connection_status'):
            self.flutter_connection_status = {}

        connection_type = status.get('connection_type', 'unknown')
        self.flutter_connection_status[connection_type] = status

        # Recreate the menu with updated status
        if self.tray:
            self.tray.menu = self._create_menu()
            self.logger.info(
                "📋 [TrayDaemon] Menu updated with new connection status"
            )

    # Menu event handlers
    def _on_show_window(self, icon, item):
        """Handle show window menu item"""
        self._send_to_clients({"command": "SHOW"})

    def _on_hide_window(self, icon, item):
        """Handle hide window menu item"""
        self._send_to_clients({"command": "HIDE"})

    def _on_ollama_test(self, icon, item):
        """Handle Ollama test menu item"""
        if self.app_is_authenticated:
            self.logger.info("Opening Ollama test via tray menu")
            self._send_to_clients({"command": "OLLAMA_TEST"})
        else:
            self.logger.warning("Ollama test requested but app is not authenticated")

    def _on_launch_app(self, icon, item):
        """Handle launch application menu item"""
        if not self.app_is_running:
            self.logger.info("Launching app via tray menu")
            self._launch_app()

    def _on_quit_app(self, icon, item):
        """Handle quit application menu item"""
        self.logger.info("Quitting app via tray menu")
        self._send_to_clients({"command": "QUIT"})

    def _on_daemon_settings(self, icon, item):
        """Handle daemon settings menu item"""
        self.logger.info(
            "🔧 [TrayDaemon] Opening daemon settings"
        )

        # ALWAYS try to send command to Flutter app first
        # If there are connected clients, this will work regardless of
        # app_is_running state
        self.logger.info(
            "🔧 [TrayDaemon] Sending DAEMON_SETTINGS command to "
            "connected clients"
        )
        self._send_to_clients({"command": "DAEMON_SETTINGS"})
        self.logger.info("🔧 [TrayDaemon] DAEMON_SETTINGS command sent")

        # If no clients are connected, the command will be ignored
        # We could add fallback logic here if needed, but for now let's see
        # if this fixes the issue

    def _on_connection_status(self, icon, item):
        """Handle connection status menu item"""
        self.logger.info(
            "📊 [TrayDaemon] Showing connection status"
        )

        # ALWAYS try to send command to Flutter app first
        # If there are connected clients, this will work regardless of
        # app_is_running state
        self.logger.info(
            "📊 [TrayDaemon] Sending CONNECTION_STATUS command to "
            "connected clients"
        )
        self._send_to_clients({"command": "CONNECTION_STATUS"})
        self.logger.info("📊 [TrayDaemon] CONNECTION_STATUS command sent")

        # If no clients are connected, the command will be ignored
        # We could add fallback logic here if needed, but for now let's see
        # if this fixes the issue

    def _on_quit_daemon(self, icon, item):
        """Handle quit daemon menu item"""
        self.logger.info("Quitting tray daemon via menu")
        self.shutdown()

    def _on_tray_click(self, icon):
        """Handle tray icon click"""
        if self.app_is_running:
            self._send_to_clients({"command": "SHOW"})
        else:
            self._launch_app()

    def _send_to_clients(self, message: Dict[str, Any]):
        """Send message to all connected clients"""
        self.logger.info(
            f"📤 [TrayDaemon] Sending message to clients: {message}"
        )
        self.logger.info(
            f"📤 [TrayDaemon] Number of connected clients: "
            f"{len(self.client_connections)}"
        )

        message_json = json.dumps(message) + "\n"
        disconnected_clients = []

        for i, client in enumerate(self.client_connections):
            try:
                self.logger.info(
                    f"📤 [TrayDaemon] Sending to client {i}: "
                    f"{message_json.strip()}"
                )
                client.send(message_json.encode('utf-8'))
                self.logger.info(f"✅ [TrayDaemon] Successfully sent to client {i}")
            except Exception as e:
                self.logger.warning(
                    f"❌ [TrayDaemon] Failed to send to client {i}: {e}"
                )
                disconnected_clients.append(client)

        # Remove disconnected clients
        for client in disconnected_clients:
            self.logger.info("🗑️ [TrayDaemon] Removing disconnected client")
            self.client_connections.remove(client)
            try:
                client.close()
            except Exception:
                pass

        self.logger.info(
            f"📤 [TrayDaemon] Message sending complete. "
            f"Active clients: {len(self.client_connections)}"
        )

    def start_server(self) -> bool:
        """Start the TCP server for IPC communication"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(
                socket.SOL_SOCKET, socket.SO_REUSEADDR, 1
            )
            self.server_socket.bind(('127.0.0.1', self.port))
            self.server_socket.listen(5)

            # Get the actual port if we used 0 (auto-assign)
            self.port = self.server_socket.getsockname()[1]

            # Write port to file for Flutter app discovery
            port_file = self._get_port_file_path()
            with open(port_file, 'w') as f:
                f.write(str(self.port))

            self.logger.info(f"TCP server started on port {self.port}")

            # Start accepting connections in a separate thread
            server_thread = threading.Thread(
                target=self._accept_connections, daemon=True
            )
            server_thread.start()

            return True
        except Exception as e:
            self.logger.error(f"Failed to start TCP server: {e}")
            return False

    def _accept_connections(self):
        """Accept incoming client connections"""
        while self.running and self.server_socket:
            try:
                client_socket, address = self.server_socket.accept()
                self.logger.info(f"Client connected from {address}")
                self.client_connections.append(client_socket)

                # Handle client in separate thread
                client_thread = threading.Thread(
                    target=self._handle_client,
                    args=(client_socket,),
                    daemon=True
                )
                client_thread.start()
            except Exception as e:
                if self.running:
                    self.logger.error(f"Error accepting connection: {e}")
                break

    def _handle_client(self, client_socket: socket.socket):
        """Handle messages from a client"""
        buffer = ""
        try:
            while self.running:
                data = client_socket.recv(1024).decode('utf-8')
                if not data:
                    break

                buffer += data
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.strip():
                        self._process_message(line.strip(), client_socket)
        except Exception as e:
            self.logger.warning(f"Client handler error: {e}")
        finally:
            try:
                client_socket.close()
            except Exception:
                pass
            if client_socket in self.client_connections:
                self.client_connections.remove(client_socket)

    def _process_message(self, message: str, client_socket: socket.socket):
        """Process a message from a client"""
        try:
            data = json.loads(message)
            command = data.get('command')

            self.logger.debug(f"Received command: {command}")

            if command == "PING":
                self._send_response(client_socket, {"status": "pong"})

            elif command == "UPDATE_TOOLTIP":
                self.tooltip = data.get('text', 'CloudToLocalLLM')
                if self.tray:
                    self.tray.title = self.tooltip

            elif command == "UPDATE_ICON":
                state = data.get('state', 'idle')
                if state != self.icon_state:
                    self.icon_state = state
                    if self.tray:
                        self.tray.icon = self._create_icon_image(state)

            elif command == "AUTH_STATUS":
                # Update authentication status
                self.app_is_authenticated = data.get('authenticated', False)
                if self.tray:
                    self.tray.menu = self._create_menu()

            elif command == "UPDATE_AUTH_TOKEN":
                # Update authentication token for cloud connections
                token = data.get('token', '')
                if self.connection_broker:
                    self.connection_broker.update_auth_token(token)

            elif command == "PROXY_REQUEST":
                # Proxy a request through the connection broker
                self._handle_proxy_request(data, client_socket)

            elif command == "GET_CONNECTION_STATUS":
                # Get connection status
                if self.connection_broker:
                    status = self.connection_broker.get_connection_status()
                    self._send_response(client_socket, {"status": status})
                else:
                    self._send_response(
                        client_socket, {"error": "Connection broker not available"}
                    )

            elif command == "UPDATE_CONNECTION_STATUS":
                # Update connection status from Flutter app
                status = data.get('status', {})
                self.logger.info(
                    f"📡 [TrayDaemon] Received connection status update: {status}"
                )

                # Update our internal status tracking
                connection_type = status.get('connection_type', 'unknown')
                connected = status.get('connected', False)

                # Update tooltip based on connection status
                if connected:
                    if connection_type == 'ollama':
                        version = status.get('version', 'Unknown')
                        model_count = len(status.get('models', []))
                        self.tooltip = (
                            f"CloudToLocalLLM - Ollama {version} "
                            f"({model_count} models)"
                        )
                    elif connection_type == 'cloud':
                        endpoint = status.get('endpoint', 'Unknown')
                        self.tooltip = f"CloudToLocalLLM - Cloud ({endpoint})"
                    else:
                        self.tooltip = "CloudToLocalLLM - Connected"

                    # Update icon to connected state
                    if self.icon_state != 'connected':
                        self.icon_state = 'connected'
                        if self.tray:
                            self.tray.icon = self._create_icon_image('connected')
                else:
                    error = status.get('error', 'Connection failed')
                    self.tooltip = (
                        f"CloudToLocalLLM - Disconnected ({error})"
                    )

                    # Update icon to disconnected state
                    if self.icon_state != 'disconnected':
                        self.icon_state = 'disconnected'
                        if self.tray:
                            self.tray.icon = self._create_icon_image('disconnected')

                # Update tooltip
                if self.tray:
                    self.tray.title = self.tooltip

                # Update menu to reflect new status
                self._update_menu_for_status(status)

                self.logger.info(
                    f"📡 [TrayDaemon] Connection status updated: {self.tooltip}"
                )

            elif command == "QUIT":
                self.logger.info("Received quit command from client")
                self.shutdown()

            else:
                self.logger.warning(f"Unknown command: {command}")

        except json.JSONDecodeError:
            self.logger.error(f"Invalid JSON message: {message}")
        except Exception as e:
            self.logger.error(f"Error processing message: {e}")

    def _send_response(
            self, client_socket: socket.socket, response: Dict[str, Any]):
        """Send a response to a specific client"""
        try:
            response_json = json.dumps(response) + "\n"
            client_socket.send(response_json.encode('utf-8'))
        except Exception as e:
            self.logger.warning(f"Failed to send response: {e}")

    def _handle_proxy_request(
            self, data: Dict[str, Any], client_socket: socket.socket):
        """Handle a proxy request from a client"""
        if not self.connection_broker:
            self._send_response(
                client_socket, {"error": "Connection broker not available"}
            )
            return

        method = data.get('method', 'GET')
        path = data.get('path', '/')
        request_data = data.get('data')

        # Execute the proxy request in the broker's event loop
        if self.broker_loop:
            future = asyncio.run_coroutine_threadsafe(
                self.connection_broker.proxy_request(
                    method, path, request_data
                ),
                self.broker_loop
            )

            try:
                result = future.result(timeout=30)  # 30 second timeout
                self._send_response(client_socket, {"result": result})
            except Exception as e:
                self._send_response(client_socket, {"error": str(e)})

    def start_tray(self) -> bool:
        """Start the system tray"""
        try:
            icon_image = self._create_icon_image(self.icon_state)
            menu = self._create_menu()

            self.tray = pystray.Icon(
                "CloudToLocalLLM",
                icon_image,
                self.tooltip,
                menu
            )

            # Set click handler
            self.tray.default_action = self._on_tray_click

            self.logger.info("Starting system tray...")
            self.running = True

            # Run tray (this blocks)
            self.tray.run()

            return True
        except Exception as e:
            self.logger.error(f"Failed to start system tray: {e}")
            return False

    def run(self) -> int:
        """Main run method"""
        try:
            self.logger.info("Starting CloudToLocalLLM Enhanced Tray Daemon...")

            # Start connection broker
            self._start_broker_thread()

            # Start TCP server
            if not self.start_server():
                self.logger.error("Failed to start TCP server")
                return 1

            # Start application monitoring
            self._start_app_monitoring()

            # Start system tray (this blocks until shutdown)
            if not self.start_tray():
                self.logger.error("Failed to start system tray")
                return 1

            return 0

        except KeyboardInterrupt:
            self.logger.info("Received keyboard interrupt")
            return 0
        except Exception as e:
            self.logger.error(f"Unexpected error: {e}")
            return 1
        finally:
            self.shutdown()

    def _start_app_monitoring(self):
        """Start monitoring the application state"""
        if self.app_monitoring_thread is not None:
            return

        self.app_monitoring_thread = threading.Thread(
            target=self._monitor_app_state, daemon=True
        )
        self.app_monitoring_thread.start()
        self.logger.info("Started application monitoring")

    def _monitor_app_state(self):
        """Monitor application state and update tray menu accordingly"""
        self.logger.info("🔍 [TrayDaemon] Starting app state monitoring thread")

        while self.running:
            try:
                current_running_state = self._is_app_running()
                current_auth_state = (
                    self._is_app_authenticated() if current_running_state else False
                )

                self.logger.debug(
                    f"🔍 [TrayDaemon] App state check: "
                    f"running={current_running_state}, auth={current_auth_state}, "
                    f"stored_running={self.app_is_running}"
                )

                # Check if running state changed
                if current_running_state != self.app_is_running:
                    self.app_is_running = current_running_state
                    self.logger.info(
                        f"🔄 [TrayDaemon] App running state changed: "
                        f"{'running' if current_running_state else 'stopped'}"
                    )

                    # Reset auth state if app stopped
                    if not current_running_state:
                        self.app_is_authenticated = False

                # Check if authentication state changed
                if current_auth_state != self.app_is_authenticated:
                    self.app_is_authenticated = current_auth_state
                    auth_status = (
                        'authenticated' if current_auth_state else 'not authenticated'
                    )
                    self.logger.info(
                        f"🔄 [TrayDaemon] App auth state changed: {auth_status}"
                    )

                # Update tray menu if any state changed
                if (current_running_state != self.app_is_running
                        or current_auth_state != self.app_is_authenticated):
                    self.logger.info(
                        "🔄 [TrayDaemon] Updating tray menu due to state change"
                    )
                    if self.tray:
                        self.tray.menu = self._create_menu()

                time.sleep(2)  # Check every 2 seconds

            except Exception as e:
                self.logger.error(f"💥 [TrayDaemon] Error in app monitoring: {e}")
                time.sleep(5)  # Wait longer on error

    def shutdown(self):
        """Shutdown the daemon"""
        self.logger.info("Shutting down tray daemon...")
        self.running = False

        # Stop connection broker
        if self.broker_loop and self.connection_broker:
            try:
                future = asyncio.run_coroutine_threadsafe(
                    self.connection_broker.stop(),
                    self.broker_loop
                )
                future.result(timeout=5)
            except Exception as e:
                self.logger.error(f"Error stopping connection broker: {e}")

        if self.broker_loop:
            self.broker_loop.call_soon_threadsafe(self.broker_loop.stop)

        # Close server socket
        if self.server_socket:
            try:
                self.server_socket.close()
            except Exception:
                pass

        # Close client connections
        for client in self.client_connections:
            try:
                client.close()
            except Exception:
                pass

        # Stop tray
        if self.tray:
            self.tray.stop()

        # Clean up port file
        try:
            port_file = self._get_port_file_path()
            if port_file.exists():
                port_file.unlink()
        except Exception:
            pass

        self.logger.info("Tray daemon shutdown complete")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='CloudToLocalLLM Enhanced Tray Daemon'
    )
    parser.add_argument(
        '--port', type=int, default=0, help='TCP port for IPC (0 for auto-assign)'
    )
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')

    args = parser.parse_args()

    daemon = EnhancedTrayDaemon(port=args.port, debug=args.debug)
    return daemon.run()


if __name__ == '__main__':
    sys.exit(main())
