# INTERNAL & CONFIDENTIAL: CloudToLocalLLM Dual Licensing Strategy

**CONFIDENTIAL DOCUMENT - NOT FOR PUBLIC DISTRIBUTION**
**INTERNAL USE ONLY**

## Dual Licensing Structure

CloudToLocalLLM will adopt a dual licensing model:

1. **Open Source License (AGPLv3)**
   - Source code publicly available on GitHub
   - Anyone can use, modify, and distribute the software
   - Any modifications must be shared under the same license
   - Includes the "network use is distribution" clause requiring any SaaS offering to release source code
   - **Key restriction**: Cloud management features are limited and require phone-home verification

2. **Commercial License**
   - Paid subscription providing exemption from AGPLv3 requirements
   - No requirement to share modifications
   - Full enterprise features unlocked
   - Priority support and updates
   - License validation through secure phone-home verification

## License Verification System

### Phone-Home Verification Design

1. **License Key Components**
   - Customer ID (tied to payment/account)
   - Subscription tier (Free/Developer/Professional/Enterprise)
   - Expiration timestamp
   - Device limit
   - Digital signature (signed with our private key)

2. **Verification Process**
   - Local app generates unique device fingerprint
   - App contacts license server with license key + fingerprint
   - Server validates license, checks subscription status, device count
   - Server returns signed token with permissions/features
   - App verifies token signature with embedded public key
   - App caches token with expiration (allow offline use for X days)

3. **Background Verification**
   - App periodically reverifies license (daily/weekly)
   - Graceful degradation when license expires/fails verification
   - Lockout only critical features, maintain basic functionality

### Technical Implementation

1. **License Server API**
   - Endpoint: `https://api.cloudtolocalllm.online/v1/license/verify`
   - Request: `{licenseKey, deviceId, appVersion, usageMetrics}`
   - Response: `{status, subscription, features, expiry, signature}`

2. **Client Integration Points**
   - App startup verification
   - Container creation/management
   - Cloud sync features
   - Premium model access
   - Periodic background verification

3. **Security Measures**
   - Public key embedded in compiled binary
   - License key obfuscation in local storage
   - SSL pinning for API communications
   - Anti-tampering checks
   - Randomized verification timing

## Enforcement Strategy

The enforcement will be designed with a "carrot, not stick" approach:

1. **Feature-Based Enforcement**
   - Open source version: Limited to 1 container, basic models, no cloud sync
   - Commercial license: Multiple containers, all models, full cloud features

2. **Graceful Handling**
   - Clear messaging about license status
   - Easy upgrade path within the app
   - Grace period when license expires (14 days)
   - No data loss when downgrading

3. **Technical Enforcement**
   - Container management API requires valid license
   - Advanced features check license capabilities
   - Cloud synchronization requires valid commercial license

## Implementation Timeline

1. **Phase 1: License Infrastructure**
   - Build license server and API
   - Create license key generation system
   - Set up payment processor integration

2. **Phase 2: Client Integration**
   - Update app to check license
   - Implement feature-gating
   - Add background verification

3. **Phase 3: Business Transition**
   - Update GitHub repository with AGPLv3 license
   - Launch commercial license offerings
   - Provide migration path for existing users

## Legal Considerations

1. **License Agreement**
   - Clear terms for both open source and commercial use
   - Explicit language about verification requirements
   - Privacy policy update for license verification data

2. **Open Source Compliance**
   - Ensure AGPLv3 requirements are met
   - Properly attribute third-party libraries
   - Document separation between open core and commercial features

## Technical Implementation Snippets

```dart
// License verification pseudo-code
Future<bool> verifyLicense() async {
  final deviceId = await _generateDeviceFingerprint();
  final licenseKey = await _secureStorage.read(key: 'license_key');
  
  try {
    final response = await http.post(
      Uri.parse('https://api.cloudtolocalllm.online/v1/license/verify'),
      body: jsonEncode({
        'licenseKey': licenseKey,
        'deviceId': deviceId,
        'appVersion': appVersion,
        'usageMetrics': _collectAnonymousMetrics(),
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final verified = _verifySignature(data);
      
      if (verified) {
        await _secureStorage.write(
          key: 'license_data',
          value: jsonEncode(data),
        );
        return true;
      }
    }
    return false;
  } catch (e) {
    // Use cached license if offline
    return _checkCachedLicense();
  }
}
``` 