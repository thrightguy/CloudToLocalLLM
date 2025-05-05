import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/onboarding_provider.dart';

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, onboardingProvider, _) {
        // If onboarding is complete, don't show the wizard
        if (onboardingProvider.isOnboardingComplete) {
          return const SizedBox.shrink();
        }

        // If user is not authenticated, show login prompt
        if (!onboardingProvider.isAuthenticated) {
          return _buildLoginPrompt(context);
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stepper indicator
                Row(
                  children: List.generate(
                    5, // Total steps
                    (index) => Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: onboardingProvider.currentStep >= index
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: onboardingProvider.currentStep > index
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 16)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: onboardingProvider.currentStep >=
                                                index
                                            ? Colors.white
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getStepTitle(index),
                            style: TextStyle(
                              fontSize: 12,
                              color: onboardingProvider.currentStep >= index
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[600],
                              fontWeight:
                                  onboardingProvider.currentStep == index
                                      ? FontWeight.bold
                                      : null,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Step content
                _buildStepContent(context, onboardingProvider),

                const SizedBox(height: 24),

                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    onboardingProvider.currentStep > 0
                        ? TextButton.icon(
                            onPressed: onboardingProvider.isLoading
                                ? null
                                : () => onboardingProvider.previousStep(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                          )
                        : const SizedBox.shrink(),
                    if (onboardingProvider.currentStep < 4) // Last step index
                      ElevatedButton.icon(
                        onPressed: onboardingProvider.isLoading
                            ? null
                            : (onboardingProvider.currentStep == 1 &&
                                    onboardingProvider.apiKey == null)
                                ? null
                                : () => onboardingProvider.nextStep(),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(onboardingProvider.currentStep == 0
                            ? 'Start Setup'
                            : 'Continue'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: onboardingProvider.isLoading
                            ? null
                            : () => onboardingProvider.completeOnboarding(),
                        icon: const Icon(Icons.check),
                        label: const Text('Finish'),
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

  Widget _buildLoginPrompt(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Up Your Secure Cloud Environment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please login to set up your secure cloud environment and generate your API key.',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to login
                Navigator.pushNamed(context, '/login');
              },
              icon: const Icon(Icons.login),
              label: const Text('Login to Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, OnboardingProvider provider) {
    switch (provider.currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildApiKeyStep(context, provider);
      case 2:
        return _buildClientSetupStep();
      case 3:
        return _buildContainerStatusStep(context, provider);
      case 4:
        return _buildCompleteStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWelcomeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Welcome to CloudToLocalLLM Setup',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text(
          'This wizard will guide you through:',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.key, color: Colors.blue),
          minLeadingWidth: 24,
          title: Text('Generating a secure private API key'),
        ),
        ListTile(
          leading: Icon(Icons.computer, color: Colors.blue),
          minLeadingWidth: 24,
          title: Text('Setting up your local client'),
        ),
        ListTile(
          leading: Icon(Icons.cloud, color: Colors.blue),
          minLeadingWidth: 24,
          title: Text('Configuring your secure cloud container'),
        ),
        SizedBox(height: 16),
        Text(
          'Important: Your data will remain private and end-to-end encrypted at all times.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildApiKeyStep(BuildContext context, OnboardingProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generate Your API Key',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your API key is private and cannot be recovered if lost. It will be shown only once.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (provider.apiKey == null)
          ElevatedButton.icon(
            onPressed:
                provider.isLoading ? null : () => provider.generateApiKey(),
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.key),
            label:
                Text(provider.isLoading ? 'Generating...' : 'Generate API Key'),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your API Key (SAVE THIS NOW!):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        provider.apiKey!,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: provider.apiKey!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('API key copied to clipboard')),
                        );
                      },
                      tooltip: 'Copy to clipboard',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'WARNING: This key will never be shown again and cannot be recovered if lost.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildClientSetupStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set Up Your Local Client',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          '1. Download the appropriate client software:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(
                    'https://github.com/yourusername/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-Windows.exe');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              icon: const Icon(Icons.desktop_windows),
              label: const Text('Windows Client'),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(
                    'https://github.com/yourusername/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-Ubuntu.deb');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              icon: const Icon(Icons.computer),
              label: const Text('Ubuntu Client'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '2. Install the client software following the included instructions.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '3. When prompted, enter the API key you generated in the previous step.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          '4. The client will automatically connect to your secure cloud container.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildContainerStatusStep(
      BuildContext context, OnboardingProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cloud Container Setup',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (provider.isLoading)
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Setting up your secure container...'),
              ],
            ),
          )
        else if (!provider.containerCreated)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your secure cloud container needs to be created.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => provider.createContainer(),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Create Container'),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Container Status: ${provider.containerStatus ?? "Unknown"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: provider.containerReady ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              provider.containerReady
                  ? const Text(
                      'Your container is ready! You can now use your client software to connect.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your container is being prepared. This may take a few minutes.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.checkContainerStatus(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Status'),
                        ),
                      ],
                    ),
            ],
          ),
      ],
    );
  }

  Widget _buildCompleteStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Setup Complete!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text(
          'Congratulations! Your secure cloud environment is now set up.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text(
          'What to do next:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ListTile(
          leading: Text('1.', style: TextStyle(fontWeight: FontWeight.bold)),
          title: Text(
              'Make sure your client software is installed and connected using your API key.'),
        ),
        ListTile(
          leading: Text('2.', style: TextStyle(fontWeight: FontWeight.bold)),
          title: Text(
              'Start a new conversation to begin using your secure cloud LLM.'),
        ),
        ListTile(
          leading: Text('3.', style: TextStyle(fontWeight: FontWeight.bold)),
          title: Text(
              'Your data remains private and end-to-end encrypted at all times.'),
        ),
      ],
    );
  }

  String _getStepTitle(int index) {
    switch (index) {
      case 0:
        return 'Welcome';
      case 1:
        return 'API Key';
      case 2:
        return 'Client';
      case 3:
        return 'Container';
      case 4:
        return 'Complete';
      default:
        return '';
    }
  }
}
