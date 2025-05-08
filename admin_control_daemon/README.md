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

## Safe Rebuild and Restart of the Daemon

Whenever you update the daemon code, always stop the running service before rebuilding:

```bash
systemctl stop cloudllm-daemon
dart compile exe bin/server.dart -o daemon
systemctl start cloudllm-daemon
systemctl status cloudllm-daemon
```

## Full Stack Deployment via Daemon

To deploy all major services (FusionAuth, webapp, monitoring, tunnel/cloud, etc.) in one go, use the daemon's API:

```bash
curl -X POST http://localhost:9001/admin/deploy/all
```

This will:
- Start FusionAuth and its database
- Start the webapp
- Start monitoring services
- Start tunnel/cloud services

Check logs and container status as needed:
```bash
journalctl -u cloudllm-daemon -f
docker ps
```

## Troubleshooting: Docker Build Context and nginx.conf

When deploying the webapp service, the Docker build context is set to the project root. The Dockerfile expects `config/nginx/nginx.conf` to exist relative to this root. If you see errors like:

```
failed to solve: failed to compute cache key: failed to calculate checksum ...: "/nginx.conf": not found
```

Make sure that `config/nginx/nginx.conf` exists at the correct path (e.g., `/opt/cloudtolocalllm/config/nginx/nginx.conf` on your server). If you move or rename files, update the Dockerfile or build context accordingly. 