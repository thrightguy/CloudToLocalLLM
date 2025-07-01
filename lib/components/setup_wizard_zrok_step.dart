import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/setup_wizard_service.dart';

/// Zrok Configuration Step for Setup Wizard
///
/// This component guides users through:
/// - Zrok account creation and setup
/// - Token validation and configuration
/// - Tunnel creation testing
/// - Container integration verification
class SetupWizardZrokStep extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onComplete;

  const SetupWizardZrokStep({
    super.key,
    this.onNext,
    this.onPrevious,
    this.onComplete,
  });

  @override
  State<SetupWizardZrokStep> createState() => _SetupWizardZrokStepState();
}

class _SetupWizardZrokStepState extends State<SetupWizardZrokStep> {
  final TextEditingController _tokenController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _currentSubStep = 0;
  bool _isTokenVisible = false;

  final List<ZrokSubStep> _subSteps = [
    ZrokSubStep(
      title: 'Create Zrok Account',
      description: 'Sign up for a free zrok account to enable secure tunneling',
      icon: Icons.account_circle_outlined,
    ),
    ZrokSubStep(
      title: 'Configure Token',
      description: 'Enter your zrok account token to enable tunnel creation',
      icon: Icons.vpn_key_outlined,
    ),
    ZrokSubStep(
      title: 'Test Tunnel Creation',
      description: 'Verify that zrok tunnels can be created successfully',
      icon: Icons.vpn_lock_outlined,
    ),
    ZrokSubStep(
      title: 'Verify Container Integration',
      description:
          'Test that containers can discover and use your zrok tunnels',
      icon: Icons.integration_instructions_outlined,
    ),
  ];

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, setupWizard, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProgressIndicator(),
              const SizedBox(height: 32),
              Expanded(child: _buildCurrentSubStep(setupWizard)),
              const SizedBox(height: 24),
              _buildNavigationButtons(setupWizard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.security_outlined,
              size: 32,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Text(
              'Zrok Tunnel Configuration',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Set up secure zrok tunnels for enhanced connectivity and privacy',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppTheme.textColorLight),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(_subSteps.length, (index) {
        final isCompleted = _isSubStepCompleted(index);
        final isCurrent = index == _currentSubStep;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index < _subSteps.length - 1 ? 8 : 0,
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? AppTheme.primaryColor
                        : AppTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subSteps[index].title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isCompleted || isCurrent
                        ? AppTheme.textColor
                        : AppTheme.textColorLight,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentSubStep(SetupWizardService setupWizard) {
    switch (_currentSubStep) {
      case 0:
        return _buildAccountCreationStep();
      case 1:
        return _buildTokenConfigurationStep(setupWizard);
      case 2:
        return _buildTunnelTestStep(setupWizard);
      case 3:
        return _buildContainerIntegrationStep(setupWizard);
      default:
        return _buildAccountCreationStep();
    }
  }

  Widget _buildAccountCreationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(0),
        const SizedBox(height: 24),
        _buildInfoCard(
          'Zrok provides secure, private tunnels for your local services',
          Icons.info_outline,
        ),
        const SizedBox(height: 24),
        _buildActionCard(
          title: 'Create Your Zrok Account',
          description: 'Sign up for a free zrok account to get started',
          buttonText: 'Open Zrok Website',
          onPressed: () => _launchZrokWebsite(),
          icon: Icons.open_in_new,
        ),
        const SizedBox(height: 16),
        _buildInstructionsList([
          '1. Visit zrok.io and click "Sign Up"',
          '2. Create your account with email and password',
          '3. Verify your email address',
          '4. Log in to your zrok dashboard',
          '5. Copy your account token from the dashboard',
        ]),
      ],
    );
  }

  Widget _buildTokenConfigurationStep(SetupWizardService setupWizard) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(1),
          const SizedBox(height: 24),
          _buildInfoCard(
            'Enter your zrok account token to enable tunnel creation',
            Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 24),
          _buildTokenInput(setupWizard),
          const SizedBox(height: 16),
          if (setupWizard.zrokValidationError != null)
            _buildErrorCard(setupWizard.zrokValidationError!),
          const SizedBox(height: 16),
          _buildInstructionsList([
            '1. Log in to your zrok dashboard at zrok.io',
            '2. Navigate to your account settings',
            '3. Copy your account token',
            '4. Paste the token in the field above',
            '5. Click "Validate Token" to verify',
          ]),
        ],
      ),
    );
  }

  Widget _buildTunnelTestStep(SetupWizardService setupWizard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(2),
        const SizedBox(height: 24),
        if (setupWizard.isZrokTunnelTested)
          _buildSuccessCard('Tunnel creation test completed successfully!')
        else
          _buildTestCard(
            title: 'Test Tunnel Creation',
            description:
                'Verify that zrok can create tunnels with your configuration',
            buttonText: setupWizard.isZrokValidating
                ? 'Testing...'
                : 'Test Tunnel',
            onPressed: setupWizard.isZrokValidating
                ? null
                : () => _testTunnel(setupWizard),
            isLoading: setupWizard.isZrokValidating,
          ),
        if (setupWizard.zrokValidationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildErrorCard(setupWizard.zrokValidationError!),
          ),
      ],
    );
  }

  Widget _buildContainerIntegrationStep(SetupWizardService setupWizard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(3),
        const SizedBox(height: 24),
        if (setupWizard.isContainerIntegrationTested)
          _buildSuccessCard(
            'Container integration test completed successfully!',
          )
        else
          _buildTestCard(
            title: 'Test Container Integration',
            description:
                'Verify that containers can discover and use your zrok tunnels',
            buttonText: setupWizard.isZrokValidating
                ? 'Testing...'
                : 'Test Integration',
            onPressed: setupWizard.isZrokValidating
                ? null
                : () => _testContainerIntegration(setupWizard),
            isLoading: setupWizard.isZrokValidating,
          ),
        if (setupWizard.zrokValidationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildErrorCard(setupWizard.zrokValidationError!),
          ),
      ],
    );
  }

  Widget _buildStepHeader(int stepIndex) {
    final step = _subSteps[stepIndex];
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(step.icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              Text(
                step.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textColorLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textColorLight.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsList(List<String> instructions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructions:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...instructions.map(
            (instruction) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                instruction,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInput(SetupWizardService setupWizard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zrok Account Token',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tokenController,
          obscureText: !_isTokenVisible,
          decoration: InputDecoration(
            hintText: 'Enter your zrok account token',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isTokenVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isTokenVisible = !_isTokenVisible;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final clipboardData = await Clipboard.getData(
                      Clipboard.kTextPlain,
                    );
                    if (clipboardData?.text != null) {
                      _tokenController.text = clipboardData!.text!;
                    }
                  },
                ),
              ],
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your zrok account token';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: setupWizard.isZrokValidating
              ? null
              : () => _validateToken(setupWizard),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: setupWizard.isZrokValidating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Validate Token'),
        ),
      ],
    );
  }

  Widget _buildTestCard({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textColorLight.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(SetupWizardService setupWizard) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _currentSubStep > 0 ? _previousSubStep : widget.onPrevious,
          child: Text(_currentSubStep > 0 ? 'Previous' : 'Back'),
        ),
        Row(
          children: [
            if (_currentSubStep < _subSteps.length - 1)
              ElevatedButton(
                onPressed: _canProceedToNext(setupWizard) ? _nextSubStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Next'),
              )
            else
              ElevatedButton(
                onPressed: setupWizard.isZrokSetupComplete
                    ? widget.onComplete
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Complete'),
              ),
          ],
        ),
      ],
    );
  }

  // Helper methods
  bool _isSubStepCompleted(int stepIndex) {
    final setupWizard = Provider.of<SetupWizardService>(context, listen: false);
    switch (stepIndex) {
      case 0:
        return true; // Account creation is manual, assume completed when moving to next step
      case 1:
        return setupWizard.isZrokConfigured;
      case 2:
        return setupWizard.isZrokTunnelTested;
      case 3:
        return setupWizard.isContainerIntegrationTested;
      default:
        return false;
    }
  }

  bool _canProceedToNext(SetupWizardService setupWizard) {
    switch (_currentSubStep) {
      case 0:
        return true; // Can always proceed from account creation
      case 1:
        return setupWizard.isZrokConfigured;
      case 2:
        return setupWizard.isZrokTunnelTested;
      case 3:
        return setupWizard.isContainerIntegrationTested;
      default:
        return false;
    }
  }

  void _nextSubStep() {
    if (_currentSubStep < _subSteps.length - 1) {
      setState(() {
        _currentSubStep++;
      });
    }
  }

  void _previousSubStep() {
    if (_currentSubStep > 0) {
      setState(() {
        _currentSubStep--;
      });
    }
  }

  Future<void> _launchZrokWebsite() async {
    const url = 'https://zrok.io';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _validateToken(SetupWizardService setupWizard) async {
    if (_formKey.currentState?.validate() ?? false) {
      final success = await setupWizard.configureZrok(
        _tokenController.text.trim(),
      );
      if (success) {
        _nextSubStep();
      }
    }
  }

  Future<void> _testTunnel(SetupWizardService setupWizard) async {
    final success = await setupWizard.testZrokTunnel();
    if (success) {
      _nextSubStep();
    }
  }

  Future<void> _testContainerIntegration(SetupWizardService setupWizard) async {
    final success = await setupWizard.testContainerIntegration();
    if (success && widget.onComplete != null) {
      widget.onComplete!();
    }
  }
}

/// Data class for zrok sub-steps
class ZrokSubStep {
  final String title;
  final String description;
  final IconData icon;

  const ZrokSubStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
