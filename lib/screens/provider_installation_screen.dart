import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/installation_service.dart';

class ProviderInstallationScreen extends StatefulWidget {
  final String provider;
  
  const ProviderInstallationScreen({
    Key? key,
    required this.provider,
  }) : super(key: key);

  @override
  State<ProviderInstallationScreen> createState() => _ProviderInstallationScreenState();
}

class _ProviderInstallationScreenState extends State<ProviderInstallationScreen> {
  final InstallationService _installationService = InstallationService();
  
  bool _isLoading = true;
  bool _isInstalled = false;
  bool _isRunning = false;
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String _statusMessage = '';
  
  @override
  void initState() {
    super.initState();
    _checkInstallation();
  }
  
  Future<void> _checkInstallation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking installation...';
    });
    
    try {
      if (widget.provider == 'ollama') {
        _isInstalled = await _installationService.isOllamaInstalled();
        _isRunning = await _installationService.isOllamaRunning();
      } else if (widget.provider == 'lmstudio') {
        _isInstalled = await _installationService.isLmStudioInstalled();
        _isRunning = await _installationService.isLmStudioRunning();
      }
    } catch (e) {
      _statusMessage = 'Error checking installation: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _installProvider() async {
    setState(() {
      _isInstalling = true;
      _installProgress = 0.0;
      _statusMessage = 'Starting installation...';
    });
    
    try {
      bool success;
      
      if (widget.provider == 'ollama') {
        success = await _installationService.installOllama(
          onProgress: (progress) {
            setState(() {
              _installProgress = progress;
            });
          },
          onStatus: (status) {
            setState(() {
              _statusMessage = status;
            });
          },
        );
      } else if (widget.provider == 'lmstudio') {
        success = await _installationService.installLmStudio(
          onProgress: (progress) {
            setState(() {
              _installProgress = progress;
            });
          },
          onStatus: (status) {
            setState(() {
              _statusMessage = status;
            });
          },
        );
      } else {
        success = false;
        _statusMessage = 'Unknown provider: ${widget.provider}';
      }
      
      if (success) {
        await _checkInstallation();
        
        // Update the selected provider in settings if installation was successful
        if (_isInstalled && _isRunning) {
          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
          settingsProvider.setLlmProvider(widget.provider);
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during installation: $e';
      });
    } finally {
      setState(() {
        _isInstalling = false;
      });
    }
  }
  
  Future<void> _startProvider() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting ${widget.provider}...';
    });
    
    try {
      bool success;
      
      if (widget.provider == 'ollama') {
        success = await _installationService.startOllama();
      } else if (widget.provider == 'lmstudio') {
        success = await _installationService.startLmStudio();
      } else {
        success = false;
        _statusMessage = 'Unknown provider: ${widget.provider}';
      }
      
      if (success) {
        await _checkInstallation();
      } else {
        setState(() {
          _statusMessage = 'Failed to start ${widget.provider}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting ${widget.provider}: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final providerName = widget.provider == 'ollama' ? 'Ollama' : 'LM Studio';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('$providerName Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$providerName Setup',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isInstalled ? Icons.check_circle : Icons.cancel,
                          color: _isInstalled ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Installed: ${_isInstalled ? 'Yes' : 'No'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isRunning ? Icons.check_circle : Icons.cancel,
                          color: _isRunning ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Running: ${_isRunning ? 'Yes' : 'No'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Status: $_statusMessage',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                    if (_isInstalling) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: _installProgress),
                      const SizedBox(height: 8),
                      Text('${(_installProgress * 100).toStringAsFixed(0)}%'),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (!_isInstalled)
                ElevatedButton.icon(
                  onPressed: _isInstalling ? null : _installProvider,
                  icon: const Icon(Icons.download),
                  label: Text('Install $providerName'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                )
              else if (!_isRunning)
                ElevatedButton.icon(
                  onPressed: _startProvider,
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Start $providerName'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    // Set as active provider and return to previous screen
                    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                    settingsProvider.setLlmProvider(widget.provider);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: Text('Use $providerName'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: _checkInstallation,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Information section
            if (widget.provider == 'ollama') ...[
              const Text(
                'About Ollama:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ollama is an open-source tool that allows you to run large language models locally. '
                'It provides a simple API for running models like Llama 2, Mistral, and more.',
              ),
            ] else if (widget.provider == 'lmstudio') ...[
              const Text(
                'About LM Studio:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'LM Studio is a desktop application that allows you to discover, download, and run local LLMs. '
                'It provides a user-friendly interface for managing and using various language models.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: After installation, you\'ll need to start LM Studio manually and enable the local inference server '
                'in the settings to use it with this application.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}