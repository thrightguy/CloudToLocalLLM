import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/tunnel_manager_service.dart';

/// Comprehensive tunnel connection wizard for CloudToLocalLLM v3.5.13+
///
/// Guides users through the complete tunnel setup process:
/// 1. Authentication
/// 2. Server Selection
/// 3. Connection Testing
/// 4. Configuration Save
class TunnelConnectionWizard extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const TunnelConnectionWizard({super.key, this.onComplete, this.onCancel});

  @override
  State<TunnelConnectionWizard> createState() => _TunnelConnectionWizardState();
}

class _TunnelConnectionWizardState extends State<TunnelConnectionWizard> {
  int _currentStep = 0;
  bool _isProcessing = false;
  String? _error;

  // Configuration state
  String _selectedServer = 'https://app.cloudtolocalllm.online';
  int _connectionTimeout = 10;
  int _healthCheckInterval = 30;
  bool _enableCloudProxy = true;

  // Test results
  bool? _authTestResult;
  bool? _connectionTestResult;
  String? _serverVersion;

  final List<WizardStep> _steps = [
    WizardStep(
      title: 'Authentication',
      description: 'Authenticate with CloudToLocalLLM services',
      icon: Icons.login,
    ),
    WizardStep(
      title: 'Server Selection',
      description: 'Choose your tunnel server configuration',
      icon: Icons.dns,
    ),
    WizardStep(
      title: 'Connection Testing',
      description: 'Test the tunnel connection',
      icon: Icons.network_check,
    ),
    WizardStep(
      title: 'Configuration Save',
      description: 'Save and activate your tunnel configuration',
      icon: Icons.save,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.8).clamp(600.0, 900.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(600.0, 800.0);

    return Dialog(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStepIndicator(),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: _buildCurrentStep())),
            const SizedBox(height: 20),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.settings_ethernet,
          size: 32,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tunnel Connection Setup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Configure your CloudToLocalLLM tunnel connection',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: _steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.green
                              : isActive
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : step.icon,
                          color: isCompleted || isActive
                              ? Colors.white
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isActive
                              ? Theme.of(context).primaryColor
                              : isCompleted
                              ? Colors.green
                              : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (index < _steps.length - 1)
                  Container(
                    width: 32,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 30),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_error != null) {
      return _buildErrorStep();
    }

