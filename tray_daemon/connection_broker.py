#!/usr/bin/env python3
"""
CloudToLocalLLM Connection Broker

Universal connection broker that handles ALL connections for CloudToLocalLLM:
- Local Ollama connections (direct HTTP)
- Cloud proxy connections (authenticated HTTP)
- Streaming chat functionality
- Authentication management
- Connection state management

This broker acts as a proxy between the main Flutter app and all external services,
providing a unified API regardless of connection type.
"""

import asyncio
import aiohttp
import json
import logging
import time
from typing import Dict, Any, Optional, List, Callable
from dataclasses import dataclass, asdict
from enum import Enum
from pathlib import Path


class ConnectionType(Enum):
    LOCAL_OLLAMA = "local_ollama"
    CLOUD_PROXY = "cloud_proxy"


class ConnectionState(Enum):
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    ERROR = "error"


@dataclass
class ConnectionConfig:
    """Configuration for a connection"""
    connection_type: ConnectionType
    host: str = "localhost"
    port: int = 11434
    api_base_url: str = ""
    auth_token: str = ""
    timeout: int = 30
    enabled: bool = True


@dataclass
class ConnectionStatus:
    """Status of a connection"""
    connection_type: ConnectionType
    state: ConnectionState
    last_check: float
    error_message: str = ""
    version: str = ""
    models: List[str] = None

    def __post_init__(self):
        if self.models is None:
            self.models = []


