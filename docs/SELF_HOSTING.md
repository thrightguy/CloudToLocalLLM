# Self-Hosting CloudToLocalLLM

This document provides instructions and considerations for self-hosting the CloudToLocalLLM application stack.

## SSL Configuration

The CloudToLocalLLM VPS deployment, specifically the `webapp` service, handles SSL termination. Here's an overview of the SSL strategy (see `docs/DEPLOYMENT.MD` for full details):

1.  **Self-Signed Certificates (Initial Default for `webapp` container)**:
    *   For ease of initial setup, the `webapp` Docker image is configured to generate and use self-signed SSL certificates by default.
    *   This allows the service to start up with HTTPS immediately without external dependencies.
    *   Browsers will show a warning for self-signed certificates; this is expected for local development or if you haven't configured a public certificate yet.

2.  **Let's Encrypt (Recommended for Public Servers)**:
    *   Free, automated certificates from Let's Encrypt.
    *   Requires your domain to be correctly pointed to your VPS.
    *   The `docs/DEPLOYMENT.MD` guide explains how to configure the system to use Let's Encrypt, typically involving the `certbot-service`.

3.  **Commercial/Wildcard SSL Certificates**:
    *   Suitable for production environments, especially with multiple subdomains.
    *   Covers all subdomains (e.g., `*.cloudtolocalllm.online`).
    *   Requires purchasing a certificate and configuring Nginx to use it (see `docs/DEPLOYMENT.MD`).

See [DEPLOYMENT.MD](docs/DEPLOYMENT.md) for detailed SSL configuration instructions.

## 🛠️ Prerequisites

- Flutter SDK (3.0.0 or higher recommended)
- Dart SDK (3.0.0 or higher recommended)
- (Optional) Ollama or LM Studio installed locally. Ollama can be installed via its desktop application (Windows, macOS, Linux) or run via Docker. For server/VPS deployments, ensure Ollama is not directly exposed to the internet without proper security measures.

## 🚀 Installation

1. Clone the repository:
   ```
   git clone https://github.com/thrightguy/CloudToLocalLLM.git
   ```

2. Navigate to the project directory:
   ```
   cd CloudToLocalLLM
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Run the application (for local development/testing):
   ```
   flutter run
   ```
   For server deployment, refer to the Docker-based setup in other sections of this guide (e.g., using `scripts/setup/docker_startup_vps.sh`).

## Static Portal Files (REVIEW: Is this still the process, or are all static assets part of the Flutter web build in the webapp container?)

To update the static portal files (e.g., `index.html`, `login.html`, `theme.css`):

1.  **Upload changed files to the VPS:**
    Replace `~/.ssh/id_rsa` with the path to your SSH key if different.
    ```bash
    scp -i ~/.ssh/id_rsa index.html root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/index.html
    scp -i ~/.ssh/id_rsa login.html root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/login.html
    scp -i ~/.ssh/id_rsa css/theme.css root@cloudtolocalllm.online:/opt/cloudtolocalllm/portal/css/theme.css
    ```

    > ⚠️ **Do NOT copy files directly into the container.**
    > Any files placed in `/usr/share/nginx/html` inside the container will be overwritten by the contents of `/opt/cloudtolocalllm/portal/` on the host.

    No container restart is needed for static file changes.

## Advanced Deployment Topics

### Dart Deployment Tool (REVIEW: Is this tool (`tools/deploy.dart`) still maintained/used or replaced by `admin_control_daemon` + `docker_startup_vps.sh`?)

(This section describes a potentially deprecated Dart-based deployment tool. Modern deployments likely use `admin_control_daemon` and `scripts/setup/docker_startup_vps.sh` as detailed in `docs/DEPLOYMENT.md` and `docs/VPS_DEPLOYMENT.md`.)

We provide a unified Dart-based tool for deploying and managing the CloudToLocalLLM portal:

```bash
# Install dependencies
dart pub add args path

# Deploy with default configuration
dart tools/deploy.dart deploy
# ... (other commands from original README) ...
dart tools/deploy.dart --help
```

Using this tool eliminates the need for multiple shell scripts and provides a consistent deployment process. 