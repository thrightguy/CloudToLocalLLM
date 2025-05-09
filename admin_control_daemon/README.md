# Admin Control Daemon

This daemon manages and monitors the CloudToLocalLLM stack.

## Container Base Image

- The admin daemon container uses the [ghcr.io/cirruslabs/flutter:latest](https://github.com/cirruslabs/docker-images-flutter) image as its base.
- **Flutter and Dart are available everywhere** in the stack for maximum compatibility.
- The admin daemon container also installs the Docker CLI and Compose plugin for service management.

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
   systemctl enable cloudllm-daemon
   systemctl start cloudllm-daemon
   ```

## Running with Docker (Recommended)

- The Docker container is built from the same Flutter image as the rest of the stack.
- The container includes Docker CLI and Compose for managing other services.

See the main documentation for details on Docker-based deployment.

## Troubleshooting

- If you see errors about `docker compose` or `docker-compose` not found, ensure the container is built from the latest code and the CLI plugins are installed (see Dockerfile).

## Using the cloudctl Command (Recommended)

The `cloudctl` command provides a convenient way to manage the daemon and services:

```bash
# Start the daemon and all services
cloudctl start

# Stop the daemon and all services
cloudctl stop

# Restart the daemon and all services
cloudctl restart

# Check the status
cloudctl status

# View logs for specific components
cloudctl logs auth    # Auth service logs
cloudctl logs web     # Web service logs
cloudctl logs admin   # Admin UI logs
cloudctl logs db      # Database logs

# Update and restart
cloudctl update
```

## Safe Rebuild and Restart of the Daemon

Whenever you update the daemon code, always stop the running service before rebuilding:

```bash
systemctl stop cloudllm-daemon
dart compile exe bin/server.dart -o daemon
systemctl start cloudllm-daemon
systemctl status cloudllm-daemon
```

## VPS Startup Script

To fully rebuild and restart the daemon on a VPS:

```bash
# Run as root
sudo bash scripts/setup/startup_vps.sh
```

This script will:
1. Stop the daemon if it's running
2. Rebuild the daemon from source
3. Start the daemon
4. Trigger a full stack deployment

## API Endpoints

The daemon exposes the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| /admin/health | GET | Check daemon health |
| /admin/deploy/all | POST | Deploy all services |
| /admin/deploy/web | POST | Deploy web service |
| /admin/deploy/fusionauth | POST | Deploy FusionAuth |
| /admin/git/pull | POST | Pull latest code from Git |
| /admin/stop/web | POST | Stop web service |
| /admin/stop/fusionauth | POST | Stop FusionAuth |
| /admin/ssl/issue-renew | POST | Issue/renew SSL certificates |

Example usage:
```bash
# Deploy all components
curl -X POST http://localhost:9001/admin/deploy/all

# Check daemon health
curl http://localhost:9001/admin/health
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

## Container Coordination

The admin control daemon helps ensure all containers work together properly. The deployment process:

1. Starts services in the correct order to respect dependencies
2. Ensures proper networking between containers via the `cloudllm-network` Docker network
3. Handles volume mounting for persistent data
4. Manages environment variables for inter-service communication

Common container coordination issues:
- If services can't reach each other, check the Docker network with `docker network inspect cloudllm-network`
- For volume permissions issues, verify user permissions in the container and host
- For timing issues, the daemon handles restart/retry logic for interdependent services

## Troubleshooting: Docker Build Context and nginx.conf

When deploying the webapp service, the Docker build context is set to the project root. The Dockerfile expects `config/nginx/nginx.conf` to exist relative to this root. If you see errors like:

```
failed to solve: failed to compute cache key: failed to calculate checksum ...: "/nginx.conf": not found
```

Make sure that `config/nginx/nginx.conf` exists at the correct path (e.g., `/opt/cloudtolocalllm/config/nginx/nginx.conf` on your server). If you move or rename files, update the Dockerfile or build context accordingly.

## Troubleshooting: Docker Compose Flag Error

If you see an error like:

```
unknown shorthand flag: 'f' in -f
See 'docker --help'.
```

This means the daemon is running `docker -f ...` instead of `docker compose -f ...`. **You must use `docker compose` (with a space), not `docker` alone, for service management.**

The code should always invoke:

```
docker compose -f ...
```

and never:

```
docker -f ...
```

## Improved Error Handling and Troubleshooting

- The admin daemon and startup script now provide detailed error output and logs if any service fails to start or is unhealthy.
- If a deployment fails, the API and script will print the error and recent logs for the affected containers.
- You can check the admin daemon logs with:
  ```bash
  docker logs docker-admin-daemon-1
  ```
- For individual service logs, use:
  ```bash
  docker logs <container-name>
  ```

If you need to provide errors for support, copy the output from the script and the relevant logs. 