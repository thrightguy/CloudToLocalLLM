/**
 * Notification Service for CloudToLocalLLM CI/CD Agent
 * Handles build status notifications via multiple channels
 */

const nodemailer = require('nodemailer');
const axios = require('axios');
const fs = require('fs-extra');
const path = require('path');

class NotificationService {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger;
    this.enabled = config.enableNotifications;
    
    // Initialize notification channels
    this.initializeChannels();
  }

  /**
   * Initialize notification channels
   */
  initializeChannels() {
    this.channels = {
      email: this.initializeEmail(),
      webhook: this.initializeWebhook(),
      slack: this.initializeSlack(),
      discord: this.initializeDiscord()
    };
  }

  /**
   * Initialize email notifications
   */
  initializeEmail() {
    if (!process.env.SMTP_HOST) {
      this.logger.debug('Email notifications disabled - no SMTP configuration');
      return null;
    }

    try {
      const transporter = nodemailer.createTransporter({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT) || 587,
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS
        }
      });

      this.logger.info('Email notifications initialized');
      return transporter;
    } catch (error) {
      this.logger.error('Failed to initialize email notifications:', error);
      return null;
    }
  }

  /**
   * Initialize webhook notifications
   */
  initializeWebhook() {
    const webhookUrl = process.env.NOTIFICATION_WEBHOOK_URL;
    if (!webhookUrl) {
      this.logger.debug('Webhook notifications disabled - no URL configured');
      return null;
    }

    this.logger.info('Webhook notifications initialized');
    return { url: webhookUrl };
  }

  /**
   * Initialize Slack notifications
   */
  initializeSlack() {
    const slackWebhook = process.env.SLACK_WEBHOOK_URL;
    if (!slackWebhook) {
      this.logger.debug('Slack notifications disabled - no webhook URL configured');
      return null;
    }

    this.logger.info('Slack notifications initialized');
    return { webhookUrl: slackWebhook };
  }

  /**
   * Initialize Discord notifications
   */
  initializeDiscord() {
    const discordWebhook = process.env.DISCORD_WEBHOOK_URL;
    if (!discordWebhook) {
      this.logger.debug('Discord notifications disabled - no webhook URL configured');
      return null;
    }

    this.logger.info('Discord notifications initialized');
    return { webhookUrl: discordWebhook };
  }

  /**
   * Send build queued notification
   */
  async sendBuildQueued(buildConfig) {
    if (!this.enabled) return;

    const message = {
      title: '🔄 Build Queued',
      description: `Build ${buildConfig.id} has been queued`,
      fields: [
        { name: 'Trigger', value: buildConfig.trigger, inline: true },
        { name: 'Branch', value: buildConfig.branch, inline: true },
        { name: 'Author', value: buildConfig.author, inline: true },
        { name: 'Platforms', value: buildConfig.platforms.join(', '), inline: true }
      ],
      color: 0xFFA500, // Orange
      timestamp: buildConfig.timestamp
    };

    await this.sendNotification(message, buildConfig);
  }

  /**
   * Send build started notification
   */
  async sendBuildStarted(buildConfig) {
    if (!this.enabled) return;

    const message = {
      title: '🚀 Build Started',
      description: `Build ${buildConfig.id} has started`,
      fields: [
        { name: 'Commit', value: buildConfig.commitSha.substring(0, 8), inline: true },
        { name: 'Message', value: buildConfig.commitMessage, inline: false },
        { name: 'Platforms', value: buildConfig.platforms.join(', '), inline: true },
        { name: 'Deploy to VPS', value: buildConfig.deployToVPS ? 'Yes' : 'No', inline: true }
      ],
      color: 0x0099FF, // Blue
      timestamp: new Date().toISOString()
    };

    await this.sendNotification(message, buildConfig);
  }

  /**
   * Send build completed notification
   */
  async sendBuildCompleted(build) {
    if (!this.enabled) return;

    const success = build.status === 'success';
    const duration = this.formatDuration(build.duration);

    const message = {
      title: success ? '✅ Build Successful' : '❌ Build Failed',
      description: `Build ${build.id} ${success ? 'completed successfully' : 'failed'}`,
      fields: [
        { name: 'Duration', value: duration, inline: true },
        { name: 'Platforms', value: Object.keys(build.result.platforms).join(', '), inline: true }
      ],
      color: success ? 0x00FF00 : 0xFF0000, // Green or Red
      timestamp: build.endTime
    };

    // Add platform-specific results
    for (const [platform, result] of Object.entries(build.result.platforms)) {
      message.fields.push({
        name: `${platform} Build`,
        value: result.success ? '✅ Success' : '❌ Failed',
        inline: true
      });
    }

    if (!success && build.error) {
      message.fields.push({
        name: 'Error',
        value: build.error.substring(0, 1000),
        inline: false
      });
    }

    await this.sendNotification(message, build);
  }

  /**
   * Send build failed notification
   */
  async sendBuildFailed(build, error) {
    if (!this.enabled) return;

    const duration = this.formatDuration(build.duration);

    const message = {
      title: '💥 Build Error',
      description: `Build ${build.id} encountered an error`,
      fields: [
        { name: 'Duration', value: duration, inline: true },
        { name: 'Error', value: error.message.substring(0, 1000), inline: false }
      ],
      color: 0xFF0000, // Red
      timestamp: build.endTime
    };

    await this.sendNotification(message, build);
  }

  /**
   * Send deployment success notification
   */
  async sendDeploymentSuccess(buildConfig, deployResult) {
    if (!this.enabled) return;

    const duration = this.formatDuration(deployResult.duration);

    const message = {
      title: '🚀 Deployment Successful',
      description: `Build ${buildConfig.id} deployed successfully to VPS`,
      fields: [
        { name: 'Duration', value: duration, inline: true },
        { name: 'Services', value: Object.keys(deployResult.services).length.toString(), inline: true }
      ],
      color: 0x00FF00, // Green
      timestamp: deployResult.endTime
    };

    // Add service status
    for (const [service, status] of Object.entries(deployResult.services)) {
      message.fields.push({
        name: service,
        value: status === 'running' ? '✅ Running' : '❌ Not Running',
        inline: true
      });
    }

    // Add health check results
    const healthyChecks = Object.values(deployResult.healthChecks)
      .filter(check => check.accessible || check.status === 'healthy').length;
    const totalChecks = Object.keys(deployResult.healthChecks).length;

    message.fields.push({
      name: 'Health Checks',
      value: `${healthyChecks}/${totalChecks} passed`,
      inline: true
    });

    await this.sendNotification(message, buildConfig);
  }

  /**
   * Send deployment failed notification
   */
  async sendDeploymentFailed(buildConfig, error) {
    if (!this.enabled) return;

    const message = {
      title: '💥 Deployment Failed',
      description: `Build ${buildConfig.id} deployment failed`,
      fields: [
        { name: 'Error', value: error.message.substring(0, 1000), inline: false }
      ],
      color: 0xFF0000, // Red
      timestamp: new Date().toISOString()
    };

    await this.sendNotification(message, buildConfig);
  }

  /**
   * Send notification to all configured channels
   */
  async sendNotification(message, context) {
    const promises = [];

    // Send to email
    if (this.channels.email) {
      promises.push(this.sendEmailNotification(message, context));
    }

    // Send to webhook
    if (this.channels.webhook) {
      promises.push(this.sendWebhookNotification(message, context));
    }

    // Send to Slack
    if (this.channels.slack) {
      promises.push(this.sendSlackNotification(message, context));
    }

    // Send to Discord
    if (this.channels.discord) {
      promises.push(this.sendDiscordNotification(message, context));
    }

    // Wait for all notifications to complete
    const results = await Promise.allSettled(promises);
    
    // Log any failures
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        this.logger.error(`Notification failed for channel ${index}:`, result.reason);
      }
    });
  }

  /**
   * Send email notification
   */
  async sendEmailNotification(message, context) {
    if (!this.channels.email) return;

    const recipients = process.env.NOTIFICATION_EMAIL_RECIPIENTS?.split(',') || [];
    if (recipients.length === 0) return;

    const subject = `CloudToLocalLLM CI/CD: ${message.title}`;
    const html = this.formatEmailMessage(message);

    try {
      await this.channels.email.sendMail({
        from: process.env.SMTP_FROM || 'cicd@cloudtolocalllm.online',
        to: recipients.join(', '),
        subject,
        html
      });

      this.logger.debug('Email notification sent successfully');
    } catch (error) {
      this.logger.error('Failed to send email notification:', error);
      throw error;
    }
  }

  /**
   * Send webhook notification
   */
  async sendWebhookNotification(message, context) {
    if (!this.channels.webhook) return;

    try {
      await axios.post(this.channels.webhook.url, {
        ...message,
        context,
        timestamp: new Date().toISOString()
      }, {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CloudToLocalLLM-CICD-Agent'
        }
      });

      this.logger.debug('Webhook notification sent successfully');
    } catch (error) {
      this.logger.error('Failed to send webhook notification:', error);
      throw error;
    }
  }

  /**
   * Send Slack notification
   */
  async sendSlackNotification(message, context) {
    if (!this.channels.slack) return;

    const slackMessage = {
      text: message.title,
      attachments: [{
        color: message.color === 0x00FF00 ? 'good' : 
               message.color === 0xFF0000 ? 'danger' : 'warning',
        fields: message.fields.map(field => ({
          title: field.name,
          value: field.value,
          short: field.inline
        })),
        ts: Math.floor(new Date(message.timestamp).getTime() / 1000)
      }]
    };

    try {
      await axios.post(this.channels.slack.webhookUrl, slackMessage, {
        timeout: 10000
      });

      this.logger.debug('Slack notification sent successfully');
    } catch (error) {
      this.logger.error('Failed to send Slack notification:', error);
      throw error;
    }
  }

  /**
   * Send Discord notification
   */
  async sendDiscordNotification(message, context) {
    if (!this.channels.discord) return;

    const discordMessage = {
      embeds: [{
        title: message.title,
        description: message.description,
        color: message.color,
        fields: message.fields,
        timestamp: message.timestamp,
        footer: {
          text: 'CloudToLocalLLM CI/CD Agent'
        }
      }]
    };

    try {
      await axios.post(this.channels.discord.webhookUrl, discordMessage, {
        timeout: 10000
      });

      this.logger.debug('Discord notification sent successfully');
    } catch (error) {
      this.logger.error('Failed to send Discord notification:', error);
      throw error;
    }
  }

  /**
   * Format email message as HTML
   */
  formatEmailMessage(message) {
    let html = `
      <h2>${message.title}</h2>
      <p>${message.description}</p>
      <table border="1" cellpadding="5" cellspacing="0">
    `;

    for (const field of message.fields) {
      html += `
        <tr>
          <td><strong>${field.name}</strong></td>
          <td>${field.value}</td>
        </tr>
      `;
    }

    html += `
      </table>
      <p><small>Timestamp: ${message.timestamp}</small></p>
    `;

    return html;
  }

  /**
   * Format duration in human-readable format
   */
  formatDuration(milliseconds) {
    if (!milliseconds) return 'Unknown';

    const seconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);

    if (hours > 0) {
      return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`;
    } else {
      return `${seconds}s`;
    }
  }

  /**
   * Test notification channels
   */
  async testNotifications() {
    const testMessage = {
      title: '🧪 Test Notification',
      description: 'This is a test notification from CloudToLocalLLM CI/CD Agent',
      fields: [
        { name: 'Status', value: 'Testing', inline: true },
        { name: 'Timestamp', value: new Date().toISOString(), inline: true }
      ],
      color: 0x0099FF,
      timestamp: new Date().toISOString()
    };

    await this.sendNotification(testMessage, { test: true });
    this.logger.info('Test notifications sent');
  }
}

module.exports = NotificationService;
