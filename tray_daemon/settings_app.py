#!/usr/bin/env python3
"""
CloudToLocalLLM Tray Daemon Settings App

Simple GUI application for configuring the tray daemon settings.
Provides interface for:
- Connection configuration (local Ollama, cloud proxy)
- Authentication settings
- Daemon preferences
- Connection status monitoring
"""

import sys
import json
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
from pathlib import Path
import threading
import time
from typing import Dict, Any, Optional

try:
    import requests
except ImportError:
    print("Please install requests: pip install requests")
    sys.exit(1)


class TrayDaemonSettings:
    """Settings GUI for the tray daemon"""
    
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("CloudToLocalLLM Tray Daemon Settings")
        self.root.geometry("600x500")
        self.root.resizable(True, True)
        
        # Configuration
        self.config_dir = self._get_config_dir()
        self.config_file = self.config_dir / "connection_config.json"
        self.config = self._load_config()
        
        # Status monitoring
        self.status_thread = None
        self.monitoring = False
        
        self._create_widgets()
        self._load_settings()
        self._start_status_monitoring()
    
    def _get_config_dir(self) -> Path:
        """Get the configuration directory"""
        home = Path.home()
        if sys.platform == "win32":
            config_dir = home / "AppData" / "Local" / "CloudToLocalLLM"
        elif sys.platform == "darwin":
            config_dir = home / "Library" / "Application Support" / "CloudToLocalLLM"
        else:  # Linux and other Unix-like
            config_dir = home / ".cloudtolocalllm"
        
        config_dir.mkdir(parents=True, exist_ok=True)
        return config_dir
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from file"""
        if not self.config_file.exists():
            return self._get_default_config()
        
        try:
            with open(self.config_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Get default configuration"""
        return {
            "local_ollama": {
                "connection_type": "local_ollama",
                "host": "localhost",
                "port": 11434,
                "api_base_url": "http://localhost:11434",
                "auth_token": "",
                "timeout": 30,
                "enabled": True
            },
            "cloud_proxy": {
                "connection_type": "cloud_proxy",
                "host": "",
                "port": 443,
                "api_base_url": "https://api.cloudtolocalllm.online",
                "auth_token": "",
                "timeout": 30,
                "enabled": False
            }
        }
    
    def _save_config(self):
        """Save configuration to file"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
            messagebox.showinfo("Success", "Configuration saved successfully!")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save configuration: {e}")
    
    def _create_widgets(self):
        """Create the GUI widgets"""
        # Create notebook for tabs
        notebook = ttk.Notebook(self.root)
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Local Ollama tab
        self.ollama_frame = ttk.Frame(notebook)
        notebook.add(self.ollama_frame, text="Local Ollama")
        self._create_ollama_tab()
        
        # Cloud Proxy tab
        self.cloud_frame = ttk.Frame(notebook)
        notebook.add(self.cloud_frame, text="Cloud Proxy")
        self._create_cloud_tab()
        
        # Status tab
        self.status_frame = ttk.Frame(notebook)
        notebook.add(self.status_frame, text="Connection Status")
        self._create_status_tab()
        
        # Buttons frame
        buttons_frame = ttk.Frame(self.root)
        buttons_frame.pack(fill=tk.X, padx=10, pady=(0, 10))
        
        ttk.Button(buttons_frame, text="Save", command=self._save_settings).pack(side=tk.RIGHT, padx=(5, 0))
        ttk.Button(buttons_frame, text="Test Connections", command=self._test_connections).pack(side=tk.RIGHT)
        ttk.Button(buttons_frame, text="Refresh Status", command=self._refresh_status).pack(side=tk.RIGHT, padx=(0, 5))
    
    def _create_ollama_tab(self):
        """Create Local Ollama configuration tab"""
        # Enabled checkbox
        self.ollama_enabled = tk.BooleanVar()
        ttk.Checkbutton(self.ollama_frame, text="Enable Local Ollama Connection", 
                       variable=self.ollama_enabled).pack(anchor=tk.W, pady=5)
        
        # Host and port
        host_frame = ttk.Frame(self.ollama_frame)
        host_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(host_frame, text="Host:").pack(side=tk.LEFT)
        self.ollama_host = tk.StringVar()
        ttk.Entry(host_frame, textvariable=self.ollama_host, width=20).pack(side=tk.LEFT, padx=(5, 10))
        
        ttk.Label(host_frame, text="Port:").pack(side=tk.LEFT)
        self.ollama_port = tk.StringVar()
        ttk.Entry(host_frame, textvariable=self.ollama_port, width=10).pack(side=tk.LEFT, padx=(5, 0))
        
        # Timeout
        timeout_frame = ttk.Frame(self.ollama_frame)
        timeout_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(timeout_frame, text="Timeout (seconds):").pack(side=tk.LEFT)
        self.ollama_timeout = tk.StringVar()
        ttk.Entry(timeout_frame, textvariable=self.ollama_timeout, width=10).pack(side=tk.LEFT, padx=(5, 0))
        
        # Status
        self.ollama_status = ttk.Label(self.ollama_frame, text="Status: Unknown")
        self.ollama_status.pack(anchor=tk.W, pady=10)
    
    def _create_cloud_tab(self):
        """Create Cloud Proxy configuration tab"""
        # Enabled checkbox
        self.cloud_enabled = tk.BooleanVar()
        ttk.Checkbutton(self.cloud_frame, text="Enable Cloud Proxy Connection", 
                       variable=self.cloud_enabled).pack(anchor=tk.W, pady=5)
        
        # API Base URL
        url_frame = ttk.Frame(self.cloud_frame)
        url_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(url_frame, text="API Base URL:").pack(anchor=tk.W)
        self.cloud_url = tk.StringVar()
        ttk.Entry(url_frame, textvariable=self.cloud_url, width=50).pack(fill=tk.X, pady=(2, 0))
        
        # Auth Token
        token_frame = ttk.Frame(self.cloud_frame)
        token_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(token_frame, text="Authentication Token:").pack(anchor=tk.W)
        self.cloud_token = tk.StringVar()
        token_entry = ttk.Entry(token_frame, textvariable=self.cloud_token, width=50, show="*")
        token_entry.pack(fill=tk.X, pady=(2, 0))
        
        # Show/Hide token button
        self.show_token = tk.BooleanVar()
        show_btn = ttk.Checkbutton(token_frame, text="Show token", variable=self.show_token,
                                  command=lambda: token_entry.config(show="" if self.show_token.get() else "*"))
        show_btn.pack(anchor=tk.W, pady=2)
        
        # Timeout
        timeout_frame = ttk.Frame(self.cloud_frame)
        timeout_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(timeout_frame, text="Timeout (seconds):").pack(side=tk.LEFT)
        self.cloud_timeout = tk.StringVar()
        ttk.Entry(timeout_frame, textvariable=self.cloud_timeout, width=10).pack(side=tk.LEFT, padx=(5, 0))
        
        # Status
        self.cloud_status = ttk.Label(self.cloud_frame, text="Status: Unknown")
        self.cloud_status.pack(anchor=tk.W, pady=10)
    
    def _create_status_tab(self):
        """Create Connection Status tab"""
        # Status text area
        self.status_text = scrolledtext.ScrolledText(self.status_frame, height=20, width=70)
        self.status_text.pack(fill=tk.BOTH, expand=True, pady=5)
        
        # Auto-refresh checkbox
        self.auto_refresh = tk.BooleanVar(value=True)
        ttk.Checkbutton(self.status_frame, text="Auto-refresh every 5 seconds", 
                       variable=self.auto_refresh).pack(anchor=tk.W, pady=5)
    
    def _load_settings(self):
        """Load settings into GUI"""
        # Local Ollama
        ollama_config = self.config.get("local_ollama", {})
        self.ollama_enabled.set(ollama_config.get("enabled", True))
        self.ollama_host.set(ollama_config.get("host", "localhost"))
        self.ollama_port.set(str(ollama_config.get("port", 11434)))
        self.ollama_timeout.set(str(ollama_config.get("timeout", 30)))
        
        # Cloud Proxy
        cloud_config = self.config.get("cloud_proxy", {})
        self.cloud_enabled.set(cloud_config.get("enabled", False))
        self.cloud_url.set(cloud_config.get("api_base_url", "https://api.cloudtolocalllm.online"))
        self.cloud_token.set(cloud_config.get("auth_token", ""))
        self.cloud_timeout.set(str(cloud_config.get("timeout", 30)))
    
    def _save_settings(self):
        """Save settings from GUI"""
        try:
            # Update Local Ollama config
            self.config["local_ollama"].update({
                "enabled": self.ollama_enabled.get(),
                "host": self.ollama_host.get(),
                "port": int(self.ollama_port.get()),
                "timeout": int(self.ollama_timeout.get()),
                "api_base_url": f"http://{self.ollama_host.get()}:{self.ollama_port.get()}"
            })
            
            # Update Cloud Proxy config
            self.config["cloud_proxy"].update({
                "enabled": self.cloud_enabled.get(),
                "api_base_url": self.cloud_url.get(),
                "auth_token": self.cloud_token.get(),
                "timeout": int(self.cloud_timeout.get())
            })
            
            self._save_config()
            
        except ValueError as e:
            messagebox.showerror("Error", f"Invalid input: {e}")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to save settings: {e}")
    
    def _test_connections(self):
        """Test all enabled connections"""
        self.status_text.delete(1.0, tk.END)
        self.status_text.insert(tk.END, "Testing connections...\n\n")
        
        # Test Local Ollama
        if self.ollama_enabled.get():
            self._test_ollama_connection()
        
        # Test Cloud Proxy
        if self.cloud_enabled.get():
            self._test_cloud_connection()
    
    def _test_ollama_connection(self):
        """Test Local Ollama connection"""
        try:
            url = f"http://{self.ollama_host.get()}:{self.ollama_port.get()}/api/version"
            response = requests.get(url, timeout=int(self.ollama_timeout.get()))
            
            if response.status_code == 200:
                data = response.json()
                version = data.get('version', 'unknown')
                self.status_text.insert(tk.END, f"✓ Local Ollama: Connected (v{version})\n")
                self.ollama_status.config(text=f"Status: Connected (v{version})")
            else:
                self.status_text.insert(tk.END, f"✗ Local Ollama: HTTP {response.status_code}\n")
                self.ollama_status.config(text=f"Status: Error (HTTP {response.status_code})")
                
        except Exception as e:
            self.status_text.insert(tk.END, f"✗ Local Ollama: {e}\n")
            self.ollama_status.config(text=f"Status: Error ({e})")
    
    def _test_cloud_connection(self):
        """Test Cloud Proxy connection"""
        try:
            url = f"{self.cloud_url.get()}/health"
            headers = {}
            if self.cloud_token.get():
                headers["Authorization"] = f"Bearer {self.cloud_token.get()}"
            
            response = requests.get(url, headers=headers, timeout=int(self.cloud_timeout.get()))
            
            if response.status_code == 200:
                self.status_text.insert(tk.END, "✓ Cloud Proxy: Connected\n")
                self.cloud_status.config(text="Status: Connected")
            else:
                self.status_text.insert(tk.END, f"✗ Cloud Proxy: HTTP {response.status_code}\n")
                self.cloud_status.config(text=f"Status: Error (HTTP {response.status_code})")
                
        except Exception as e:
            self.status_text.insert(tk.END, f"✗ Cloud Proxy: {e}\n")
            self.cloud_status.config(text=f"Status: Error ({e})")
    
    def _refresh_status(self):
        """Refresh connection status"""
        self._test_connections()
    
    def _start_status_monitoring(self):
        """Start background status monitoring"""
        self.monitoring = True
        self.status_thread = threading.Thread(target=self._status_monitor_loop, daemon=True)
        self.status_thread.start()
    
    def _status_monitor_loop(self):
        """Background status monitoring loop"""
        while self.monitoring:
            if self.auto_refresh.get():
                self.root.after(0, self._refresh_status)
            time.sleep(5)
    
    def run(self):
        """Run the settings application"""
        try:
            self.root.mainloop()
        finally:
            self.monitoring = False


def main():
    """Main entry point"""
    app = TrayDaemonSettings()
    app.run()


if __name__ == '__main__':
    main()
