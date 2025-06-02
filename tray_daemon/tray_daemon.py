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
        self.server_socket: Optional[socket.socket] = None
        self.tray: Optional[pystray.Icon] = None
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
        """Create the system tray context menu"""
        return pystray.Menu(
            Item("Show CloudToLocalLLM", self._on_show_window),
            Item("Hide to Tray", self._on_hide_window),
            pystray.Menu.SEPARATOR,
            Item("Settings", self._on_settings),
            pystray.Menu.SEPARATOR,
            Item("Quit", self._on_quit)
        )
    
    def _on_show_window(self, icon, item):
        """Handle show window menu item"""
        self._send_to_clients({"command": "SHOW"})
    
    def _on_hide_window(self, icon, item):
        """Handle hide window menu item"""
        self._send_to_clients({"command": "HIDE"})
    
    def _on_settings(self, icon, item):
        """Handle settings menu item"""
        self._send_to_clients({"command": "SETTINGS"})
    
    def _on_quit(self, icon, item):
        """Handle quit menu item"""
        self._send_to_clients({"command": "QUIT"})
        self.shutdown()
    
    def _on_tray_click(self, icon):
        """Handle tray icon click"""
        self._send_to_clients({"command": "SHOW"})
    
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
            except:
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
            server_thread = threading.Thread(target=self._accept_connections, daemon=True)
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
            except:
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
            elif command == 'PING':
                # Send pong response
                response = {"response": "PONG"}
                response_json = json.dumps(response) + "\n"
                for client in self.client_connections:
                    try:
                        client.send(response_json.encode('utf-8'))
                    except:
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
            except:
                pass
        self.client_connections.clear()

        # Close server socket
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass

        # Stop tray
        if self.tray:
            try:
                self.tray.stop()
            except:
                pass

        # Remove port file
        try:
            port_file = self._get_port_file_path()
            if port_file.exists():
                port_file.unlink()
        except:
            pass

        self.logger.info("Tray daemon shutdown complete")

    def run(self) -> int:
        """Main run method"""
        self.logger.info("Starting CloudToLocalLLM Tray Daemon...")

        # Check if system tray is supported
        if not self._is_tray_supported():
            self.logger.error("System tray is not supported on this platform")
            return 1

        # Start TCP server
        if not self.start_server():
            self.logger.error("Failed to start TCP server")
            return 1

        # Start system tray (this blocks until shutdown)
        if not self.start_tray():
            self.logger.error("Failed to start system tray")
            return 1

        return 0

    def _is_tray_supported(self) -> bool:
        """Check if system tray is supported"""
        try:
            # Try to create a test icon to check support
            test_image = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
            test_icon = pystray.Icon("test", test_image)
            # If we can create it, tray is likely supported
            return True
        except Exception as e:
            self.logger.warning(f"System tray support check failed: {e}")
            return False


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
