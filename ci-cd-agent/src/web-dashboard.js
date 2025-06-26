/**
 * Web Dashboard for CloudToLocalLLM CI/CD Agent
 * Provides a web interface for monitoring builds and deployments
 */

const express = require('express');
const path = require('path');
const fs = require('fs-extra');

class WebDashboard {
  constructor(config, logger) {
    this.config = config;
    this.logger = logger;
    this.router = express.Router();
    
    this.setupRoutes();
  }

  /**
   * Setup dashboard routes
   */
  setupRoutes() {
    // Serve static files
    this.router.use('/static', express.static(path.join(__dirname, '../public')));

    // Dashboard home page
    this.router.get('/', (req, res) => {
      res.send(this.generateDashboardHTML());
    });

    // Build details page
    this.router.get('/build/:id', (req, res) => {
      res.send(this.generateBuildDetailsHTML(req.params.id));
    });

    // API endpoints for dashboard data
    this.router.get('/api/dashboard/stats', (req, res) => {
      res.json(this.getDashboardStats());
    });

    this.router.get('/api/dashboard/recent-builds', (req, res) => {
      res.json(this.getRecentBuilds());
    });

    this.router.get('/api/dashboard/system-status', (req, res) => {
      res.json(this.getSystemStatus());
    });
  }

  /**
   * Generate main dashboard HTML
   */
  generateDashboardHTML() {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudToLocalLLM CI/CD Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            color: #333;
        }
        
