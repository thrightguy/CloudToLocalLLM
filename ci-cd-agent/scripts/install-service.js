#!/usr/bin/env node

/**
 * CloudToLocalLLM CI/CD Agent Service Installer
 * Installs the CI/CD agent as a systemd service on Linux
 */

const fs = require('fs-extra');
const path = require('path');
const { execSync } = require('child_process');

const SERVICE_NAME = 'cloudtolocalllm-cicd-agent';
const SERVICE_USER = 'cloudllm';
const PROJECT_ROOT = '/opt/cloudtolocalllm';
const AGENT_ROOT = path.join(PROJECT_ROOT, 'ci-cd-agent');

// Colors for output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logInfo(message) {
  log(`[INFO] ${message}`, 'blue');
}

function logSuccess(message) {
  log(`[SUCCESS] ${message}`, 'green');
}

function logWarning(message) {
  log(`[WARNING] ${message}`, 'yellow');
}

function logError(message) {
  log(`[ERROR] ${message}`, 'red');
}

function executeCommand(command, description) {
  try {
    logInfo(`${description}...`);
    execSync(command, { stdio: 'inherit' });
    logSuccess(`${description} completed`);
  } catch (error) {
    logError(`${description} failed: ${error.message}`);
    process.exit(1);
  }
}

function createSystemdService() {
  const serviceContent = `[Unit]
Description=CloudToLocalLLM CI/CD Agent
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${AGENT_ROOT}
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PROJECT_ROOT=${PROJECT_ROOT}

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${PROJECT_ROOT}
ReadWritePaths=/var/log

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
`;

  const servicePath = `/etc/systemd/system/${SERVICE_NAME}.service`;
  
  try {
    logInfo('Creating systemd service file');
    fs.writeFileSync(servicePath, serviceContent);
    logSuccess(`Service file created: ${servicePath}`);
  } catch (error) {
    logError(`Failed to create service file: ${error.message}`);
    process.exit(1);
  }
}

function createLogrotateConfig() {
  const logrotateContent = `${PROJECT_ROOT}/logs/cicd-*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ${SERVICE_USER} ${SERVICE_USER}
    postrotate
        systemctl reload ${SERVICE_NAME} > /dev/null 2>&1 || true
    endscript
}
`;

  const logrotatePath = `/etc/logrotate.d/${SERVICE_NAME}`;
  
  try {
    logInfo('Creating logrotate configuration');
    fs.writeFileSync(logrotatePath, logrotateContent);
    logSuccess(`Logrotate config created: ${logrotatePath}`);
  } catch (error) {
    logWarning(`Failed to create logrotate config: ${error.message}`);
  }
}

function setupDirectories() {
  const directories = [
    path.join(PROJECT_ROOT, 'logs'),
    path.join(AGENT_ROOT, 'logs'),
    path.join(AGENT_ROOT, 'public')
  ];

  for (const dir of directories) {
    try {
      fs.ensureDirSync(dir);
      execSync(`chown ${SERVICE_USER}:${SERVICE_USER} ${dir}`);
      logInfo(`Directory created: ${dir}`);
    } catch (error) {
      logWarning(`Failed to create directory ${dir}: ${error.message}`);
    }
  }
}

function installDependencies() {
  try {
    logInfo('Installing Node.js dependencies');
    process.chdir(AGENT_ROOT);
    execSync('npm ci --only=production', { stdio: 'inherit' });
    logSuccess('Dependencies installed');
  } catch (error) {
    logError(`Failed to install dependencies: ${error.message}`);
    process.exit(1);
  }
}

function setupEnvironment() {
  const envPath = path.join(AGENT_ROOT, '.env');
  const envExamplePath = path.join(AGENT_ROOT, '.env.example');
  
  if (!fs.existsSync(envPath) && fs.existsSync(envExamplePath)) {
    try {
      fs.copyFileSync(envExamplePath, envPath);
      logInfo(`Environment file created: ${envPath}`);
      logWarning('Please edit .env file with your configuration before starting the service');
    } catch (error) {
      logWarning(`Failed to create .env file: ${error.message}`);
    }
  }
}

function checkPrerequisites() {
  logInfo('Checking prerequisites');

  // Check if running as root
  if (process.getuid() !== 0) {
    logError('This script must be run as root (use sudo)');
    process.exit(1);
  }

  // Check if project directory exists
  if (!fs.existsSync(PROJECT_ROOT)) {
    logError(`Project directory not found: ${PROJECT_ROOT}`);
    process.exit(1);
  }

  // Check if agent directory exists
  if (!fs.existsSync(AGENT_ROOT)) {
    logError(`CI/CD agent directory not found: ${AGENT_ROOT}`);
    process.exit(1);
  }

  // Check if service user exists
  try {
    execSync(`id ${SERVICE_USER}`, { stdio: 'ignore' });
  } catch (error) {
    logError(`Service user '${SERVICE_USER}' does not exist`);
    process.exit(1);
  }

  // Check if Node.js is installed
  try {
    execSync('node --version', { stdio: 'ignore' });
  } catch (error) {
    logError('Node.js is not installed');
    process.exit(1);
  }

  // Check if Docker is installed
  try {
    execSync('docker --version', { stdio: 'ignore' });
  } catch (error) {
    logWarning('Docker is not installed - some features may not work');
  }

  logSuccess('Prerequisites check passed');
}

function main() {
  log('CloudToLocalLLM CI/CD Agent Service Installer', 'blue');
  log('==============================================', 'blue');

  checkPrerequisites();
  setupDirectories();
  installDependencies();
  setupEnvironment();
  createSystemdService();
  createLogrotateConfig();

  // Reload systemd and enable service
  executeCommand('systemctl daemon-reload', 'Reloading systemd');
  executeCommand(`systemctl enable ${SERVICE_NAME}`, 'Enabling service');

  logSuccess('CI/CD Agent service installation completed!');
  log('');
  logInfo('Next steps:');
  logInfo(`1. Edit ${path.join(AGENT_ROOT, '.env')} with your configuration`);
  logInfo(`2. Start the service: sudo systemctl start ${SERVICE_NAME}`);
  logInfo(`3. Check status: sudo systemctl status ${SERVICE_NAME}`);
  logInfo(`4. View logs: sudo journalctl -u ${SERVICE_NAME} -f`);
  logInfo('5. Configure GitHub webhook to point to your VPS:3001/webhook');
}

// Handle command line arguments
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
CloudToLocalLLM CI/CD Agent Service Installer

Usage: sudo node install-service.js

This script will:
1. Install Node.js dependencies
2. Create systemd service configuration
3. Setup log rotation
4. Create necessary directories
5. Enable the service

Prerequisites:
- Run as root (sudo)
- CloudToLocalLLM project in ${PROJECT_ROOT}
- User '${SERVICE_USER}' exists
- Node.js installed

Options:
  --help, -h    Show this help message
`);
  process.exit(0);
}

if (require.main === module) {
  main();
}

module.exports = { main };