    switch (_currentStep) {
      case 0:
        return _buildAuthenticationStep();
      case 1:
        return _buildServerSelectionStep();
      case 2:
        return _buildConnectionTestingStep();
      case 3:
        return _buildConfigurationSaveStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildErrorStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Setup Error',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationStep() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;
        final isLoading = authService.isLoading.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _steps[0].title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _steps[0].description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (isAuthenticated) ...[
              _buildSuccessCard(
                'Authentication Successful',
                'You are logged in as ${authService.currentUser?.email ?? 'Unknown'}',
                Icons.check_circle,
              ),
            ] else ...[
              _buildInfoCard(
                'Authentication Required',
                'Please authenticate with your CloudToLocalLLM account to continue.',
                Icons.info,
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _performAuthentication(authService),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(isLoading ? 'Authenticating...' : 'Login'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildServerSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _steps[1].title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[1].description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _buildServerConfigCard(),
      ],
    );
  }

  Widget _buildConnectionTestingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _steps[2].title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[2].description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _buildConnectionTestCard(),
      ],
    );
  }

  Widget _buildConfigurationSaveStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _steps[3].title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[3].description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _buildConfigurationSummaryCard(),
      ],
    );
  }

  Widget _buildSuccessCard(String title, String description, IconData icon) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.green, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String description, IconData icon) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _selectedServer,
              decoration: const InputDecoration(
                labelText: 'Tunnel Server URL',
                hintText: 'https://app.cloudtolocalllm.online',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedServer = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _connectionTimeout.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Connection Timeout (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _connectionTimeout = int.tryParse(value) ?? 10;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _healthCheckInterval.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Health Check Interval (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _healthCheckInterval = int.tryParse(value) ?? 30;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Cloud Proxy'),
              subtitle: const Text(
                'Allow tunnel connections through cloud proxy',
              ),
              value: _enableCloudProxy,
              onChanged: (value) {
                setState(() {
                  _enableCloudProxy = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Test',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTestResultItem(
              'Authentication',
              _authTestResult,
              'Verifying authentication token...',
            ),
            const SizedBox(height: 8),
            _buildTestResultItem(
              'Server Connection',
              _connectionTestResult,
              'Testing connection to $_selectedServer...',
            ),
            if (_serverVersion != null) ...[
              const SizedBox(height: 8),
              Text(
                'Server Version: $_serverVersion',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.green.shade700),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _performConnectionTest,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_isProcessing ? 'Testing...' : 'Test Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultItem(String label, bool? result, String loadingText) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: result == null
              ? (_isProcessing
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey,
                      ))
              : result
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.error, color: Colors.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            result == null && _isProcessing ? loadingText : label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: result == null
                  ? Colors.grey
                  : result
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryItem('Server URL', _selectedServer),
            _buildSummaryItem(
              'Connection Timeout',
              '$_connectionTimeout seconds',
            ),
            _buildSummaryItem(
              'Health Check Interval',
              '$_healthCheckInterval seconds',
            ),
            _buildSummaryItem(
              'Cloud Proxy',
              _enableCloudProxy ? 'Enabled' : 'Disabled',
            ),
            if (_serverVersion != null)
              _buildSummaryItem('Server Version', _serverVersion!),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Ready to Save',
              'Your tunnel configuration is ready to be saved and activated.',
              Icons.info,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _currentStep < _steps.length - 1
                ? ElevatedButton.icon(
                    onPressed: _canProceedToNextStep() && !_isProcessing
                        ? _nextStep
                        : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isProcessing ? 'Processing...' : 'Next'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _canCompleteWizard() && !_isProcessing
                        ? _completeWizard
                        : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isProcessing ? 'Saving...' : 'Complete Setup'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _error = null;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _error = null;
      });
    }
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Authentication step
        final authService = context.read<AuthService>();
        return authService.isAuthenticated.value;
      case 1: // Server selection step
        return _selectedServer.isNotEmpty &&
            _connectionTimeout > 0 &&
            _healthCheckInterval > 0;
      case 2: // Connection testing step
        return _authTestResult == true && _connectionTestResult == true;
      case 3: // Configuration save step
        return true;
      default:
        return false;
    }
  }

  bool _canCompleteWizard() {
    return _authTestResult == true && _connectionTestResult == true;
  }

  // Action methods
  Future<void> _performAuthentication(AuthService authService) async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      await authService.loginWithPersistence();

      if (authService.isAuthenticated.value) {
        setState(() {
          _authTestResult = true;
        });
      } else {
        setState(() {
          _error = 'Authentication failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Authentication error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _performConnectionTest() async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
        _authTestResult = null;
        _connectionTestResult = null;
        _serverVersion = null;
      });

      // Test authentication
      final authService = context.read<AuthService>();
      final isAuthenticated = await authService.validateAuthentication();

      setState(() {
        _authTestResult = isAuthenticated;
      });

      if (!isAuthenticated) {
        setState(() {
          _error = 'Authentication test failed. Please re-authenticate.';
        });
        return;
      }

      // Test server connection using enhanced testing
      if (!mounted) return;
      final tunnelManager = context.read<TunnelManagerService>();
      final testConfig = TunnelConfig(
        enableCloudProxy: _enableCloudProxy,
        cloudProxyUrl: _selectedServer,
        connectionTimeout: _connectionTimeout,
        healthCheckInterval: _healthCheckInterval,
      );

      // Use the enhanced connection testing method
      final testResult = await tunnelManager.testConnectionForWizard(
        testConfig,
      );

      if (mounted) {
        setState(() {
          _connectionTestResult = testResult['success'] as bool;
          _serverVersion = testResult['serverInfo']?['version'] as String?;
        });

        if (!_connectionTestResult!) {
          final errorMessage = testResult['error'] as String?;
          final steps = testResult['steps'] as List<Map<String, dynamic>>?;

          // Build detailed error message from test steps
          final failedSteps = steps
              ?.where((step) => step['status'] == 'failed')
              .toList();
          String detailedError = errorMessage ?? 'Connection test failed';

          if (failedSteps != null && failedSteps.isNotEmpty) {
            final stepErrors = failedSteps
                .map((step) => '${step['name']}: ${step['error']}')
                .join('; ');
            detailedError = '$detailedError ($stepErrors)';
          }

          setState(() {
            _error = detailedError;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Connection test error: ${e.toString()}';
        _connectionTestResult = false;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeWizard() async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      if (!mounted) return;
      final tunnelManager = context.read<TunnelManagerService>();
      final finalConfig = TunnelConfig(
        enableCloudProxy: _enableCloudProxy,
        cloudProxyUrl: _selectedServer,
        connectionTimeout: _connectionTimeout,
        healthCheckInterval: _healthCheckInterval,
      );

      await tunnelManager.updateConfiguration(finalConfig);

      // Notify completion
      if (mounted) {
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save configuration: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}

/// Wizard step data model
class WizardStep {
  final String title;
  final String description;
  final IconData icon;

  const WizardStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