        .header {
            background: #2c3e50;
            color: white;
            padding: 1rem 2rem;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 1.5rem;
            font-weight: 600;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        
        .stat-card {
            background: white;
            padding: 1.5rem;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid #3498db;
        }
        
        .stat-card.success {
            border-left-color: #27ae60;
        }
        
        .stat-card.warning {
            border-left-color: #f39c12;
        }
        
        .stat-card.error {
            border-left-color: #e74c3c;
        }
        
        .stat-value {
            font-size: 2rem;
            font-weight: bold;
            margin-bottom: 0.5rem;
        }
        
        .stat-label {
            color: #666;
            font-size: 0.9rem;
        }
        
        .builds-section {
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .section-header {
            background: #34495e;
            color: white;
            padding: 1rem 1.5rem;
            font-weight: 600;
        }
        
        .builds-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .builds-table th,
        .builds-table td {
            padding: 1rem 1.5rem;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        
        .builds-table th {
            background: #f8f9fa;
            font-weight: 600;
        }
        
        .status-badge {
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-success {
            background: #d4edda;
            color: #155724;
        }
        
        .status-failed {
            background: #f8d7da;
            color: #721c24;
        }
        
        .status-running {
            background: #d1ecf1;
            color: #0c5460;
        }
        
        .status-queued {
            background: #fff3cd;
            color: #856404;
        }
        
        .refresh-btn {
            background: #3498db;
            color: white;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.9rem;
            margin-bottom: 1rem;
        }
        
        .refresh-btn:hover {
            background: #2980b9;
        }
        
        .auto-refresh {
            color: #666;
            font-size: 0.8rem;
            margin-left: 1rem;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 CloudToLocalLLM CI/CD Dashboard</h1>
    </div>
    
    <div class="container">
        <div class="stats-grid" id="stats-grid">
            <!-- Stats will be loaded here -->
        </div>
        
        <div class="builds-section">
            <div class="section-header">
                Recent Builds
                <button class="refresh-btn" onclick="refreshData()">Refresh</button>
                <span class="auto-refresh">Auto-refresh: <span id="countdown">30</span>s</span>
            </div>
            <table class="builds-table">
                <thead>
                    <tr>
                        <th>Build ID</th>
                        <th>Status</th>
                        <th>Trigger</th>
                        <th>Branch</th>
                        <th>Author</th>
                        <th>Duration</th>
                        <th>Started</th>
                    </tr>
                </thead>
                <tbody id="builds-tbody">
                    <!-- Builds will be loaded here -->
                </tbody>
            </table>
        </div>
    </div>
    
    <script>
        let countdownTimer = 30;
        let refreshInterval;
        
        // Load initial data
        refreshData();
        
        // Setup auto-refresh
        startAutoRefresh();
        
        function refreshData() {
            loadStats();
            loadRecentBuilds();
            resetCountdown();
        }
        
        function loadStats() {
            fetch('/api/dashboard/stats')
                .then(response => response.json())
                .then(data => {
                    const statsGrid = document.getElementById('stats-grid');
                    statsGrid.innerHTML = \`
                        <div class="stat-card success">
                            <div class="stat-value">\${data.successfulBuilds}</div>
                            <div class="stat-label">Successful Builds (24h)</div>
                        </div>
                        <div class="stat-card error">
                            <div class="stat-value">\${data.failedBuilds}</div>
                            <div class="stat-label">Failed Builds (24h)</div>
                        </div>
                        <div class="stat-card warning">
                            <div class="stat-value">\${data.currentBuilds}</div>
                            <div class="stat-label">Current Builds</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-value">\${data.queueLength}</div>
                            <div class="stat-label">Queued Builds</div>
                        </div>
                    \`;
                })
                .catch(error => console.error('Failed to load stats:', error));
        }
        
        function loadRecentBuilds() {
            fetch('/api/dashboard/recent-builds')
                .then(response => response.json())
                .then(data => {
                    const tbody = document.getElementById('builds-tbody');
                    tbody.innerHTML = data.builds.map(build => \`
                        <tr>
                            <td><a href="/build/\${build.id}">\${build.id.substring(0, 12)}...</a></td>
                            <td><span class="status-badge status-\${build.status}">\${build.status}</span></td>
                            <td>\${build.trigger}</td>
                            <td>\${build.branch}</td>
                            <td>\${build.author}</td>
                            <td>\${formatDuration(build.duration)}</td>
                            <td>\${formatDate(build.startTime)}</td>
                        </tr>
                    \`).join('');
                })
                .catch(error => console.error('Failed to load builds:', error));
        }
        
        function formatDuration(ms) {
            if (!ms) return '-';
            const seconds = Math.floor(ms / 1000);
            const minutes = Math.floor(seconds / 60);
            const hours = Math.floor(minutes / 60);
            
            if (hours > 0) {
                return \`\${hours}h \${minutes % 60}m\`;
            } else if (minutes > 0) {
                return \`\${minutes}m \${seconds % 60}s\`;
            } else {
                return \`\${seconds}s\`;
            }
        }
        
        function formatDate(dateString) {
            if (!dateString) return '-';
            const date = new Date(dateString);
            return date.toLocaleString();
        }
        
        function startAutoRefresh() {
            refreshInterval = setInterval(() => {
                countdownTimer--;
                document.getElementById('countdown').textContent = countdownTimer;
                
                if (countdownTimer <= 0) {
                    refreshData();
                }
            }, 1000);
        }
        
        function resetCountdown() {
            countdownTimer = 30;
            document.getElementById('countdown').textContent = countdownTimer;
        }
        
        // Cleanup on page unload
        window.addEventListener('beforeunload', () => {
            if (refreshInterval) {
                clearInterval(refreshInterval);
            }
        });
    </script>
</body>
</html>
    `;
  }

  /**
   * Generate build details HTML
   */
  generateBuildDetailsHTML(buildId) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Build ${buildId} - CloudToLocalLLM CI/CD</title>
    <style>
        /* Same styles as dashboard */
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; }
        .header { background: #2c3e50; color: white; padding: 1rem 2rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        .back-link { color: #3498db; text-decoration: none; margin-bottom: 1rem; display: inline-block; }
        .build-header { background: white; padding: 1.5rem; border-radius: 8px; margin-bottom: 1rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .logs-section { background: #2c3e50; color: #ecf0f1; padding: 1rem; border-radius: 8px; font-family: 'Courier New', monospace; font-size: 0.9rem; white-space: pre-wrap; max-height: 500px; overflow-y: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 Build Details: ${buildId}</h1>
    </div>
    
    <div class="container">
        <a href="/" class="back-link">← Back to Dashboard</a>
        
        <div class="build-header" id="build-details">
            <!-- Build details will be loaded here -->
        </div>
        
        <div class="logs-section" id="build-logs">
            Loading build details...
        </div>
    </div>
    
    <script>
        // Load build details
        fetch('/api/builds/${buildId}')
            .then(response => response.json())
            .then(build => {
                document.getElementById('build-details').innerHTML = \`
                    <h2>Build \${build.id}</h2>
                    <p><strong>Status:</strong> \${build.status}</p>
                    <p><strong>Trigger:</strong> \${build.trigger}</p>
                    <p><strong>Branch:</strong> \${build.branch}</p>
                    <p><strong>Author:</strong> \${build.author}</p>
                    <p><strong>Started:</strong> \${new Date(build.startTime).toLocaleString()}</p>
                    \${build.endTime ? \`<p><strong>Completed:</strong> \${new Date(build.endTime).toLocaleString()}</p>\` : ''}
                    \${build.duration ? \`<p><strong>Duration:</strong> \${formatDuration(build.duration)}</p>\` : ''}
                \`;
                
                // Show logs
                const logs = build.logs || [];
                document.getElementById('build-logs').textContent = logs.join('\\n') || 'No logs available';
            })
            .catch(error => {
                document.getElementById('build-logs').textContent = 'Error loading build details: ' + error.message;
            });
            
        function formatDuration(ms) {
            const seconds = Math.floor(ms / 1000);
            const minutes = Math.floor(seconds / 60);
            const hours = Math.floor(minutes / 60);
            
            if (hours > 0) {
                return \`\${hours}h \${minutes % 60}m \${seconds % 60}s\`;
            } else if (minutes > 0) {
                return \`\${minutes}m \${seconds % 60}s\`;
            } else {
                return \`\${seconds}s\`;
            }
        }
    </script>
</body>
</html>
    `;
  }

  /**
   * Get dashboard statistics
   */
  getDashboardStats() {
    // This would be implemented to get actual stats from the build state
    return {
      successfulBuilds: 0,
      failedBuilds: 0,
      currentBuilds: 0,
      queueLength: 0,
      uptime: process.uptime()
    };
  }

  /**
   * Get recent builds
   */
  getRecentBuilds() {
    // This would be implemented to get actual builds from the build state
    return {
      builds: [],
      total: 0
    };
  }

  /**
   * Get system status
   */
  getSystemStatus() {
    return {
      status: 'healthy',
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: require('../package.json').version
    };
  }
}

module.exports = WebDashboard;
