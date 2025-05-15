import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/license_service.dart';

/// Widget for license key input and verification
class LicenseKeyInput extends StatefulWidget {
  final LicenseService licenseService;
  final Function(bool success) onVerificationComplete;

  const LicenseKeyInput({
    super.key,
    required this.licenseService,
    required this.onVerificationComplete,
  });

  @override
  State<LicenseKeyInput> createState() => _LicenseKeyInputState();
}

class _LicenseKeyInputState extends State<LicenseKeyInput> {
  final TextEditingController _licenseKeyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isVerified = false;
  String? _currentTier;

  @override
  void initState() {
    super.initState();
    _checkExistingLicense();
  }

  /// Check if a license key already exists
  Future<void> _checkExistingLicense() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final licenseKey = await widget.licenseService.getLicenseKey();
      if (licenseKey != null && licenseKey.isNotEmpty) {
        _licenseKeyController.text = licenseKey;

        // Verify the existing license
        final isValid = await widget.licenseService.verifyLicense();
        if (isValid) {
          final tier = await widget.licenseService.getLicenseTier();
          setState(() {
            _isVerified = true;
            _currentTier = tier;
            _errorMessage = null;
          });
          widget.onVerificationComplete(true);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking license: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Verify the license key
  Future<void> _verifyLicenseKey() async {
    final licenseKey = _licenseKeyController.text.trim();
    if (licenseKey.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a license key';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.licenseService.setLicenseKey(licenseKey);

      if (success) {
        final tier = await widget.licenseService.getLicenseTier();
        setState(() {
          _isVerified = true;
          _currentTier = tier;
        });
        widget.onVerificationComplete(true);
      } else {
        setState(() {
          _errorMessage = 'Invalid license key';
          _isVerified = false;
        });
        widget.onVerificationComplete(false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying license: $e';
        _isVerified = false;
      });
      widget.onVerificationComplete(false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'License Key',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_isVerified) ...[
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'License verified (${_currentTier?.toUpperCase() ?? 'UNKNOWN'} tier)',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isVerified = false;
                        });
                      },
                child: const Text('Change'),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _licenseKeyController,
            decoration: InputDecoration(
              hintText: 'Enter your license key',
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
              suffixIcon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data != null && data.text != null) {
                          _licenseKeyController.text = data.text!.trim();
                        }
                      },
                    ),
            ),
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyLicenseKey(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyLicenseKey,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify License'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    // Open a dialog with trial license information
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Start Free Trial'),
                        content: const Text(
                          'Don\'t have a license key? You can start a 30-day trial to explore all features before purchasing.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _licenseKeyController.text =
                                  'FREE-TRIAL-KEY-123456';
                              _verifyLicenseKey();
                            },
                            child: const Text('Start Trial'),
                          ),
                        ],
                      ),
                    );
                  },
            child: const Text('Start Free Trial'),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }
}
