#!/usr/bin/env node

/**
 * CloudToLocalLLM CI/CD Agent
 * Automated build and deployment system for CloudToLocalLLM
 * 
 * Features:
 * - GitHub webhook integration
 * - Multi-platform build orchestration
 * - Integration with existing deployment scripts
 * - Build status monitoring and notifications
 * - Web dashboard for monitoring
 */

const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const fs = require('fs-extra');
const path = require('path');
const winston = require('winston');
const cron = require('node-cron');
const WebSocket = require('ws');
const axios = require('axios');
const helmet = require('helmet');
const cors = require('cors');
require('dotenv').config();

const BuildOrchestrator = require('./src/build-orchestrator');
const DeploymentManager = require('./src/deployment-manager');
const NotificationService = require('./src/notification-service');
const WebDashboard = require('./src/web-dashboard');
const SecurityManager = require('./src/security-manager');

// Configuration
const CONFIG = {
  port: process.env.CICD_PORT || 3001,
  projectRoot: process.env.PROJECT_ROOT || '/opt/cloudtolocalllm',
  githubSecret: process.env.GITHUB_WEBHOOK_SECRET,
  githubRepo: 'imrightguy/CloudToLocalLLM',
  buildTimeout: parseInt(process.env.BUILD_TIMEOUT) || 3600000, // 1 hour
  maxConcurrentBuilds: parseInt(process.env.MAX_CONCURRENT_BUILDS) || 2,
  enableNotifications: process.env.ENABLE_NOTIFICATIONS !== 'false',
  logLevel: process.env.LOG_LEVEL || 'info',
  environment: process.env.NODE_ENV || 'production'
};

// Logger setup
const logger = winston.createLogger({
  level: CONFIG.logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'cicd-agent' },
  transports: [
    new winston.transports.File({ 
      filename: path.join(CONFIG.projectRoot, 'logs/cicd-error.log'), 
      level: 'error' 
    }),
    new winston.transports.File({ 
      filename: path.join(CONFIG.projectRoot, 'logs/cicd-combined.log') 
    }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Express app setup
const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: ['https://cloudtolocalllm.online', 'https://app.cloudtolocalllm.online'],
  credentials: true
}));

// Body parser with webhook signature verification
app.use('/webhook', bodyParser.raw({ type: 'application/json' }));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Initialize services
const buildOrchestrator = new BuildOrchestrator(CONFIG, logger);
const deploymentManager = new DeploymentManager(CONFIG, logger);
const notificationService = new NotificationService(CONFIG, logger);
const webDashboard = new WebDashboard(CONFIG, logger);
const securityManager = new SecurityManager(CONFIG, logger);

// Build state management
const buildState = {
  currentBuilds: new Map(),
  buildHistory: [],
  buildQueue: [],
  isProcessing: false
};

// Webhook signature verification
function verifyGitHubSignature(payload, signature) {
  if (!CONFIG.githubSecret) {
    logger.warn('GitHub webhook secret not configured');
    return true; // Allow in development
  }

  const hmac = crypto.createHmac('sha256', CONFIG.githubSecret);
  const digest = 'sha256=' + hmac.update(payload).digest('hex');
  
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'utf8'),
    Buffer.from(digest, 'utf8')
  );
}

