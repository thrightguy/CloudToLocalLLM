/**
 * Deployment Manager for CloudToLocalLLM CI/CD Agent
 * Integrates with existing VPS deployment scripts and infrastructure
 */

const { spawn, exec } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const util = require('util');

const execAsync = util.promisify(exec);

class DeploymentManager {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger;
    this.projectRoot = config.projectRoot;
  }

  /**
   * Deploy to VPS using existing deployment scripts
   */
  async deployToVPS(buildConfig, buildResult) {
    const { id } = buildConfig;
    
    this.logger.info(`Starting VPS deployment for build ${id}`);

    const deployResult = {
      success: false,
      logs: [],
      startTime: new Date(),
      endTime: null,
      duration: null,
      services: {},
      healthChecks: {}
    };

    try {
      // Pre-deployment checks
      await this.preDeploymentChecks(deployResult);

      // Execute deployment using existing scripts
      await this.executeVPSDeployment(deployResult, buildConfig);

      // Post-deployment verification
      await this.postDeploymentVerification(deployResult);

      deployResult.success = true;
      deployResult.endTime = new Date();
      deployResult.duration = deployResult.endTime - deployResult.startTime;

      this.logger.info(`VPS deployment completed successfully for build ${id}`, {
        duration: deployResult.duration
      });

      return deployResult;

    } catch (error) {
      this.logger.error(`VPS deployment failed for build ${id}:`, error);
      deployResult.success = false;
      deployResult.error = error.message;
      deployResult.endTime = new Date();
      deployResult.duration = deployResult.endTime - deployResult.startTime;
      
      return deployResult;
    }
  }

  /**
   * Pre-deployment checks
   */
  async preDeploymentChecks(deployResult) {
    this.logger.info('Performing pre-deployment checks');

    // Check if we're in the correct directory
    if (!await fs.pathExists(path.join(this.projectRoot, 'pubspec.yaml'))) {
      throw new Error('Not in CloudToLocalLLM project directory');
    }

    // Check if deployment script exists
    const deployScript = path.join(this.projectRoot, 'scripts/deploy/update_and_deploy.sh');
    if (!await fs.pathExists(deployScript)) {
      throw new Error('Deployment script not found');
    }

    // Check Docker availability
    try {
      await this.executeCommand('docker', ['--version']);
      deployResult.logs.push('Docker is available');
    } catch (error) {
      throw new Error('Docker is not available');
    }

    // Check Flutter build output
    const webBuildPath = path.join(this.projectRoot, 'build/web');
    if (!await fs.pathExists(webBuildPath)) {
      throw new Error('Flutter web build not found');
    }

    deployResult.logs.push('Pre-deployment checks passed');
    this.logger.info('Pre-deployment checks completed successfully');
  }

  /**
   * Execute VPS deployment using existing scripts
   */
  async executeVPSDeployment(deployResult, buildConfig) {
    this.logger.info('Executing VPS deployment');

    // Change to project directory
    process.chdir(this.projectRoot);

    // Create backup before deployment
    await this.createDeploymentBackup(deployResult);

    // Use existing deployment script with force flag for automation
    const deployScript = path.join(this.projectRoot, 'scripts/deploy/update_and_deploy.sh');
    const deployArgs = ['--force', '--verbose'];

    this.logger.info(`Executing deployment script: ${deployScript}`);
    
    const deploymentResult = await this.executeCommand('bash', [deployScript, ...deployArgs]);
    deployResult.logs.push(deploymentResult.stdout);

    // Check if deployment script succeeded
    if (deploymentResult.code !== 0) {
      throw new Error(`Deployment script failed with exit code ${deploymentResult.code}`);
    }

    this.logger.info('VPS deployment script completed successfully');
  }

  /**
   * Create deployment backup
   */
  async createDeploymentBackup(deployResult) {
    this.logger.info('Creating deployment backup');

    try {
      // Use existing backup functionality if available
      const backupScript = path.join(this.projectRoot, 'scripts/backup/create_backup.sh');
      
      if (await fs.pathExists(backupScript)) {
        const backupResult = await this.executeCommand('bash', [backupScript]);
        deployResult.logs.push(`Backup created: ${backupResult.stdout}`);
      } else {
        // Fallback: create simple backup
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupDir = path.join(this.projectRoot, 'backups', `deployment-${timestamp}`);
        
        await fs.ensureDir(backupDir);
        
        // Backup critical files
        const filesToBackup = [
          'docker-compose.yml',
          'docker-compose.multi.yml',
          'build/web',
          'config/nginx'
        ];

        for (const file of filesToBackup) {
          const sourcePath = path.join(this.projectRoot, file);
          const targetPath = path.join(backupDir, file);
          
          if (await fs.pathExists(sourcePath)) {
            await fs.copy(sourcePath, targetPath);
          }
        }

        deployResult.logs.push(`Manual backup created: ${backupDir}`);
      }

      this.logger.info('Deployment backup completed');
    } catch (error) {
      this.logger.warn('Backup creation failed, continuing with deployment:', error);
      deployResult.logs.push(`Backup warning: ${error.message}`);
    }
  }

  /**
   * Post-deployment verification
   */
  async postDeploymentVerification(deployResult) {
    this.logger.info('Performing post-deployment verification');

    // Check Docker containers
    await this.verifyDockerContainers(deployResult);

    // Check web application accessibility
    await this.verifyWebApplication(deployResult);

    // Check API backend
    await this.verifyAPIBackend(deployResult);

    // Check SSL certificates
    await this.verifySSLCertificates(deployResult);

    this.logger.info('Post-deployment verification completed');
  }

  /**
   * Verify Docker containers are running
   */
  async verifyDockerContainers(deployResult) {
    this.logger.info('Verifying Docker containers');

    try {
      const containerResult = await this.executeCommand('docker', ['ps', '--format', 'table {{.Names}}\t{{.Status}}']);
      deployResult.logs.push(`Container status:\n${containerResult.stdout}`);

      // Check for expected containers
      const expectedContainers = [
        'cloudtolocalllm-nginx-proxy',
        'cloudtolocalllm-flutter-app',
        'cloudtolocalllm-api-backend'
      ];

      const runningContainers = containerResult.stdout;
      
      for (const container of expectedContainers) {
        if (runningContainers.includes(container)) {
          deployResult.services[container] = 'running';
          this.logger.debug(`Container ${container} is running`);
        } else {
          deployResult.services[container] = 'not_found';
          this.logger.warn(`Container ${container} not found`);
        }
      }

    } catch (error) {
      this.logger.error('Docker container verification failed:', error);
      deployResult.logs.push(`Container check error: ${error.message}`);
    }
  }

  /**
   * Verify web application accessibility
   */
  async verifyWebApplication(deployResult) {
    this.logger.info('Verifying web application accessibility');

    const endpoints = [
      'http://localhost:80',
      'https://cloudtolocalllm.online',
      'https://app.cloudtolocalllm.online'
    ];

    for (const endpoint of endpoints) {
      try {
        const curlResult = await this.executeCommand('curl', [
          '-s', '-o', '/dev/null', '-w', '%{http_code}',
          '--max-time', '10',
          endpoint
        ]);

        const statusCode = curlResult.stdout.trim();
        deployResult.healthChecks[endpoint] = {
          status: statusCode,
          accessible: statusCode.startsWith('2') || statusCode.startsWith('3')
        };

        this.logger.debug(`${endpoint}: HTTP ${statusCode}`);
      } catch (error) {
        deployResult.healthChecks[endpoint] = {
          status: 'error',
          accessible: false,
          error: error.message
        };
        this.logger.warn(`Failed to check ${endpoint}:`, error.message);
      }
    }
  }

  /**
   * Verify API backend
   */
  async verifyAPIBackend(deployResult) {
    this.logger.info('Verifying API backend');

    try {
      const healthEndpoint = 'http://localhost:8080/health';
      const healthResult = await this.executeCommand('curl', [
        '-s', '--max-time', '10', healthEndpoint
      ]);

      deployResult.healthChecks.apiBackend = {
        status: 'healthy',
        response: healthResult.stdout
      };

      this.logger.debug('API backend health check passed');
    } catch (error) {
      deployResult.healthChecks.apiBackend = {
        status: 'unhealthy',
        error: error.message
      };
      this.logger.warn('API backend health check failed:', error.message);
    }
  }

  /**
   * Verify SSL certificates
   */
  async verifySSLCertificates(deployResult) {
    this.logger.info('Verifying SSL certificates');

    const domains = ['cloudtolocalllm.online', 'app.cloudtolocalllm.online'];

    for (const domain of domains) {
      try {
        const certResult = await this.executeCommand('openssl', [
          's_client', '-connect', `${domain}:443`,
          '-servername', domain,
          '-verify_return_error'
        ], { timeout: 10000 });

        deployResult.healthChecks[`ssl_${domain}`] = {
          status: 'valid',
          details: 'Certificate verification passed'
        };

        this.logger.debug(`SSL certificate for ${domain} is valid`);
      } catch (error) {
        deployResult.healthChecks[`ssl_${domain}`] = {
          status: 'invalid',
          error: error.message
        };
        this.logger.warn(`SSL certificate check failed for ${domain}:`, error.message);
      }
    }
  }

  /**
   * Execute command with proper error handling
   */
  async executeCommand(command, args = [], options = {}) {
    return new Promise((resolve, reject) => {
      const fullCommand = `${command} ${args.join(' ')}`;
      this.logger.debug(`Executing: ${fullCommand}`);

      const child = spawn(command, args, {
        cwd: options.cwd || this.projectRoot,
        stdio: ['pipe', 'pipe', 'pipe'],
        ...options
      });

      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => {
        const output = data.toString();
        stdout += output;
        this.logger.debug(`[${command}] ${output.trim()}`);
      });

      child.stderr.on('data', (data) => {
        const output = data.toString();
        stderr += output;
        this.logger.debug(`[${command}] ERROR: ${output.trim()}`);
      });

      child.on('close', (code) => {
        if (code === 0) {
          resolve({ stdout, stderr, code });
        } else {
          const error = new Error(`Command failed: ${fullCommand}\nExit code: ${code}\nStderr: ${stderr}`);
          error.code = code;
          error.stdout = stdout;
          error.stderr = stderr;
          reject(error);
        }
      });

      child.on('error', (error) => {
        this.logger.error(`Command execution error: ${fullCommand}`, error);
        reject(error);
      });

      // Set timeout
      const timeout = setTimeout(() => {
        child.kill('SIGTERM');
        reject(new Error(`Command timeout: ${fullCommand}`));
      }, options.timeout || 300000); // 5 minutes default

      child.on('close', () => {
        clearTimeout(timeout);
      });
    });
  }

  /**
   * Rollback deployment if needed
   */
  async rollbackDeployment(backupPath) {
    this.logger.info(`Rolling back deployment from backup: ${backupPath}`);

    try {
      // Stop current containers
      await this.executeCommand('docker', ['compose', 'down']);

      // Restore from backup
      if (await fs.pathExists(backupPath)) {
        await fs.copy(backupPath, this.projectRoot, { overwrite: true });
      }

      // Restart containers
      await this.executeCommand('docker', ['compose', 'up', '-d']);

      this.logger.info('Deployment rollback completed');
      return { success: true };
    } catch (error) {
      this.logger.error('Deployment rollback failed:', error);
      return { success: false, error: error.message };
    }
  }
}

module.exports = DeploymentManager;
