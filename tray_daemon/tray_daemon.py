#!/usr/bin/env python3
"""
CloudToLocalLLM System Tray Daemon

Cross-platform system tray daemon for CloudToLocalLLM using Python and pystray.
Provides reliable system tray functionality with crash isolation from the main Flutter app.

Architecture:
- TCP socket IPC with JSON protocol
- Embedded base64 monochrome icons
- Cross-platform compatibility (Linux, Windows, macOS)
- Graceful degradation when system tray is unavailable
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
from pathlib import Path
from typing import Optional, Dict, Any, Callable

try:
    import pystray
    from pystray import MenuItem as Item
    from PIL import Image
    import io
except ImportError as e:
    print(f"Required dependencies not found: {e}")
    print("Please install: pip install pystray pillow")
    sys.exit(1)


class TrayDaemon:
    """Main system tray daemon class"""

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
        self.tooltip = "CloudToLocalLLM"
        self.icon_state = "idle"  # idle, connected, error

        # Application management
        self.app_process = None
        self.app_monitoring_thread = None
        self.app_is_running = False
        self.app_is_authenticated = False
        self.app_executable_path = None

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
            # Try to query the app's authentication status via IPC
            # We'll send a status query and check the response
            if not self.client_connections:
                # No active connections, assume not authenticated
                return False

            # For now, we'll use a simple heuristic:
            # If the app has been connected for more than 10 seconds, assume authenticated
            # In a more sophisticated implementation, we could send a STATUS command
            # and wait for a response with authentication state

            # Check if we have any active client connections
            active_connections = [
                conn for conn in self.client_connections if not conn._closed
            ]
            if active_connections:
                # If we have active connections, the app is likely authenticated
                # This is a simplified approach - in production you might want to
                # implement a proper status query mechanism
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

    def _start_app_monitoring(self):
        """Start monitoring the application state"""
        if self.app_monitoring_thread is not None:
            return

        self.app_monitoring_thread = threading.Thread(
            target=self._monitor_app_state,
            daemon=True
        )
        self.app_monitoring_thread.start()
        self.logger.info("Started application monitoring")

    def _monitor_app_state(self):
        """Monitor application state and update tray menu accordingly"""
        while self.running:
            try:
                current_running_state = self._is_app_running()
                current_auth_state = (
                    self._is_app_authenticated() if current_running_state else False
                )

                # Check if running state changed
                if current_running_state != self.app_is_running:
                    self.app_is_running = current_running_state
                    self.logger.info(
                        f"App running state changed: "
                        f"{'running' if current_running_state else 'stopped'}"
                    )

                    # Reset auth state if app stopped
                    if not current_running_state:
                        self.app_is_authenticated = False

                # Check if authentication state changed
                if current_auth_state != self.app_is_authenticated:
                    self.app_is_authenticated = current_auth_state
                    self.logger.info(
                        f"App auth state changed: "
                        f"{'authenticated' if current_auth_state else 'not authenticated'}"
                    )

                # Update tray menu if any state changed
                if (current_running_state != self.app_is_running
                        or current_auth_state != self.app_is_authenticated):
                    if self.tray:
                        self.tray.menu = self._create_menu()

                # Update icon state
                if current_running_state and current_auth_state:
                    new_icon_state = "connected"
                elif current_running_state:
                    new_icon_state = "idle"  # Running but not authenticated
                else:
                    new_icon_state = "idle"  # Not running

                if new_icon_state != self.icon_state:
                    self.icon_state = new_icon_state
                    if self.tray:
                        self.tray.icon = self._create_icon_image(
                            self.icon_state
                        )

                time.sleep(2)  # Check every 2 seconds

            except Exception as e:
                self.logger.error(f"Error in app monitoring: {e}")
                time.sleep(5)  # Wait longer on error

    def _get_icon_data(self, state: str = "idle") -> bytes:
        """Get base64 encoded icon data for different states"""
        # Base64 encoded monochrome icons (16x16 PNG)
        # Generated from CloudToLocalLLM assets
        icons = {
            "idle": (
                "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAAmJLR0QA/4ePzL8AAAAHdElNRQfpBgEO"
                "GAvVNB70AAAAgElEQVQoz83RMQ6CUBAE0PfRBgItFzDxVh7DeA8bGo9lSW04ApCYtYBGBGqn3VdMdhJh"
                "O0maz7X8SyajTnAEFzfVAgwad28h6njGWl5xDhly1WqBQkmG2OgZYgK7+ReQpK0/T2A0rIJRP72607gq"
                "frZ4aM1jHZyUC9BrjaT9ufkAKf46eVLyT+wAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYtMDFUMTM6"
                "MjI6MzkrMDA6MDAT6q3EAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjIyOjM5KzAwOjAw"
                "YrcVeAAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxNDoyNDoxMSswMDowMDQFC6IAAAAA"
                "SUVORK5CYII="
            ),
            "connected": (
                "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWEAQAAAA+LXjzAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1"
                "MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRP//FKsxzQAAAAd0SU1FB+kGAQ0KAtZaaNoAAAFBSURBVDjL"
                "7ZOxSwJhGMZ/BE3ieNNFS4ZDoxE4JCTBQS1tDSJNbeV04L8Rrm5BkARRDU1CWncIWY2dzrVoqzQFT8Nx"
                "pxdGlzaFD3zw8X3v++N5X94XZvrPMu7BvgYvD3oFbwfsCzAaU0ALKZC+PwVzEuhyAMhvSfsL0vuT5JxI"
                "K0cReOo35beDxMqZVCpJg4EiqjyMwo3mV8LcePDeG4C1BovzYJqQSEQjDjNg5cL4j5iOvQ3wyy4WpXZb"
                "Y+VcBY699ZhgvYCkGymdlvp9fathO2K1onMA4PYhmQTXHfnpQK/n3916+Lob07F9CZKVlWo1yTSlclmq"
                "VqVud+jW2gzc2udxp6IRTsXp+BZUbiNTcRcTDP7w+4nWtuS4kh4l51iyVqdfkqUfNi8zATRsSxPsOng5"
                "0DN4WbBbYLSmgM70B/oE5jIou4+gv28AAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYtMDFUMTM6MTA6"
                "MDIrMDA6MDACdUjhAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjEwOjAyKzAwOjAwcyjw"
                "XQAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxMzoxMDowMiswMDowMCQ90YIAAAAASUVO"
                "RK5CYII="
            ),
            "error": (
                "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAAmJLR0QA/4ePzL8AAAAHdElNRQfpBgEO"
                "GQRckDIkAAAAhklEQVQoz82RsQ2DQAxFnxN0MAL0dKyVhiZ7oIzBVCkyALQgqKKfwkFK4HQ1z4Ul+9mF"
                "bRJJsm8eWbGfugiU2Cb0dEw7IaflzhVJgxoRiUpPKQNWJv7GfQULM1wAO3Qdw1xIchZBxM8t5JcM5MSc"
                "QOFCScuD5fCLGzWYBLx5Me+EgpqwCQk+v2IykhHf6oIAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDYt"
                "MDFUMTM6MjI6MzkrMDA6MDAT6q3EAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTA2LTAxVDEzOjIyOjM5"
                "KzAwOjAwYrcVeAAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNS0wNi0wMVQxNDoyNTowNCswMDowMEVV"
                "T6UAAAAASUVORK5CYII="
            ),
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
        """Create the system tray context menu based on application and authentication state"""
        menu_items = []

        if self.app_is_running:
            # App is running - show control options
            menu_items.extend([
                Item("Show CloudToLocalLLM", self._on_show_window),
                Item("Hide to Tray", self._on_hide_window),
                pystray.Menu.SEPARATOR,
            ])

            # Add authentication-aware menu items
            if self.app_is_authenticated:
                menu_items.extend([
                    Item("Settings", self._on_settings),
                    Item("Ollama Test", self._on_ollama_test),
                    pystray.Menu.SEPARATOR,
                ])
            else:
                menu_items.extend([
                    Item("Login Required", None, enabled=False),
                    pystray.Menu.SEPARATOR,
                ])

            menu_items.append(Item("Quit Application", self._on_quit_app))
        else:
            # App is not running - show launch option
            menu_items.extend([
                Item("Launch CloudToLocalLLM", self._on_launch_app),
                pystray.Menu.SEPARATOR,
            ])

        # Always show daemon quit option
        menu_items.extend([
            pystray.Menu.SEPARATOR,
            Item("Quit Tray Daemon", self._on_quit_daemon)
        ])

        return pystray.Menu(*menu_items)

    def _on_show_window(self, icon, item):
        """Handle show window menu item"""
        self._send_to_clients({"command": "SHOW"})

    def _on_hide_window(self, icon, item):
        """Handle hide window menu item"""
        self._send_to_clients({"command": "HIDE"})

    def _on_settings(self, icon, item):
        """Handle settings menu item"""
        if self.app_is_authenticated:
            self.logger.info("Opening settings via tray menu")
            self._send_to_clients({"command": "SETTINGS"})
        else:
            self.logger.warning("Settings requested but app is not authenticated")

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
        message_json = json.dumps(message) + "\n"
        disconnected_clients = []

        for client in self.client_connections:
            try:
                client.send(message_json.encode('utf-8'))
            except Exception as e:
                self.logger.warning(f"Failed to send to client: {e}")
                disconnected_clients.append(client)

        # Remove disconnected clients
        for client in disconnected_clients:
            self.client_connections.remove(client)
            try:
                client.close()
            except Exception:
                pass

    def start_server(self) -> bool:
        """Start the TCP server for IPC communication"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
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
                        self._process_message(line.strip())
        except Exception as e:
            self.logger.warning(f"Client connection error: {e}")
        finally:
            if client_socket in self.client_connections:
                self.client_connections.remove(client_socket)
            try:
                client_socket.close()
            except Exception:
                pass

    def _process_message(self, message: str):
        """Process incoming message from client"""
        try:
            data = json.loads(message)
            command = data.get('command', '')

            self.logger.debug(f"Received command: {command}")

            if command == 'UPDATE_TOOLTIP':
                self.tooltip = data.get('text', 'CloudToLocalLLM')
                if self.tray:
                    self.tray.title = self.tooltip
            elif command == 'UPDATE_ICON':
                new_state = data.get('state', 'idle')
                if new_state != self.icon_state:
                    self.icon_state = new_state
                    if self.tray:
                        self.tray.icon = self._create_icon_image(new_state)
            elif command == 'UPDATE_AUTH_STATUS':
                authenticated = data.get('authenticated', False)
                old_auth_state = self.app_is_authenticated
                self.app_is_authenticated = authenticated
                self.logger.info(f"Auth status updated: {authenticated}")

                # Update tray menu if auth state changed
                if old_auth_state != authenticated and self.tray:
                    self.tray.menu = self._create_menu()
                    self.logger.info("Tray menu updated due to auth state change")
            elif command == 'PING':
                # Send pong response
                response = {"response": "PONG"}
                response_json = json.dumps(response) + "\n"
                for client in self.client_connections:
                    try:
                        client.send(response_json.encode('utf-8'))
                    except Exception:
                        pass
            elif command == 'QUIT':
                self.shutdown()
        except json.JSONDecodeError as e:
            self.logger.warning(f"Invalid JSON message: {e}")
        except Exception as e:
            self.logger.error(f"Error processing message: {e}")

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

    def shutdown(self):
        """Shutdown the daemon gracefully"""
        self.logger.info("Shutting down tray daemon...")
        self.running = False

        # Close all client connections
        for client in self.client_connections:
            try:
                client.close()
            except Exception:
                pass
        self.client_connections.clear()

        # Close server socket
        if self.server_socket:
            try:
                self.server_socket.close()
            except Exception:
                pass

        # Stop tray
        if self.tray:
            try:
                self.tray.stop()
            except Exception:
                pass

        # Remove port file
        try:
            port_file = self._get_port_file_path()
            if port_file.exists():
                port_file.unlink()
        except Exception:
            pass

        self.logger.info("Tray daemon shutdown complete")

    def run(self) -> int:
        """Main run method"""
        self.logger.info("Starting CloudToLocalLLM Tray Daemon...")

        # Check if system tray is supported
        if not self._is_tray_supported():
            self.logger.error("System tray is not supported on this platform")
            return 1

        # Find app executable
        self.app_executable_path = self._find_app_executable()

        # Check initial app state
        self.app_is_running = self._is_app_running()
        self.logger.info(f"Initial app state: {'running' if self.app_is_running else 'stopped'}")

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

    def _is_tray_supported(self) -> bool:
        """Check if system tray is supported"""
        try:
            # Basic platform check
            if sys.platform not in ["linux", "win32", "darwin"]:
                return False

            # For Linux, check if we're in a graphical environment
            if sys.platform == "linux":
                display = os.environ.get('DISPLAY')
                wayland = os.environ.get('WAYLAND_DISPLAY')
                if not display and not wayland:
                    self.logger.warning("No graphical display detected")
                    return False

                # Check available backends
                self._check_available_backends()

            # Try to create a test icon to check support
            test_image = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
            pystray.Icon("test", test_image)
            # If we can create it, tray is likely supported
            return True
        except Exception as e:
            self.logger.warning(f"System tray support check failed: {e}")
            return False

    def _check_available_backends(self):
        """Check and log available pystray backends"""
        backends = []

        try:
            import pystray._xorg
            backends.append("xorg")
        except ImportError:
            pass

        try:
            import pystray._gtk
            backends.append("gtk")
        except ImportError:
            pass

        try:
            import pystray._appindicator  # noqa: F401
            backends.append("appindicator")
        except ImportError:
            pass

        self.logger.info(
            f"Available pystray backends: {', '.join(backends) if backends else 'none'}"
        )

        # Log desktop environment info
        desktop = os.environ.get('XDG_CURRENT_DESKTOP', 'unknown')
        session = os.environ.get('XDG_SESSION_TYPE', 'unknown')
        self.logger.info(
            f"Desktop environment: {desktop}, Session type: {session}"
        )

        if 'appindicator' in backends:
            self.logger.info(
                "AppIndicator backend available - should work well with "
                "modern desktop environments"
            )
        elif 'gtk' in backends:
            self.logger.info("GTK backend available - good fallback option")
        elif 'xorg' in backends:
            self.logger.warning(
                "Only X11 backend available - may have compatibility issues "
                "with some desktop environments"
            )
        else:
            self.logger.error(
                "No pystray backends available - system tray will not work"
            )


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='CloudToLocalLLM System Tray Daemon')
    parser.add_argument('--port', type=int, default=0,
                       help='TCP port for IPC (0 for auto-assign)')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug logging')
    parser.add_argument('--version', action='version', version='1.0.0')

    args = parser.parse_args()

    daemon = TrayDaemon(port=args.port, debug=args.debug)

    try:
        return daemon.run()
    except KeyboardInterrupt:
        daemon.shutdown()
        return 0
    except Exception as e:
        print(f"Fatal error: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
