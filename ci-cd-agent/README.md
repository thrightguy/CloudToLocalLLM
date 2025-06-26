# CloudToLocalLLM CI/CD Agent

A comprehensive CI/CD automation system for the CloudToLocalLLM project that provides automated build and deployment capabilities.

## Features

- **GitHub Webhook Integration** - Automatically triggers builds on code changes
- **Multi-Platform Builds** - Supports Flutter web, Windows desktop, and Linux packages
- **VPS Deployment** - Integrates with existing deployment scripts
- **Build Monitoring** - Web dashboard for monitoring builds and deployments
- **Notifications** - Email, Slack, Discord, and webhook notifications
- **Security** - API key authentication, rate limiting, and input validation
- **Rollback Support** - Automatic backup and rollback capabilities

## Architecture

The CI/CD agent consists of several components:

- **Webhook Receiver** - Handles GitHub webhooks and triggers builds
- **Build Orchestrator** - Manages multi-platform builds using existing scripts
- **Deployment Manager** - Integrates with VPS deployment infrastructure
- **Notification Service** - Sends build status notifications
- **Web Dashboard** - Provides monitoring and management interface
- **Security Manager** - Handles authentication and security

## Installation

### Prerequisites

- Node.js 18+
- Docker and Docker Compose
- Git access to the CloudToLocalLLM repository
- Flutter SDK (for builds)

### Setup

1. **Clone and navigate to the CI/CD agent directory:**
   ```bash
   cd /opt/cloudtolocalllm/ci-cd-agent
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Start the service:**
   ```bash
   # Development
   npm run dev
   
   # Production with Docker
   docker-compose up -d
   ```

## Configuration

### Environment Variables

Key configuration options in `.env`:

```bash
# Basic Configuration
NODE_ENV=production
CICD_PORT=3001
PROJECT_ROOT=/opt/cloudtolocalllm

# GitHub Configuration
GITHUB_WEBHOOK_SECRET=your_webhook_secret
GITHUB_TOKEN=your_github_token

# Security
CICD_API_KEYS=your_api_key_here
JWT_SECRET=your_jwt_secret

# Notifications
SMTP_HOST=smtp.gmail.com
SMTP_USER=your_email@gmail.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```

### GitHub Webhook Setup

1. Go to your GitHub repository settings
2. Navigate to Webhooks
3. Add a new webhook:
   - **Payload URL**: `https://your-vps.com:3001/webhook`
   - **Content type**: `application/json`
   - **Secret**: Your webhook secret from `.env`
   - **Events**: Select "Push" and "Pull requests"

## Usage

### Web Dashboard

Access the web dashboard at `http://your-vps:3001` to:

- Monitor current and recent builds
- View build logs and details
- Trigger manual builds
- Check system status

### API Endpoints

- `POST /webhook` - GitHub webhook receiver
- `GET /api/status` - System status
- `GET /api/builds` - List builds
- `POST /api/trigger` - Manual build trigger
- `GET /health` - Health check

### Manual Build Trigger

```bash
curl -X POST http://your-vps:3001/api/trigger \
  -H "X-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "platforms": ["web", "linux"],
    "deployToVPS": true,
    "createRelease": false
  }'
```

## Integration with Existing Infrastructure

The CI/CD agent integrates seamlessly with the existing CloudToLocalLLM infrastructure:

### Build Scripts
- Uses existing `scripts/flutter_build_with_timestamp.sh`
- Leverages `scripts/build_unified_package.sh`
- Integrates with `scripts/create_aur_binary_package.sh`

### Deployment Scripts
- Uses `scripts/deploy/update_and_deploy.sh`
- Preserves existing Docker Compose setup
- Maintains current backup procedures

### Version Management
- Integrates with `scripts/version_manager.sh`
- Preserves timestamp injection system
- Maintains GitHub release workflow

## Build Process

When a push to master is detected:

1. **Webhook Reception** - GitHub webhook triggers the build
2. **Environment Preparation** - Git pull, Flutter clean, dependencies
3. **Multi-Platform Builds**:
   - **Web**: Flutter web build with timestamp injection
   - **Windows**: Docker container with PowerShell scripts
   - **Linux**: Native builds with AUR package creation
4. **VPS Deployment** - Uses existing deployment scripts
5. **Verification** - Health checks and service validation
6. **Notifications** - Status updates via configured channels

## Monitoring and Logging

### Logs
- Application logs: `/opt/cloudtolocalllm/logs/cicd-combined.log`
- Error logs: `/opt/cloudtolocalllm/logs/cicd-error.log`
- Build logs: Stored per build in the system

### Health Checks
- Service health: `GET /health`
- Container health: Docker health checks
- Build status: Web dashboard

### Notifications
- Build started/completed/failed
- Deployment success/failure
- System alerts and errors

## Security

### Authentication
- API key authentication for manual triggers
- JWT token support for web dashboard
- GitHub webhook signature verification

### Rate Limiting
- API endpoint rate limiting
- IP-based access control
- Request validation and sanitization

### Access Control
- Non-root container execution
- Limited file system access
- Secure environment variable handling

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check Flutter SDK installation
   - Verify Docker access
   - Review build logs in dashboard

2. **Deployment Issues**
   - Ensure SSH keys are properly mounted
   - Check VPS connectivity
   - Verify existing deployment scripts

3. **Webhook Issues**
   - Verify webhook secret configuration
   - Check GitHub webhook delivery logs
   - Ensure port 3001 is accessible

### Debug Mode

Enable debug logging:
```bash
LOG_LEVEL=debug npm start
```

## Development

### Running in Development

```bash
npm run dev
```

### Testing

```bash
npm test
```

### Contributing

1. Create a feature branch
2. Make your changes
3. Add tests if applicable
4. Submit a pull request

## License

This CI/CD agent is part of the CloudToLocalLLM project and follows the same license terms.
