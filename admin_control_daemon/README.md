# Admin Control Daemon

This daemon manages and monitors the CloudToLocalLLM stack.

## Running as a systemd Service

1. **Build the daemon executable:**
   ```bash
   cd /opt/cloudtolocalllm/admin_control_daemon
   dart compile exe bin/server.dart -o daemon
   ```

2. **Create a systemd service file:**
   ```bash
   nano /etc/systemd/system/cloudllm-daemon.service
   ```
   Paste the following:
   ```ini
   [Unit]
   Description=CloudToLocalLLM Admin Control Daemon
   After=network.target

   [Service]
   Type=simple
   WorkingDirectory=/opt/cloudtolocalllm/admin_control_daemon
   ExecStart=/opt/cloudtolocalllm/admin_control_daemon/daemon
   Restart=on-failure
   User=root

   [Install]
   WantedBy=multi-user.target
   ```

3. **Enable and start the service:**
   ```bash
   systemctl daemon-reload
   systemctl enable --now cloudllm-daemon
   systemctl status cloudllm-daemon
   ```

4. **Monitor logs:**
   ```bash
   journalctl -u cloudllm-daemon -f
   ``` 