class ConnectionBroker:
    """Universal connection broker for all CloudToLocalLLM connections"""

    def __init__(self, config_dir: Path, logger: logging.Logger):
        self.config_dir = config_dir
        self.logger = logger
        self.connections: Dict[ConnectionType, ConnectionConfig] = {}
        self.connection_status: Dict[ConnectionType, ConnectionStatus] = {}
        self.session: Optional[aiohttp.ClientSession] = None
        self.monitoring_task: Optional[asyncio.Task] = None
        self.status_callbacks: List[Callable] = []

        # Initialize default configurations
        self._init_default_configs()

        # Load saved configurations
        self._load_configs()

    def _init_default_configs(self):
        """Initialize default connection configurations"""
        self.connections[ConnectionType.LOCAL_OLLAMA] = ConnectionConfig(
            connection_type=ConnectionType.LOCAL_OLLAMA,
            host="localhost",
            port=11434,
            api_base_url="http://localhost:11434",
            enabled=True
        )

        self.connections[ConnectionType.CLOUD_PROXY] = ConnectionConfig(
            connection_type=ConnectionType.CLOUD_PROXY,
            api_base_url="https://api.cloudtolocalllm.online",
            enabled=False  # Disabled by default, enabled when authenticated
        )

        # Initialize connection status
        for conn_type in ConnectionType:
            self.connection_status[conn_type] = ConnectionStatus(
                connection_type=conn_type,
                state=ConnectionState.DISCONNECTED,
                last_check=0
            )

    def _get_config_file(self) -> Path:
        """Get the configuration file path"""
        return self.config_dir / "connection_config.json"

    def _load_configs(self):
        """Load connection configurations from file"""
        config_file = self._get_config_file()
        if not config_file.exists():
            self._save_configs()
            return

        try:
            with open(config_file, 'r') as f:
                data = json.load(f)

            for conn_type_str, config_data in data.items():
                try:
                    conn_type = ConnectionType(conn_type_str)
                    self.connections[conn_type] = ConnectionConfig(**config_data)
                except (ValueError, TypeError) as e:
                    self.logger.warning(f"Invalid config for {conn_type_str}: {e}")

        except Exception as e:
            self.logger.error(f"Failed to load connection configs: {e}")

    def _save_configs(self):
        """Save connection configurations to file"""
        config_file = self._get_config_file()
        try:
            data = {}
            for conn_type, config in self.connections.items():
                # Convert to dict, excluding the enum
                config_dict = asdict(config)
                config_dict['connection_type'] = conn_type.value
                data[conn_type.value] = config_dict

            with open(config_file, 'w') as f:
                json.dump(data, f, indent=2)

        except Exception as e:
            self.logger.error(f"Failed to save connection configs: {e}")

    async def start(self):
        """Start the connection broker"""
        self.logger.info("Starting connection broker...")

        # Create aiohttp session
        timeout = aiohttp.ClientTimeout(total=30)
        self.session = aiohttp.ClientSession(timeout=timeout)

        # Start connection monitoring
        self.monitoring_task = asyncio.create_task(self._monitor_connections())

        self.logger.info("Connection broker started")

    async def stop(self):
        """Stop the connection broker"""
        self.logger.info("Stopping connection broker...")

        if self.monitoring_task:
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass

        if self.session:
            await self.session.close()

        self.logger.info("Connection broker stopped")

    def add_status_callback(self, callback: Callable):
        """Add a callback for connection status changes"""
        self.status_callbacks.append(callback)

    def _notify_status_change(self, connection_type: ConnectionType):
        """Notify all callbacks of a status change"""
        for callback in self.status_callbacks:
            try:
                callback(connection_type, self.connection_status[connection_type])
            except Exception as e:
                self.logger.error(f"Error in status callback: {e}")

    async def _monitor_connections(self):
        """Monitor all enabled connections"""
        while True:
            try:
                for conn_type, config in self.connections.items():
                    if config.enabled:
                        await self._check_connection(conn_type)

                await asyncio.sleep(10)  # Check every 10 seconds

            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"Error in connection monitoring: {e}")
                await asyncio.sleep(5)

    async def _check_connection(self, connection_type: ConnectionType):
        """Check the status of a specific connection"""
        config = self.connections[connection_type]
        status = self.connection_status[connection_type]

        old_state = status.state

        try:
            if connection_type == ConnectionType.LOCAL_OLLAMA:
                await self._check_ollama_connection(config, status)
            elif connection_type == ConnectionType.CLOUD_PROXY:
                await self._check_cloud_connection(config, status)

        except Exception as e:
            status.state = ConnectionState.ERROR
            status.error_message = str(e)
            self.logger.error(
                f"Connection check failed for {connection_type.value}: {e}"
            )

        status.last_check = time.time()

        # Notify if state changed
        if old_state != status.state:
            self.logger.info(
                f"Connection {connection_type.value} state: "
                f"{old_state.value} -> {status.state.value}"
            )
            self._notify_status_change(connection_type)

    async def _check_ollama_connection(self, config: ConnectionConfig, status: ConnectionStatus):
        """Check local Ollama connection"""
        url = f"{config.api_base_url}/api/version"

        try:
            async with self.session.get(url) as response:
                if response.status == 200:
                    data = await response.json()
                    status.state = ConnectionState.CONNECTED
                    status.version = data.get('version', 'unknown')
                    status.error_message = ""

                    # Also fetch available models
                    await self._fetch_ollama_models(config, status)
                else:
                    status.state = ConnectionState.ERROR
                    status.error_message = f"HTTP {response.status}"

        except aiohttp.ClientConnectorError:
            status.state = ConnectionState.DISCONNECTED
            status.error_message = "Connection refused"
        except asyncio.TimeoutError:
            status.state = ConnectionState.ERROR
            status.error_message = "Connection timeout"

    async def _fetch_ollama_models(self, config: ConnectionConfig, status: ConnectionStatus):
        """Fetch available models from Ollama"""
        url = f"{config.api_base_url}/api/tags"

        try:
            async with self.session.get(url) as response:
                if response.status == 200:
                    data = await response.json()
                    models = [
                        model['name'] for model in data.get('models', [])
                    ]
                    status.models = models

        except Exception as e:
            self.logger.warning(f"Failed to fetch Ollama models: {e}")

    async def _check_cloud_connection(self, config: ConnectionConfig, status: ConnectionStatus):
        """Check cloud proxy connection"""
        if not config.auth_token:
            status.state = ConnectionState.DISCONNECTED
            status.error_message = "No authentication token"
            return

        url = f"{config.api_base_url}/health"
        headers = {"Authorization": f"Bearer {config.auth_token}"}

        try:
            async with self.session.get(url, headers=headers) as response:
                if response.status == 200:
                    await response.json()  # Consume response
                    status.state = ConnectionState.CONNECTED
                    status.version = "Cloud Bridge"
                    status.error_message = ""
                else:
                    status.state = ConnectionState.ERROR
                    status.error_message = f"HTTP {response.status}"

        except aiohttp.ClientConnectorError:
            status.state = ConnectionState.DISCONNECTED
            status.error_message = "Connection refused"
        except asyncio.TimeoutError:
            status.state = ConnectionState.ERROR
            status.error_message = "Connection timeout"

    # Public API Methods

    def get_connection_status(self, connection_type: ConnectionType = None) -> Dict[str, Any]:
        """Get status of connections"""
        if connection_type:
            status = self.connection_status[connection_type]
            return {
                'connection_type': connection_type.value,
                'state': status.state.value,
                'last_check': status.last_check,
                'error_message': status.error_message,
                'version': status.version,
                'models': status.models
            }
        else:
            # Return all connection statuses
            result = {}
            for conn_type, status in self.connection_status.items():
                result[conn_type.value] = {
                    'state': status.state.value,
                    'last_check': status.last_check,
                    'error_message': status.error_message,
                    'version': status.version,
                    'models': status.models
                }
            return result

    def get_best_connection(self) -> Optional[ConnectionType]:
        """Get the best available connection"""
        # Prefer local Ollama if available
        if (self.connections[ConnectionType.LOCAL_OLLAMA].enabled
                and self.connection_status[ConnectionType.LOCAL_OLLAMA].state
                == ConnectionState.CONNECTED):
            return ConnectionType.LOCAL_OLLAMA

        # Fall back to cloud proxy if available
        if (self.connections[ConnectionType.CLOUD_PROXY].enabled
                and self.connection_status[ConnectionType.CLOUD_PROXY].state
                == ConnectionState.CONNECTED):
            return ConnectionType.CLOUD_PROXY

        return None

    def update_auth_token(self, token: str):
        """Update the authentication token for cloud connections"""
        self.connections[ConnectionType.CLOUD_PROXY].auth_token = token
        self.connections[ConnectionType.CLOUD_PROXY].enabled = bool(token)
        self._save_configs()

        # Trigger immediate connection check
        if token:
            asyncio.create_task(self._check_connection(ConnectionType.CLOUD_PROXY))

    def update_ollama_config(self, host: str = "localhost", port: int = 11434):
        """Update local Ollama configuration"""
        config = self.connections[ConnectionType.LOCAL_OLLAMA]
        config.host = host
        config.port = port
        config.api_base_url = f"http://{host}:{port}"
        self._save_configs()

        # Trigger immediate connection check
        asyncio.create_task(self._check_connection(ConnectionType.LOCAL_OLLAMA))

    async def proxy_request(
            self, method: str, path: str, data: Dict[str, Any] = None,
            connection_type: ConnectionType = None) -> Dict[str, Any]:
        """Proxy a request through the best available connection"""
        if connection_type is None:
            connection_type = self.get_best_connection()

        if connection_type is None:
            raise Exception("No available connections")

        config = self.connections[connection_type]

        if connection_type == ConnectionType.LOCAL_OLLAMA:
            return await self._proxy_ollama_request(config, method, path, data)
        elif connection_type == ConnectionType.CLOUD_PROXY:
            return await self._proxy_cloud_request(config, method, path, data)
        else:
            raise Exception(f"Unsupported connection type: {connection_type}")

    async def _proxy_ollama_request(
            self, config: ConnectionConfig, method: str,
            path: str, data: Dict[str, Any] = None) -> Dict[str, Any]:
        """Proxy request to local Ollama"""
        url = f"{config.api_base_url}{path}"

        try:
            if method.upper() == "GET":
                async with self.session.get(url) as response:
                    return await self._handle_response(response)
            elif method.upper() == "POST":
                async with self.session.post(url, json=data) as response:
                    return await self._handle_response(response)
            else:
                raise Exception(f"Unsupported method: {method}")

        except Exception as e:
            self.logger.error(f"Ollama request failed: {e}")
            raise

    async def _proxy_cloud_request(
            self, config: ConnectionConfig, method: str,
            path: str, data: Dict[str, Any] = None) -> Dict[str, Any]:
        """Proxy request to cloud service"""
        # Map Ollama API paths to cloud API paths
        cloud_path = self._map_ollama_to_cloud_path(path)
        url = f"{config.api_base_url}{cloud_path}"

        headers = {"Authorization": f"Bearer {config.auth_token}"}

        try:
            if method.upper() == "GET":
                async with self.session.get(url, headers=headers) as response:
                    return await self._handle_response(response)
            elif method.upper() == "POST":
                async with self.session.post(
                        url, json=data, headers=headers) as response:
                    return await self._handle_response(response)
            else:
                raise Exception(f"Unsupported method: {method}")

        except Exception as e:
            self.logger.error(f"Cloud request failed: {e}")
            raise

    def _map_ollama_to_cloud_path(self, ollama_path: str) -> str:
        """Map Ollama API paths to cloud API paths"""
        # Map common Ollama paths to cloud equivalents
        path_mapping = {
            "/api/version": "/api/proxy/status",
            "/api/tags": "/api/ollama/api/tags",
            "/api/chat": "/api/ollama/api/chat",
            "/api/generate": "/api/ollama/api/generate",
            "/api/pull": "/api/ollama/api/pull",
            "/api/push": "/api/ollama/api/push",
            "/api/create": "/api/ollama/api/create",
            "/api/delete": "/api/ollama/api/delete",
        }

        return path_mapping.get(ollama_path, f"/api/ollama{ollama_path}")

    async def _handle_response(
            self, response: aiohttp.ClientResponse) -> Dict[str, Any]:
        """Handle HTTP response"""
        if response.status == 200:
            return await response.json()
        else:
            error_text = await response.text()
            raise Exception(f"HTTP {response.status}: {error_text}")

    async def stream_chat(
            self, model: str, messages: List[Dict[str, str]],
            connection_type: ConnectionType = None):
        """Stream chat responses"""
        if connection_type is None:
            connection_type = self.get_best_connection()

        if connection_type is None:
            raise Exception("No available connections")

        config = self.connections[connection_type]

        if connection_type == ConnectionType.LOCAL_OLLAMA:
            async for chunk in self._stream_ollama_chat(config, model, messages):
                yield chunk
        elif connection_type == ConnectionType.CLOUD_PROXY:
            async for chunk in self._stream_cloud_chat(config, model, messages):
                yield chunk
        else:
            raise Exception(f"Unsupported connection type: {connection_type}")

    async def _stream_ollama_chat(
            self, config: ConnectionConfig, model: str,
            messages: List[Dict[str, str]]):
        """Stream chat from local Ollama"""
        url = f"{config.api_base_url}/api/chat"
        data = {
            "model": model,
            "messages": messages,
            "stream": True
        }

        try:
            async with self.session.post(url, json=data) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"HTTP {response.status}: {error_text}")

                async for line in response.content:
                    if line:
                        try:
                            chunk = json.loads(line.decode('utf-8'))
                            yield chunk
                        except json.JSONDecodeError:
                            continue

        except Exception as e:
            self.logger.error(f"Ollama streaming failed: {e}")
            raise

    async def _stream_cloud_chat(
            self, config: ConnectionConfig, model: str,
            messages: List[Dict[str, str]]):
        """Stream chat from cloud service"""
        url = f"{config.api_base_url}/api/ollama/api/chat"
        headers = {"Authorization": f"Bearer {config.auth_token}"}
        data = {
            "model": model,
            "messages": messages,
            "stream": True
        }

        try:
            async with self.session.post(url, json=data, headers=headers) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"HTTP {response.status}: {error_text}")

                async for line in response.content:
                    if line:
                        try:
                            chunk = json.loads(line.decode('utf-8'))
                            yield chunk
                        except json.JSONDecodeError:
                            continue

        except Exception as e:
            self.logger.error(f"Cloud streaming failed: {e}")
            raise
