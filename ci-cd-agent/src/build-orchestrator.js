/**
 * Build Orchestrator for CloudToLocalLLM CI/CD Agent
 * Manages multi-platform builds using existing scripts and Docker containers
 */

const { spawn, exec } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const util = require('util');

const execAsync = util.promisify(exec);

class BuildOrchestrator {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger;
    this.projectRoot = config.projectRoot;
  }

  /**
   * Execute build process for specified platforms
   */
  async executeBuild(buildConfig) {
    const { id, platforms, commitSha } = buildConfig;
    
    this.logger.info(`Executing build ${id} for platforms: ${platforms.join(', ')}`);

    const buildResult = {
      success: false,
      platforms: {},
      artifacts: {},
      logs: [],
      startTime: new Date(),
      endTime: null,
      duration: null
    };

    try {
      // Prepare build environment
      await this.prepareBuildEnvironment(buildConfig);

      // Execute platform-specific builds
      for (const platform of platforms) {
        this.logger.info(`Building for platform: ${platform}`);
        
        try {
          const platformResult = await this.buildPlatform(platform, buildConfig);
          buildResult.platforms[platform] = platformResult;
          
          if (platformResult.artifacts) {
            buildResult.artifacts[platform] = platformResult.artifacts;
          }
        } catch (error) {
          this.logger.error(`Build failed for platform ${platform}:`, error);
          buildResult.platforms[platform] = {
            success: false,
            error: error.message,
            logs: [error.message]
          };
        }
      }

      // Check if all builds succeeded
      const allSucceeded = Object.values(buildResult.platforms)
        .every(result => result.success);

      buildResult.success = allSucceeded;
      buildResult.endTime = new Date();
      buildResult.duration = buildResult.endTime - buildResult.startTime;

      this.logger.info(`Build ${id} completed`, {
        success: buildResult.success,
        duration: buildResult.duration,
        platforms: Object.keys(buildResult.platforms)
      });

      return buildResult;

    } catch (error) {
      this.logger.error(`Build orchestration failed for ${id}:`, error);
      buildResult.success = false;
      buildResult.error = error.message;
      buildResult.endTime = new Date();
      buildResult.duration = buildResult.endTime - buildResult.startTime;
      
      return buildResult;
    }
  }

  /**
   * Prepare build environment
   */
  async prepareBuildEnvironment(buildConfig) {
    const { commitSha } = buildConfig;
    
    this.logger.info('Preparing build environment');

    // Ensure we're in the project directory
    process.chdir(this.projectRoot);

    // Pull latest changes if not already at the correct commit
    if (commitSha !== 'HEAD') {
      await this.executeCommand('git', ['fetch', 'origin']);
      await this.executeCommand('git', ['checkout', commitSha]);
    } else {
      await this.executeCommand('git', ['pull', 'origin', 'master']);
    }

    // Clean previous builds
    await this.executeCommand('flutter', ['clean']);
    
    // Get dependencies
    await this.executeCommand('flutter', ['pub', 'get']);

    // Verify Flutter environment
    const flutterDoctor = await this.executeCommand('flutter', ['doctor', '--machine']);
    this.logger.debug('Flutter doctor output:', flutterDoctor.stdout);

    this.logger.info('Build environment prepared successfully');
  }

  /**
   * Build for specific platform
   */
  async buildPlatform(platform, buildConfig) {
    const platformResult = {
      success: false,
      logs: [],
      artifacts: {},
      startTime: new Date(),
      endTime: null,
      duration: null
    };

    try {
      switch (platform) {
        case 'web':
          await this.buildWeb(platformResult, buildConfig);
          break;
        case 'windows':
          await this.buildWindows(platformResult, buildConfig);
          break;
        case 'linux':
          await this.buildLinux(platformResult, buildConfig);
          break;
        default:
          throw new Error(`Unsupported platform: ${platform}`);
      }

      platformResult.success = true;
      platformResult.endTime = new Date();
      platformResult.duration = platformResult.endTime - platformResult.startTime;

    } catch (error) {
      platformResult.success = false;
      platformResult.error = error.message;
      platformResult.endTime = new Date();
      platformResult.duration = platformResult.endTime - platformResult.startTime;
      throw error;
    }

    return platformResult;
  }

  /**
   * Build Flutter web application
   */
  async buildWeb(platformResult, buildConfig) {
    this.logger.info('Building Flutter web application');

    // Use existing build script with timestamp injection
    const buildScript = path.join(this.projectRoot, 'scripts/flutter_build_with_timestamp.sh');
    
    if (await fs.pathExists(buildScript)) {
      // Use build script with timestamp injection
      const result = await this.executeCommand('bash', [buildScript, 'web', '--release']);
      platformResult.logs.push(result.stdout);
    } else {
      // Fallback to direct Flutter build
      const result = await this.executeCommand('flutter', ['build', 'web', '--release']);
      platformResult.logs.push(result.stdout);
    }

    // Verify build output
    const webBuildPath = path.join(this.projectRoot, 'build/web');
    if (!(await fs.pathExists(webBuildPath))) {
      throw new Error('Web build output not found');
    }

    platformResult.artifacts.webBuild = webBuildPath;
    this.logger.info('Flutter web build completed successfully');
  }

  /**
   * Build Windows packages using Docker container
   */
  async buildWindows(platformResult, buildConfig) {
    this.logger.info('Building Windows packages');

    // Use Docker container with Windows build environment
    const dockerImage = 'cloudtolocalllm-windows-builder';
    
    // Check if Docker image exists, build if not
    await this.ensureDockerImage(dockerImage, 'Dockerfile.windows-builder');

    // Run Windows build in container
    const buildCommand = [
      'docker', 'run', '--rm',
      '-v', `${this.projectRoot}:/workspace`,
      '-w', '/workspace',
      dockerImage,
      'bash', '-c', 'scripts/powershell/build_unified_package.ps1 -Platform Windows'
    ];

    const result = await this.executeCommand(buildCommand[0], buildCommand.slice(1));
    platformResult.logs.push(result.stdout);

    // Verify Windows build artifacts
    const windowsBuildPath = path.join(this.projectRoot, 'dist/windows');
    if (await fs.pathExists(windowsBuildPath)) {
      platformResult.artifacts.windowsPackages = windowsBuildPath;
    }

    this.logger.info('Windows build completed successfully');
  }

  /**
   * Build Linux packages
   */
  async buildLinux(platformResult, buildConfig) {
    this.logger.info('Building Linux packages');

    // Build Flutter Linux application
    const flutterResult = await this.executeCommand('flutter', ['build', 'linux', '--release']);
    platformResult.logs.push(flutterResult.stdout);

    // Create AUR package using existing script
    const aurScript = path.join(this.projectRoot, 'scripts/create_aur_binary_package.sh');
    if (await fs.pathExists(aurScript)) {
      const aurResult = await this.executeCommand('bash', [aurScript]);
      platformResult.logs.push(aurResult.stdout);
    }

    // Create unified package using existing script
    const unifiedScript = path.join(this.projectRoot, 'scripts/build_unified_package.sh');
    if (await fs.pathExists(unifiedScript)) {
      const unifiedResult = await this.executeCommand('bash', [unifiedScript]);
      platformResult.logs.push(unifiedResult.stdout);
    }

    // Verify Linux build artifacts
    const linuxBuildPath = path.join(this.projectRoot, 'build/linux');
    const distPath = path.join(this.projectRoot, 'dist');
    
    if (await fs.pathExists(linuxBuildPath)) {
      platformResult.artifacts.linuxBuild = linuxBuildPath;
    }
    
    if (await fs.pathExists(distPath)) {
      platformResult.artifacts.packages = distPath;
    }

    this.logger.info('Linux build completed successfully');
  }

  /**
   * Ensure Docker image exists for builds
   */
  async ensureDockerImage(imageName, dockerfilePath) {
    try {
      // Check if image exists
      await this.executeCommand('docker', ['inspect', imageName]);
      this.logger.debug(`Docker image ${imageName} already exists`);
    } catch (error) {
      // Image doesn't exist, build it
      this.logger.info(`Building Docker image: ${imageName}`);
      
      const dockerfileFull = path.join(this.projectRoot, dockerfilePath);
      if (await fs.pathExists(dockerfileFull)) {
        await this.executeCommand('docker', [
          'build', '-t', imageName, '-f', dockerfileFull, '.'
        ]);
      } else {
        this.logger.warn(`Dockerfile not found: ${dockerfileFull}`);
      }
    }
  }

  /**
   * Execute command with proper error handling and logging
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
      }, this.config.buildTimeout);

      child.on('close', () => {
        clearTimeout(timeout);
      });
    });
  }

  /**
   * Get build status for monitoring
   */
  getBuildStatus() {
    return {
      isBuilding: this.currentBuild !== null,
      currentBuild: this.currentBuild,
      lastBuild: this.lastBuild
    };
  }
}

module.exports = BuildOrchestrator;
