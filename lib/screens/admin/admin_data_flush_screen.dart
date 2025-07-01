import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/admin_data_flush_service.dart';

/// Administrative Data Flush Screen
///
/// Provides secure administrative interface for data flush operations
/// with multi-step confirmation and comprehensive audit trail.
class AdminDataFlushScreen extends StatefulWidget {
  const AdminDataFlushScreen({super.key});

  @override
  State<AdminDataFlushScreen> createState() => _AdminDataFlushScreenState();
}

class _AdminDataFlushScreenState extends State<AdminDataFlushScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _targetUserController = TextEditingController();
  String _selectedScope = 'FULL_FLUSH';
  final Map<String, bool> _flushOptions = {
    'skipAuth': false,
    'skipConversations': false,
    'skipPreferences': false,
    'skipCache': false,
    'skipContainers': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetUserController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final adminService = context.read<AdminDataFlushService>();
    await adminService.getSystemStatistics();
    await adminService.loadFlushHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundMain,
      appBar: AppBar(
        title: const Text(
          '🗑️ Administrative Data Flush',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.backgroundCard,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textColorLight,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Data Flush', icon: Icon(Icons.delete_forever)),
            Tab(text: 'Audit Trail', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildDataFlushTab(),
          _buildAuditTrailTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        if (adminService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSystemStatsCard(),
              const SizedBox(height: 16),
              _buildQuickActionsCard(),
              const SizedBox(height: 16),
              _buildRecentOperationsCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemStatsCard() {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return Card(
          color: AppTheme.backgroundCard,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                // System stats would be displayed here
                // This is a placeholder for the actual implementation
                const Text(
                  'Loading system statistics...',
                  style: TextStyle(color: AppTheme.textColorLight),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      color: AppTheme.backgroundCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _performEmergencyCleanup,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Emergency Cleanup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _refreshData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOperationsCard() {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        final recentOps = adminService.operationHistory.take(5).toList();

        return Card(
          color: AppTheme.backgroundCard,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Operations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (recentOps.isEmpty)
                  const Text(
                    'No recent operations',
                    style: TextStyle(color: AppTheme.textColorLight),
                  )
                else
                  ...recentOps.map((op) => _buildOperationTile(op)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataFlushTab() {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWarningCard(),
              const SizedBox(height: 16),
              _buildFlushConfigurationCard(),
              const SizedBox(height: 16),
              _buildFlushExecutionCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.red.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            const Text(
              'CRITICAL WARNING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data flush operations permanently delete user data and cannot be undone. '
              'Ensure you have proper authorization and have backed up any necessary data.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlushConfigurationCard() {
    return Card(
      color: AppTheme.backgroundCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flush Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),

            // Scope selection
            DropdownButtonFormField<String>(
              value: _selectedScope,
              decoration: const InputDecoration(
                labelText: 'Flush Scope',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'FULL_FLUSH',
                  child: Text('Full System Flush'),
                ),
                DropdownMenuItem(
                  value: 'USER_SPECIFIC',
                  child: Text('Specific User'),
                ),
                DropdownMenuItem(
                  value: 'CONTAINERS_ONLY',
                  child: Text('Containers Only'),
                ),
                DropdownMenuItem(
                  value: 'AUTH_ONLY',
                  child: Text('Authentication Only'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedScope = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Target user (if user-specific)
            if (_selectedScope == 'USER_SPECIFIC')
              TextField(
                controller: _targetUserController,
                decoration: const InputDecoration(
                  labelText: 'Target User ID',
                  border: OutlineInputBorder(),
                  hintText: 'Enter specific user ID to target',
                ),
              ),

            const SizedBox(height: 16),

            // Flush options
            const Text(
              'Flush Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),

            ..._flushOptions.entries.map(
              (entry) => CheckboxListTile(
                title: Text(_getOptionLabel(entry.key)),
                subtitle: Text(_getOptionDescription(entry.key)),
                value: entry.value,
                onChanged: (value) {
                  setState(() {
                    _flushOptions[entry.key] = value ?? false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlushExecutionCard() {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return Card(
          color: AppTheme.backgroundCard,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flush Execution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 16),

                if (adminService.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      adminService.error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: adminService.isLoading
                            ? null
                            : _prepareFlush,
                        icon: const Icon(Icons.security),
                        label: Text(
                          adminService.hasValidConfirmationToken
                              ? 'Token Ready'
                              : 'Prepare Flush',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              adminService.hasValidConfirmationToken
                              ? Colors.green
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            adminService.hasValidConfirmationToken &&
                                !adminService.isLoading
                            ? _executeFlush
                            : null,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('EXECUTE FLUSH'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                if (adminService.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditTrailTab() {
    return Consumer<AdminDataFlushService>(
      builder: (context, adminService, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: adminService.operationHistory.length,
          itemBuilder: (context, index) {
            final operation = adminService.operationHistory[index];
            return _buildOperationCard(operation);
          },
        );
      },
    );
  }

  Widget _buildOperationTile(Map<String, dynamic> operation) {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: Text(
        'Operation ${operation['operationId']?.substring(0, 8) ?? 'Unknown'}',
      ),
      subtitle: Text('Target: ${operation['targetUserId'] ?? 'Unknown'}'),
      trailing: Text(
        _formatTimestamp(operation['timestamp']),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildOperationCard(Map<String, dynamic> operation) {
    return Card(
      color: AppTheme.backgroundCard,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Operation ${operation['operationId']?.substring(0, 8) ?? 'Unknown'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(operation['timestamp']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textColorLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Target: ${operation['targetUserId'] ?? 'Unknown'}'),
            if (operation['duration'] != null)
              Text('Duration: ${operation['duration']}ms'),
            if (operation['results'] != null)
              Text('Results: ${operation['results'].toString()}'),
          ],
        ),
      ),
    );
  }

  String _getOptionLabel(String key) {
    switch (key) {
      case 'skipAuth':
        return 'Skip Authentication Data';
      case 'skipConversations':
        return 'Skip Conversation Data';
      case 'skipPreferences':
        return 'Skip Preferences Data';
      case 'skipCache':
        return 'Skip Cache Data';
      case 'skipContainers':
        return 'Skip Container Cleanup';
      default:
        return key;
    }
  }

  String _getOptionDescription(String key) {
    switch (key) {
      case 'skipAuth':
        return 'Preserve user authentication tokens and sessions';
      case 'skipConversations':
        return 'Preserve conversation history and chat data';
      case 'skipPreferences':
        return 'Preserve user settings and preferences';
      case 'skipCache':
        return 'Preserve cached data and temporary files';
      case 'skipContainers':
        return 'Preserve Docker containers and networks';
      default:
        return '';
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid';
    }
  }

  Future<void> _prepareFlush() async {
    final adminService = context.read<AdminDataFlushService>();

    final confirmed = await _showConfirmationDialog(
      'Prepare Data Flush',
      'This will prepare a data flush operation. Are you sure you want to continue?',
    );

    if (confirmed) {
      final targetUserId = _selectedScope == 'USER_SPECIFIC'
          ? _targetUserController.text.trim()
          : null;

      await adminService.prepareDataFlush(
        targetUserId: targetUserId,
        scope: _selectedScope,
      );
    }
  }

  Future<void> _executeFlush() async {
    final adminService = context.read<AdminDataFlushService>();

    final confirmed = await _showConfirmationDialog(
      'EXECUTE DATA FLUSH',
      'This will PERMANENTLY DELETE user data. This action CANNOT be undone. Are you absolutely sure?',
      isDestructive: true,
    );

    if (confirmed) {
      final targetUserId = _selectedScope == 'USER_SPECIFIC'
          ? _targetUserController.text.trim()
          : null;

      final success = await adminService.executeDataFlush(
        targetUserId: targetUserId,
        options: _flushOptions,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data flush executed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _performEmergencyCleanup() async {
    final adminService = context.read<AdminDataFlushService>();

    final confirmed = await _showConfirmationDialog(
      'Emergency Container Cleanup',
      'This will remove all orphaned containers and networks. Continue?',
    );

    if (confirmed) {
      await adminService.emergencyContainerCleanup();
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  Future<bool> _showConfirmationDialog(
    String title,
    String message, {
    bool isDestructive = false,
  }) async {
    if (isDestructive) {
      return await _showDestructiveConfirmationDialog(title, message);
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isDestructive ? Icons.warning : Icons.info,
                  color: isDestructive ? Colors.orange : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (isDestructive) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This action cannot be undone!',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive
                      ? Colors.red
                      : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(isDestructive ? 'I Understand' : 'Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Enhanced destructive confirmation dialog with multi-step verification
  Future<bool> _showDestructiveConfirmationDialog(
    String title,
    String message,
  ) async {
    final TextEditingController confirmationController =
        TextEditingController();
    bool canConfirm = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.dangerous, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'CRITICAL WARNING',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• This will PERMANENTLY delete user data\n'
                          '• This action CANNOT be undone\n'
                          '• All conversations will be lost\n'
                          '• All authentication tokens will be cleared\n'
                          '• Docker containers will be removed',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Type "DELETE" to confirm this destructive action:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmationController,
                    decoration: const InputDecoration(
                      hintText: 'Type DELETE here',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        canConfirm = value.trim().toUpperCase() == 'DELETE';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canConfirm
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('EXECUTE DELETION'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }
}
