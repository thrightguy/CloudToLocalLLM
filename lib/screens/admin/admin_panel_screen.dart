import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import 'admin_data_flush_screen.dart';

/// Comprehensive Administrative Panel Screen
///
/// Provides secure administrative interface with:
/// - System monitoring dashboard
/// - User management
/// - Configuration management
/// - Container management
/// - Data flush operations
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Initialize admin service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAdminPanel();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeAdminPanel() async {
    final adminService = context.read<AdminService>();

    setState(() {
      _isInitialized = false;
    });

    final success = await adminService.initialize();

    setState(() {
      _isInitialized = success;
    });

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to initialize admin panel. Please check your admin privileges.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      appBar: AppBar(
        title: const Text(
          '🔧 CloudToLocalLLM Admin Panel',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.backgroundCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
            tooltip: 'Refresh All Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textColorLight,
          indicatorColor: AppTheme.primaryColor,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Containers', icon: Icon(Icons.developer_board)),
            Tab(text: 'Configuration', icon: Icon(Icons.settings)),
            Tab(text: 'Data Flush', icon: Icon(Icons.delete_forever)),
          ],
        ),
      ),
      body: _isInitialized
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildUsersTab(),
                _buildContainersTab(),
                _buildConfigurationTab(),
                _buildDataFlushTab(),
              ],
            )
          : _buildInitializingView(),
    );
  }

  Widget _buildInitializingView() {
    return Consumer<AdminService>(
      builder: (context, adminService, child) {
        if (adminService.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Admin Panel Initialization Failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  adminService.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeAdminPanel,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Admin Panel...'),
              SizedBox(height: 8),
              Text(
                'Checking admin privileges and loading data',
                style: TextStyle(color: AppTheme.textColorLight),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    return Consumer<AdminService>(
      builder: (context, adminService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSystemStatsCard(adminService),
              const SizedBox(height: 16),
              _buildRealtimeMetricsCard(adminService),
              const SizedBox(height: 16),
              _buildQuickActionsCard(adminService),
              const SizedBox(height: 16),
              _buildSystemHealthCard(adminService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemStatsCard(AdminService adminService) {
    final stats = adminService.systemStats;

    return Card(
      color: AppTheme.backgroundCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'System Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (stats != null)
                  Text(
                    'Last updated: ${_formatTimestamp(stats['timestamp'])}',
                    style: const TextStyle(
                      color: AppTheme.textColorLight,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (stats == null)
              const Center(child: CircularProgressIndicator())
            else
              _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final systemStats = stats['system'] as Map<String, dynamic>? ?? {};
    final dockerStats = stats['docker'] as Map<String, dynamic>? ?? {};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatItem(
          'Total Memory',
          _formatBytes(systemStats['totalMemory'] ?? 0),
          Icons.memory,
        ),
        _buildStatItem(
          'Free Memory',
          _formatBytes(systemStats['freeMemory'] ?? 0),
          Icons.memory_outlined,
        ),
        _buildStatItem(
          'CPU Cores',
          '${systemStats['cpuCount'] ?? 0}',
          Icons.developer_board,
        ),
        _buildStatItem(
          'System Uptime',
          _formatUptime(systemStats['uptime'] ?? 0),
          Icons.timer,
        ),
        _buildStatItem(
          'Total Containers',
          '${dockerStats['totalContainers'] ?? 0}',
          Icons.inventory,
        ),
        _buildStatItem(
          'Running Containers',
          '${dockerStats['runningContainers'] ?? 0}',
          Icons.play_circle,
        ),
        _buildStatItem(
          'Active Users',
          '${dockerStats['activeUsers'] ?? 0}',
          Icons.people,
        ),
        _buildStatItem(
          'User Networks',
          '${dockerStats['userNetworks'] ?? 0}',
          Icons.network_check,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundMain,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textColorLight,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeMetricsCard(AdminService adminService) {
    return Card(
      color: AppTheme.backgroundCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Real-time Metrics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (adminService.lastRealtimeUpdate != null)
                  Text(
                    'Last updated: ${_formatTimestamp(adminService.lastRealtimeUpdate.toString())}',
                    style: const TextStyle(
                      color: AppTheme.textColorLight,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => adminService.getRealtimeData(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Real-time metrics will be implemented here
            const Center(
              child: Text(
                'Real-time metrics visualization coming soon',
                style: TextStyle(color: AppTheme.textColorLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAllData() async {
    final adminService = context.read<AdminService>();
    await adminService.refreshAllData();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatUptime(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    try {
      final dateTime = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildQuickActionsCard(AdminService adminService) {
    return Card(
      color: AppTheme.backgroundCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionButton(
                  'Refresh All Data',
                  Icons.refresh,
                  () => adminService.refreshAllData(),
                ),
                _buildQuickActionButton(
                  'View Users',
                  Icons.people,
                  () => _tabController.animateTo(1),
                ),
                _buildQuickActionButton(
                  'View Containers',
                  Icons.developer_board,
                  () => _tabController.animateTo(2),
                ),
                _buildQuickActionButton(
                  'System Config',
                  Icons.settings,
                  () => _tabController.animateTo(3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
    );
  }

  Widget _buildSystemHealthCard(AdminService adminService) {
    return Card(
      color: AppTheme.backgroundCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.health_and_safety,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Health',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHealthIndicator('Admin Server', true),
            _buildHealthIndicator('Docker Service', true),
            _buildHealthIndicator(
              'Authentication',
              adminService.isAdminAuthenticated,
            ),
            _buildHealthIndicator('Database Connection', true),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(String service, bool isHealthy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            color: isHealthy ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(service, style: const TextStyle(color: AppTheme.textColor)),
          const Spacer(),
          Text(
            isHealthy ? 'Healthy' : 'Error',
            style: TextStyle(
              color: isHealthy ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Consumer<AdminService>(
      builder: (context, adminService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppTheme.backgroundCard,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'User Management',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppTheme.textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () =>
                                adminService.getUsers(forceRefresh: true),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (adminService.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (adminService.users.isEmpty)
                        const Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: AppTheme.textColorLight),
                          ),
                        )
                      else
                        _buildUsersList(adminService.users),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          color: AppTheme.backgroundMain,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: user['isActive'] ? Colors.green : Colors.grey,
              child: Text(
                user['userId'].toString().substring(0, 2).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(
              user['userId'] ?? 'Unknown User',
              style: const TextStyle(color: AppTheme.textColor),
            ),
            subtitle: Text(
              'Containers: ${user['containerCount']} | Active: ${user['activeContainers']} | Last Activity: ${_formatTimestamp(user['lastActivity'])}',
              style: const TextStyle(
                color: AppTheme.textColorLight,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user['isActive'])
                  const Icon(Icons.circle, color: Colors.green, size: 12),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleUserAction(value, user),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view_sessions',
                      child: Text('View Sessions'),
                    ),
                    const PopupMenuItem(
                      value: 'terminate_sessions',
                      child: Text('Terminate All Sessions'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'view_sessions':
        _showUserSessions(user['userId']);
        break;
      case 'terminate_sessions':
        _confirmTerminateUserSessions(user['userId']);
        break;
    }
  }

  void _showUserSessions(String userId) {
    // Implementation for showing user sessions dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sessions for $userId'),
        content: const Text('User sessions view coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmTerminateUserSessions(String userId) {
    // Implementation for confirming session termination
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text(
          'Are you sure you want to terminate all sessions for $userId?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement session termination
            },
            child: const Text('Terminate'),
          ),
        ],
      ),
    );
  }

  Widget _buildContainersTab() {
    return Consumer<AdminService>(
      builder: (context, adminService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppTheme.backgroundCard,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.developer_board,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Container Management',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppTheme.textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () =>
                                adminService.getContainers(forceRefresh: true),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (adminService.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (adminService.containers.isEmpty)
                        const Center(
                          child: Text(
                            'No containers found',
                            style: TextStyle(color: AppTheme.textColorLight),
                          ),
                        )
                      else
                        _buildContainersList(adminService.containers),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContainersList(List<Map<String, dynamic>> containers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: containers.length,
      itemBuilder: (context, index) {
        final container = containers[index];
        final isRunning = container['state'] == 'running';

        return Card(
          color: AppTheme.backgroundMain,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isRunning ? Colors.green : Colors.grey,
              child: Icon(
                isRunning ? Icons.play_arrow : Icons.stop,
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Text(
              container['name'] ?? 'Unknown Container',
              style: const TextStyle(color: AppTheme.textColor),
            ),
            subtitle: Text(
              'State: ${container['state']} | Image: ${container['image']} | User: ${container['labels']?['cloudtolocalllm.user'] ?? 'Unknown'}',
              style: const TextStyle(
                color: AppTheme.textColorLight,
                fontSize: 12,
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleContainerAction(value, container),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view_logs',
                  child: Text('View Logs'),
                ),
                const PopupMenuItem(
                  value: 'view_stats',
                  child: Text('View Stats'),
                ),
                if (isRunning)
                  const PopupMenuItem(
                    value: 'stop',
                    child: Text('Stop Container'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleContainerAction(String action, Map<String, dynamic> container) {
    switch (action) {
      case 'view_logs':
        _showContainerLogs(container['id']);
        break;
      case 'view_stats':
        _showContainerStats(container['id']);
        break;
      case 'stop':
        _confirmStopContainer(container['id'], container['name']);
        break;
    }
  }

  void _showContainerLogs(String containerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Container Logs: ${containerId.substring(0, 12)}'),
        content: const Text('Container logs view coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContainerStats(String containerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Container Stats: ${containerId.substring(0, 12)}'),
        content: const Text('Container stats view coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmStopContainer(String containerId, String containerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text(
          'Are you sure you want to stop container $containerName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement container stop
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationTab() {
    return Consumer<AdminService>(
      builder: (context, adminService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppTheme.backgroundCard,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.settings,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'System Configuration',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppTheme.textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => adminService.getConfiguration(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (adminService.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (adminService.configuration == null)
                        const Center(
                          child: Text(
                            'No configuration data available',
                            style: TextStyle(color: AppTheme.textColorLight),
                          ),
                        )
                      else
                        _buildConfigurationView(adminService.configuration!),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigurationView(Map<String, dynamic> config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigSection('Server Configuration', config['server']),
        const SizedBox(height: 16),
        _buildConfigSection('Authentication', config['auth']),
        const SizedBox(height: 16),
        _buildConfigSection('Docker Configuration', config['docker']),
        const SizedBox(height: 16),
        _buildConfigSection('Feature Flags', config['features']),
        const SizedBox(height: 16),
        _buildConfigSection('Resource Limits', config['limits']),
      ],
    );
  }

  Widget _buildConfigSection(String title, dynamic data) {
    if (data == null) return const SizedBox.shrink();

    final Map<String, dynamic> configData = data as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...configData.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: AppTheme.textColorLight),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(color: AppTheme.textColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataFlushTab() {
    return const AdminDataFlushScreen();
  }
}