// GitHub webhook handler
app.post('/webhook', async (req, res) => {
  try {
    const signature = req.get('X-Hub-Signature-256');
    const event = req.get('X-GitHub-Event');
    
    if (!verifyGitHubSignature(req.body, signature)) {
      logger.error('Invalid webhook signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const payload = JSON.parse(req.body.toString());
    
    logger.info(`Received GitHub webhook: ${event}`, {
      repository: payload.repository?.full_name,
      ref: payload.ref,
      commits: payload.commits?.length
    });

    // Handle push events to master branch
    if (event === 'push' && payload.ref === 'refs/heads/master') {
      await handlePushEvent(payload);
    }

    // Handle pull request events
    if (event === 'pull_request') {
      await handlePullRequestEvent(payload);
    }

    res.status(200).json({ status: 'received' });
  } catch (error) {
    logger.error('Webhook processing error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Handle push events (trigger full build and deployment)
async function handlePushEvent(payload) {
  const buildId = generateBuildId();
  const commitSha = payload.head_commit.id;
  const commitMessage = payload.head_commit.message;
  const author = payload.head_commit.author.name;

  logger.info(`Triggering build for push event`, {
    buildId,
    commitSha: commitSha.substring(0, 8),
    author,
    message: commitMessage
  });

  const buildConfig = {
    id: buildId,
    trigger: 'push',
    repository: payload.repository.full_name,
    branch: 'master',
    commitSha,
    commitMessage,
    author,
    timestamp: new Date().toISOString(),
    platforms: ['web', 'windows', 'linux'],
    deployToVPS: true,
    createRelease: true
  };

  await queueBuild(buildConfig);
}

// Handle pull request events (trigger test builds)
async function handlePullRequestEvent(payload) {
  if (payload.action !== 'opened' && payload.action !== 'synchronize') {
    return;
  }

  const buildId = generateBuildId();
  const commitSha = payload.pull_request.head.sha;
  const prNumber = payload.pull_request.number;

  logger.info(`Triggering test build for PR #${prNumber}`, {
    buildId,
    commitSha: commitSha.substring(0, 8)
  });

  const buildConfig = {
    id: buildId,
    trigger: 'pull_request',
    repository: payload.repository.full_name,
    branch: payload.pull_request.head.ref,
    commitSha,
    commitMessage: payload.pull_request.title,
    author: payload.pull_request.user.login,
    timestamp: new Date().toISOString(),
    platforms: ['web'], // Only web build for PRs
    deployToVPS: false,
    createRelease: false,
    pullRequest: prNumber
  };

  await queueBuild(buildConfig);
}

// Queue build for processing
async function queueBuild(buildConfig) {
  buildState.buildQueue.push(buildConfig);
  
  logger.info(`Build queued: ${buildConfig.id}`, {
    queueLength: buildState.buildQueue.length,
    currentBuilds: buildState.currentBuilds.size
  });

  await notificationService.sendBuildQueued(buildConfig);
  
  // Process queue if not already processing
  if (!buildState.isProcessing) {
    processQueue();
  }
}

// Process build queue
async function processQueue() {
  if (buildState.isProcessing || buildState.buildQueue.length === 0) {
    return;
  }

  if (buildState.currentBuilds.size >= CONFIG.maxConcurrentBuilds) {
    logger.info('Max concurrent builds reached, waiting...');
    return;
  }

  buildState.isProcessing = true;

  try {
    const buildConfig = buildState.buildQueue.shift();
    await startBuild(buildConfig);
  } catch (error) {
    logger.error('Queue processing error:', error);
  } finally {
    buildState.isProcessing = false;
    
    // Continue processing if more builds in queue
    if (buildState.buildQueue.length > 0) {
      setTimeout(processQueue, 1000);
    }
  }
}

// Start build process
async function startBuild(buildConfig) {
  const { id } = buildConfig;
  
  logger.info(`Starting build: ${id}`);
  
  buildState.currentBuilds.set(id, {
    ...buildConfig,
    status: 'running',
    startTime: new Date(),
    logs: []
  });

  try {
    await notificationService.sendBuildStarted(buildConfig);
    
    // Execute build orchestration
    const buildResult = await buildOrchestrator.executeBuild(buildConfig);
    
    // Update build state
    const build = buildState.currentBuilds.get(id);
    build.status = buildResult.success ? 'success' : 'failed';
    build.endTime = new Date();
    build.duration = build.endTime - build.startTime;
    build.result = buildResult;

    // Move to history
    buildState.buildHistory.unshift(build);
    buildState.currentBuilds.delete(id);

    // Keep only last 100 builds in history
    if (buildState.buildHistory.length > 100) {
      buildState.buildHistory = buildState.buildHistory.slice(0, 100);
    }

    logger.info(`Build completed: ${id}`, {
      status: build.status,
      duration: build.duration
    });

    await notificationService.sendBuildCompleted(build);

    // Deploy if successful and configured
    if (buildResult.success && buildConfig.deployToVPS) {
      await deployToVPS(buildConfig, buildResult);
    }

  } catch (error) {
    logger.error(`Build failed: ${id}`, error);
    
    const build = buildState.currentBuilds.get(id);
    if (build) {
      build.status = 'failed';
      build.endTime = new Date();
      build.duration = build.endTime - build.startTime;
      build.error = error.message;

      buildState.buildHistory.unshift(build);
      buildState.currentBuilds.delete(id);

      await notificationService.sendBuildFailed(build, error);
    }
  }

  // Continue processing queue
  setTimeout(processQueue, 1000);
}

// Deploy to VPS
async function deployToVPS(buildConfig, buildResult) {
  logger.info(`Starting VPS deployment for build: ${buildConfig.id}`);
  
  try {
    const deployResult = await deploymentManager.deployToVPS(buildConfig, buildResult);
    
    if (deployResult.success) {
      logger.info(`VPS deployment successful: ${buildConfig.id}`);
      await notificationService.sendDeploymentSuccess(buildConfig, deployResult);
    } else {
      logger.error(`VPS deployment failed: ${buildConfig.id}`, deployResult.error);
      await notificationService.sendDeploymentFailed(buildConfig, deployResult.error);
    }
  } catch (error) {
    logger.error(`VPS deployment error: ${buildConfig.id}`, error);
    await notificationService.sendDeploymentFailed(buildConfig, error);
  }
}

// Generate unique build ID
function generateBuildId() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const random = Math.random().toString(36).substring(2, 8);
  return `build-${timestamp}-${random}`;
}

// API endpoints for dashboard
app.get('/api/status', (req, res) => {
  res.json({
    status: 'running',
    currentBuilds: Array.from(buildState.currentBuilds.values()),
    queueLength: buildState.buildQueue.length,
    recentBuilds: buildState.buildHistory.slice(0, 10),
    uptime: process.uptime(),
    version: require('./package.json').version
  });
});

app.get('/api/builds', (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;
  const start = (page - 1) * limit;
  const end = start + limit;

  res.json({
    builds: buildState.buildHistory.slice(start, end),
    total: buildState.buildHistory.length,
    page,
    limit
  });
});

app.get('/api/builds/:id', (req, res) => {
  const { id } = req.params;
  const build = buildState.currentBuilds.get(id) || 
                buildState.buildHistory.find(b => b.id === id);
  
  if (!build) {
    return res.status(404).json({ error: 'Build not found' });
  }

  res.json(build);
});

// Manual trigger endpoint
app.post('/api/trigger', securityManager.authenticate, async (req, res) => {
  try {
    const { platforms = ['web'], deployToVPS = false, createRelease = false } = req.body;
    
    const buildConfig = {
      id: generateBuildId(),
      trigger: 'manual',
      repository: CONFIG.githubRepo,
      branch: 'master',
      commitSha: 'HEAD',
      commitMessage: 'Manual trigger',
      author: req.user?.name || 'System',
      timestamp: new Date().toISOString(),
      platforms,
      deployToVPS,
      createRelease
    };

    await queueBuild(buildConfig);
    
    res.json({ 
      success: true, 
      buildId: buildConfig.id,
      message: 'Build queued successfully'
    });
  } catch (error) {
    logger.error('Manual trigger error:', error);
    res.status(500).json({ error: 'Failed to trigger build' });
  }
});

// Serve web dashboard
app.use('/', webDashboard.router);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error('Express error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start server
const server = app.listen(CONFIG.port, () => {
  logger.info(`CI/CD Agent started on port ${CONFIG.port}`, {
    environment: CONFIG.environment,
    projectRoot: CONFIG.projectRoot,
    maxConcurrentBuilds: CONFIG.maxConcurrentBuilds
  });
});

// Cleanup on exit
process.on('exit', () => {
  logger.info('CI/CD Agent shutting down');
});

module.exports = { app, server, buildState };
