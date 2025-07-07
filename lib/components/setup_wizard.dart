import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/desktop_client_detection_service.dart';

/// Setup wizard component that appears for first-time users or when no desktop client is detected
///
/// This component guides users through:
/// - Understanding the desktop client requirement for local Ollama connectivity
/// - Downloading the appropriate client for their platform
/// - Step-by-step installation instructions
/// - Connection verification steps
class SetupWizard extends StatefulWidget {
  final bool isFirstTimeUser;
  final VoidCallback? onDismiss;
  final VoidCallback? onComplete;

  const SetupWizard({
    super.key,
    this.isFirstTimeUser = false,
    this.onDismiss,
    this.onComplete,
  });

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _currentStep = 0;
  bool _isDismissed = false;

  final List<SetupStep> _steps = [
    SetupStep(
      title: 'Welcome to CloudToLocalLLM',
      description:
          'Connect your local Ollama instance to this web interface for secure, private AI conversations.',
      icon: Icons.cloud_download_outlined,
    ),
    SetupStep(
      title: 'Desktop Client Required',
      description:
          'To use your local Ollama models, you need to install the CloudToLocalLLM desktop client. It creates a secure tunnel between your local Ollama instance and this web app.',
      icon: Icons.desktop_windows,
    ),
    SetupStep(
      title: 'Download Desktop Client',
      description: 'Choose the appropriate version for your operating system.',
      icon: Icons.download,
    ),
    SetupStep(
      title: 'Installation Instructions',
      description: 'Follow the platform-specific installation guide.',
      icon: Icons.install_desktop,
    ),
    SetupStep(
      title: 'Connection Verification',
      description:
          'Verify that your desktop client is connected and ready to use.',
      icon: Icons.check_circle_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    // Don't show if dismissed
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    return Consumer<DesktopClientDetectionService>(
      builder: (context, clientDetection, child) {
        // Don't show if clients are connected (unless it's first time user)
        if (clientDetection.hasConnectedClients && !widget.isFirstTimeUser) {
          return const SizedBox.shrink();
        }

        return _buildWizardDialog(context, clientDetection);
      },
    );
  }

  Widget _buildWizardDialog(
    BuildContext context,
    DesktopClientDetectionService clientDetection,
  ) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Progress indicator
            _buildProgressIndicator(),

            // Content
            Expanded(child: _buildStepContent(clientDetection)),

            // Footer with navigation buttons
            _buildFooter(clientDetection),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.borderRadiusL),
          topRight: Radius.circular(AppTheme.borderRadiusL),
        ),
      ),
      child: Row(
        children: [
          Icon(_steps[_currentStep].icon, color: Colors.white, size: 32),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _steps[_currentStep].title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Step ${_currentStep + 1} of ${_steps.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onDismiss != null)
            IconButton(
              onPressed: _dismissWizard,
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      child: LinearProgressIndicator(
        value: (_currentStep + 1) / _steps.length,
        backgroundColor: AppTheme.backgroundMain,
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildStepContent(DesktopClientDetectionService clientDetection) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _steps[_currentStep].description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textColor,
              height: 1.5,
            ),
          ),
          SizedBox(height: AppTheme.spacingL),
          Expanded(child: _buildStepSpecificContent(clientDetection)),
        ],
      ),
    );
  }

  Widget _buildStepSpecificContent(
    DesktopClientDetectionService clientDetection,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeContent();
      case 1:
        return _buildRequirementContent();
      case 2:
        return _buildDownloadContent();
      case 3:
        return _buildInstallationContent();
      case 4:
        return _buildVerificationContent(clientDetection);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.waving_hand, size: 64, color: AppTheme.primaryColor),
          SizedBox(height: AppTheme.spacingL),
          Text(
            'Let\'s get you set up!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'This wizard will guide you through connecting your local Ollama instance to this web interface.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementContent() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 24),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  'The desktop client acts as a secure bridge between this web interface and your local Ollama installation.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppTheme.spacingL),
        _buildFeatureList(),
      ],
    );
  }

  Widget _buildFeatureList() {
    final features = [
      'Secure tunnel connection',
      'No data leaves your machine',
      'Works with any Ollama model',
      'Real-time streaming responses',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features
          .map(
            (feature) => Padding(
              padding: EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                  SizedBox(width: AppTheme.spacingS),
                  Text(
                    feature,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDownloadContent() {
    return Column(
      children: [
        Text(
          'Choose your platform:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppTheme.spacingL),
        _buildPlatformButtons(),
      ],
    );
  }

  Widget _buildPlatformButtons() {
    return Column(
      children: [
        _buildPlatformButton(
          'Windows',
          Icons.desktop_windows,
          () => context.go('/settings/downloads'),
        ),
        SizedBox(height: AppTheme.spacingM),
        _buildPlatformButton(
          'macOS',
          Icons.laptop_mac,
          () => context.go('/settings/downloads'),
        ),
        SizedBox(height: AppTheme.spacingM),
        _buildPlatformButton(
          'Linux',
          Icons.computer,
          () => context.go('/settings/downloads'),
        ),
      ],
    );
  }

  Widget _buildPlatformButton(
    String platform,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text('Download for $platform'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(AppTheme.spacingM),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
        ),
      ),
    );
  }

  Widget _buildInstallationContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Installation Steps:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildInstallationSteps(),
        ],
      ),
    );
  }

  Widget _buildInstallationSteps() {
    final steps = [
      'Download the desktop client for your platform',
      'Run the installer or extract the portable version',
      'Launch the CloudToLocalLLM desktop application',
      'The client will automatically connect to this web interface',
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;

        return Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spacingM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  step,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVerificationContent(
    DesktopClientDetectionService clientDetection,
  ) {
    final hasConnectedClients = clientDetection.hasConnectedClients;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasConnectedClients ? Icons.check_circle : Icons.pending,
            size: 64,
            color: hasConnectedClients
                ? AppTheme.successColor
                : AppTheme.warningColor,
          ),
          SizedBox(height: AppTheme.spacingL),
          Text(
            hasConnectedClients
                ? 'Desktop Client Connected!'
                : 'Waiting for Desktop Client...',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            hasConnectedClients
                ? 'Your desktop client is successfully connected. You can now use your local Ollama models!'
                : 'Please launch the desktop client to complete the setup.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            textAlign: TextAlign.center,
          ),
          if (hasConnectedClients) ...[
            SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: _completeWizard,
              icon: const Icon(Icons.check_circle),
              label: const Text('Complete Setup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                  vertical: AppTheme.spacingM,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(DesktopClientDetectionService clientDetection) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            )
          else
            const SizedBox.shrink(),

          Row(
            children: [
              if (widget.onDismiss != null && _currentStep < _steps.length - 1)
                TextButton(
                  onPressed: _dismissWizard,
                  child: const Text('Skip for now'),
                ),
              SizedBox(width: AppTheme.spacingM),
              if (_currentStep < _steps.length - 1)
                ElevatedButton.icon(
                  onPressed: _nextStep,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _completeWizard,
                  icon: const Icon(Icons.check),
                  label: const Text('Complete Setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _dismissWizard() {
    setState(() {
      _isDismissed = true;
    });
    widget.onDismiss?.call();
  }

  void _completeWizard() {
    setState(() {
      _isDismissed = true;
    });
    widget.onComplete?.call();
  }
}

/// Data class for setup wizard steps
class SetupStep {
  final String title;
  final String description;
  final IconData icon;

  const SetupStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
