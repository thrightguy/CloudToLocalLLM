import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Documentation screen - web-only Flutter implementation
/// Replaces VitePress with native Flutter widgets for documentation
class DocumentationScreen extends StatefulWidget {
  const DocumentationScreen({super.key});

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen> {
  String _selectedSection = 'getting-started';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(child: Text('This page is only available on web')),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Row(
              children: [
                // Sidebar navigation
                Container(
                  width: 280,
                  decoration: const BoxDecoration(
                    color: Color(0xFF23243a),
                    border: Border(
                      right: BorderSide(color: Color(0xFF6e8efb), width: 1),
                    ),
                  ),
                  child: _buildSidebar(context),
                ),
                // Main content area
                Expanded(
                  child: Container(
                    color: const Color(0xFF181a20),
                    child: _buildMainContent(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6e8efb), Color(0xFFa777e3)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              // Logo
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF6e8efb),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFFa777e3), width: 2),
                ),
                child: const Center(
                  child: Text(
                    'LLM',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFa777e3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Title
              Text(
                'CloudToLocalLLM Documentation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              // Search bar
              Container(
                width: 300,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search documentation...',
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Back to home
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text(
                  '← Back to Home',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Column(
      children: [
        // Search results or navigation
        if (_searchQuery.isNotEmpty)
          _buildSearchResults()
        else
          _buildNavigationTree(),
      ],
    );
  }

  Widget _buildSearchResults() {
    // Filter documentation sections based on search query
    final results = _getSearchResults(_searchQuery);

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final result = results[index];
          return ListTile(
            title: Text(
              result['title']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              result['excerpt']!,
              style: const TextStyle(color: Color(0xFFb0b0b0), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              setState(() {
                _selectedSection = result['id']!;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildNavigationTree() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNavSection('Getting Started', [
            _buildNavItem('getting-started', 'Quick Start Guide'),
            _buildNavItem('installation', 'Installation'),
            _buildNavItem('features', 'Features Overview'),
          ]),

          _buildNavSection('Architecture', [
            _buildNavItem('system-architecture', 'System Architecture'),
            _buildNavItem('unified-flutter-web', 'Unified Flutter Web'),
          ]),

          _buildNavSection('User Guide', [
            _buildNavItem('user-guide', 'User Guide'),
            _buildNavItem('features-guide', 'Features Guide'),
          ]),

          _buildNavSection('Deployment', [
            _buildNavItem('deployment-workflow', 'Complete Workflow'),
            _buildNavItem('versioning-strategy', 'Versioning Strategy'),
            _buildNavItem('github-releases', 'GitHub Releases'),
          ]),

          _buildNavSection('Operations', [
            _buildNavItem('self-hosting', 'Self Hosting'),
            _buildNavItem('infrastructure', 'Infrastructure Guide'),
          ]),

          _buildNavSection('Legal', [
            _buildNavItem('privacy', 'Privacy Policy'),
            _buildNavItem('terms', 'Terms of Service'),
          ]),
        ],
      ),
    );
  }

  Widget _buildNavSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFa777e3),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...items,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNavItem(String id, String title) {
    final isSelected = _selectedSection == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6e8efb).withValues(alpha: 0.2)
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6e8efb) : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedSection = id;
          });
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: _getContentForSection(_selectedSection),
      ),
    );
  }

  Widget _getContentForSection(String section) {
    switch (section) {
      case 'getting-started':
        return _buildGettingStartedContent();
      case 'installation':
        return _buildInstallationContent();
      case 'features':
        return _buildFeaturesContent();
      case 'system-architecture':
        return _buildSystemArchitectureContent();
      case 'unified-flutter-web':
        return _buildUnifiedFlutterWebContent();
      case 'user-guide':
        return _buildUserGuideContent();
      case 'features-guide':
        return _buildFeaturesGuideContent();
      case 'deployment-workflow':
        return _buildDeploymentWorkflowContent();
      case 'versioning-strategy':
        return _buildVersioningStrategyContent();
      case 'github-releases':
        return _buildGitHubReleasesContent();
      case 'self-hosting':
        return _buildSelfHostingContent();
      case 'infrastructure':
        return _buildInfrastructureContent();
      case 'privacy':
        return _buildPrivacyContent();
      case 'terms':
        return _buildTermsContent();
      default:
        return _buildGettingStartedContent();
    }
  }

  List<Map<String, String>> _getSearchResults(String query) {
    final allSections = [
      {
        'id': 'getting-started',
        'title': 'Getting Started',
        'excerpt': 'Quick start guide for CloudToLocalLLM',
      },
      {
        'id': 'installation',
        'title': 'Installation',
        'excerpt': 'How to install CloudToLocalLLM on your system',
      },
      {
        'id': 'features',
        'title': 'Features',
        'excerpt': 'Overview of CloudToLocalLLM features',
      },
      {
        'id': 'system-architecture',
        'title': 'System Architecture',
        'excerpt': 'Technical architecture overview',
      },
      {
        'id': 'unified-flutter-web',
        'title': 'Unified Flutter Web',
        'excerpt': 'New unified web architecture',
      },
      {
        'id': 'user-guide',
        'title': 'User Guide',
        'excerpt': 'Complete user guide for the application',
      },
      {
        'id': 'deployment-workflow',
        'title': 'Deployment Workflow',
        'excerpt': 'Complete deployment process',
      },
      {
        'id': 'self-hosting',
        'title': 'Self Hosting',
        'excerpt': 'How to self-host CloudToLocalLLM',
      },
    ];

    return allSections
        .where(
          (section) =>
              section['title']!.toLowerCase().contains(query.toLowerCase()) ||
              section['excerpt']!.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Documentation content methods
  Widget _buildGettingStartedContent() {
    return _buildDocumentationPage('Getting Started', '''
# Welcome to CloudToLocalLLM

CloudToLocalLLM is an innovative platform that lets you run AI language models on your own computer while managing them through a simple cloud interface.

## Quick Start

1. **Download and Install**
   - Visit the [download page](/download) for installation options
   - Choose your preferred installation method (AppImage, Debian, AUR, etc.)

2. **Configure Your LLM Provider**
   - Install Ollama locally for the best performance
   - Or use our cloud streaming service

3. **Start Chatting**
   - Launch the application
   - Create your first conversation
   - Begin chatting with your local LLM

## Key Features

- **Local Processing**: Run models on your own hardware
- **Cloud Management**: Manage everything through a web interface
- **Multi-Platform**: Available on Linux desktop and web
- **Privacy First**: Your data stays on your machine
- **Cost Effective**: No per-token charges

## Next Steps

- Read the [Installation Guide](installation) for detailed setup instructions
- Explore the [Features Guide](features-guide) to learn about all capabilities
- Check out the [User Guide](user-guide) for comprehensive usage instructions
      ''');
  }

  Widget _buildInstallationContent() {
    return _buildDocumentationPage('Installation Guide', '''
# Installation Guide

CloudToLocalLLM is available for Linux systems with multiple installation options.

## System Requirements

### Minimum Requirements
- **OS**: Any modern Linux distribution (kernel 4.15+)
- **Architecture**: x86_64 (64-bit)
- **Memory**: 512MB RAM minimum, 1GB recommended
- **Storage**: 200MB available space
- **Desktop**: GNOME, KDE Plasma, XFCE, or compatible

### For System Tray Support
- **Required**: libayatana-appindicator
- **GNOME Users**: AppIndicator extension recommended
- **Tiling WMs**: Status bar with system tray support

## Installation Methods

### 1. AppImage (Recommended)
Portable application that runs on any Linux distribution without installation.

```bash
# Download AppImage
wget https://cloudtolocalllm.online/cloudtolocalllm-2.1.1-x86_64.AppImage

# Make executable
chmod +x cloudtolocalllm-2.1.1-x86_64.AppImage

# Run directly
./cloudtolocalllm-2.1.1-x86_64.AppImage
```

### 2. Debian Package
Native package for Ubuntu, Debian, and derivatives.

```bash
# Download the package
wget https://cloudtolocalllm.online/dist/debian/cloudtolocalllm_2.1.1_amd64.deb

# Install with dpkg
sudo dpkg -i cloudtolocalllm_2.1.1_amd64.deb

# Install dependencies if needed
sudo apt-get install -f
```

### 3. AUR Package (Arch Linux)
Pre-built binary package for Arch Linux and derivatives.

```bash
# Install with yay
yay -S cloudtolocalllm

# Or using paru
paru -S cloudtolocalllm
```

## Post-Installation Setup

1. **Install Ollama** (for local LLM support)
```bash
curl -fsSL https://ollama.ai/install.sh | sh
sudo systemctl enable --now ollama
ollama pull llama2
```

2. **Configure System Tray** (if needed)
   - GNOME: Install AppIndicator extension
   - KDE: Check system tray widget configuration
   - XFCE: Add notification area to panel

For complete installation instructions, visit our [download page](/download).
      ''');
  }

  Widget _buildFeaturesContent() {
    return _buildDocumentationPage('Features Overview', '''
# Features Overview

CloudToLocalLLM provides a comprehensive set of features for local LLM management and cloud synchronization.

## Core Features

### 🖥️ Local LLM Processing
- Run models directly on your hardware
- Support for Ollama and LM Studio
- No internet required for inference
- Complete privacy and data control

### ☁️ Cloud Management
- Web-based interface for easy access
- Conversation synchronization across devices
- Remote model management
- Real-time streaming capabilities

### 🔒 Privacy & Security
- All processing happens locally
- Optional cloud features with encryption
- No data sent to third parties
- Open source and auditable

### 🚀 Performance
- Optimized for local hardware
- Efficient memory usage
- Fast response times
- Hardware acceleration support

## Platform Support

### Desktop Application
- Native Linux application
- System tray integration
- Offline functionality
- Direct hardware access

### Web Application
- Cross-platform browser support
- Real-time chat interface
- Cloud streaming capabilities
- Responsive design

## Model Management

### Supported Providers
- **Ollama**: Primary local provider
- **LM Studio**: Alternative local provider
- **Cloud Streaming**: Fallback option

### Model Features
- Automatic model discovery
- One-click model installation
- Model performance monitoring
- Hardware compatibility checking

## Advanced Features

### Tunnel Management
- Secure cloud-to-local connections
- Health monitoring and failover
- Connection quality metrics
- Automatic reconnection

### Authentication
- Auth0 integration
- Secure token management
- Multi-device support
- Session persistence

### Configuration
- Flexible settings management
- Hot-reloadable configuration
- Environment-specific settings
- Backup and restore

## Coming Soon

- Mobile applications (iOS/Android)
- Additional model providers
- Enhanced collaboration features
- Plugin system for extensions
      ''');
  }

  // Helper method to build documentation pages with consistent styling
  Widget _buildDocumentationPage(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFa777e3),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildMarkdownContent(content),
      ],
    );
  }

  // Simple markdown-like content renderer
  Widget _buildMarkdownContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('# ')) {
        widgets.add(_buildHeading(line.substring(2), 1));
      } else if (line.startsWith('## ')) {
        widgets.add(_buildHeading(line.substring(3), 2));
      } else if (line.startsWith('### ')) {
        widgets.add(_buildHeading(line.substring(4), 3));
      } else if (line.startsWith('- ')) {
        widgets.add(_buildBulletPoint(line.substring(2)));
      } else if (line.startsWith('```')) {
        // Handle code blocks (simplified)
        continue;
      } else if (line.trim().startsWith('**') && line.trim().endsWith('**')) {
        widgets.add(
          _buildBoldText(line.trim().substring(2, line.trim().length - 2)),
        );
      } else {
        widgets.add(_buildParagraph(line));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildHeading(String text, int level) {
    double fontSize;
    FontWeight fontWeight;
    Color color;

    switch (level) {
      case 1:
        fontSize = 28;
        fontWeight = FontWeight.bold;
        color = const Color(0xFFa777e3);
        break;
      case 2:
        fontSize = 24;
        fontWeight = FontWeight.bold;
        color = const Color(0xFF6e8efb);
        break;
      case 3:
        fontSize = 20;
        fontWeight = FontWeight.w600;
        color = const Color(0xFF6e8efb);
        break;
      default:
        fontSize = 18;
        fontWeight = FontWeight.w500;
        color = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFf1f1f1),
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: Color(0xFF6e8efb),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFf1f1f1),
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoldText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFf1f1f1),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Placeholder methods for other content sections
  Widget _buildSystemArchitectureContent() {
    return _buildDocumentationPage('System Architecture', '''
# System Architecture

CloudToLocalLLM uses a modern, unified Flutter-based architecture that consolidates web functionality while maintaining desktop capabilities.

## Architecture Overview

### Unified Flutter Application
- Single codebase for all platforms
- Shared components and state management
- Platform-specific routing with kIsWeb detection
- Material Design 3 consistency

### Domain Structure
- **cloudtolocalllm.online**: Marketing homepage and download pages
- **app.cloudtolocalllm.online**: Chat interface and settings
- **docs.cloudtolocalllm.online**: Documentation (this page)

### Core Components

#### Authentication Service
- Auth0 integration with PKCE flow
- Platform-specific implementations
- Secure token management
- Multi-device synchronization

#### Tunnel Manager Service
- Local Ollama connection management
- Cloud proxy integration
- Health monitoring and failover
- Real-time status updates

#### Streaming Proxy Service
- WebSocket-based communication
- Real-time message streaming
- Connection multiplexing
- Error handling and recovery

## Deployment Architecture

### Multi-Container Setup
- **nginx-proxy**: Reverse proxy and SSL termination
- **flutter-app**: Main application container
- **api-backend**: Backend services and WebSocket handling

### Security Features
- SSL/TLS encryption
- CORS protection
- Rate limiting
- Authentication middleware

For detailed deployment information, see the [Deployment Workflow](deployment-workflow).
      ''');
  }

  Widget _buildUnifiedFlutterWebContent() {
    return _buildDocumentationPage('Unified Flutter Web Architecture', '''
# Unified Flutter Web Architecture

CloudToLocalLLM v3.4.0+ implements a unified Flutter-based web architecture that consolidates both marketing content and application functionality into a single codebase.

## Migration Benefits

### Before (Multi-Container)
- Separate static site container for marketing
- Different technologies (HTML/CSS vs Flutter)
- Complex deployment coordination
- Inconsistent design systems

### After (Unified Flutter)
- Single Flutter application for all web content
- Consistent Material Design 3 theming
- Simplified deployment and maintenance
- Shared state management and components

## Implementation Details

### Platform-Specific Routing
```dart
// Web: Show marketing homepage
// Desktop: Redirect to chat interface
if (kIsWeb) {
  return const HomepageScreen();
} else {
  return const HomeScreen();
}
```

### Domain Routing Strategy
- **Main Domain**: Marketing content with authentication bypass
- **App Subdomain**: Application features requiring authentication
- **Platform Detection**: Web-only routes excluded from desktop builds

## Technical Benefits

### Performance
- Single container for web functionality
- Shared Flutter assets and dependencies
- Reduced infrastructure complexity
- Faster build and deployment times

### Developer Experience
- Single codebase for all web features
- Consistent development environment
- Shared tooling and testing infrastructure
- Simplified debugging and monitoring

For implementation details, see the source code in `lib/screens/marketing/`.
      ''');
  }

  // Placeholder methods for remaining content sections
  Widget _buildUserGuideContent() {
    return _buildDocumentationPage(
      'User Guide',
      'Complete user guide content...',
    );
  }

  Widget _buildFeaturesGuideContent() {
    return _buildDocumentationPage(
      'Features Guide',
      'Detailed features guide content...',
    );
  }

  Widget _buildDeploymentWorkflowContent() {
    return _buildDocumentationPage(
      'Deployment Workflow',
      'Complete deployment workflow content...',
    );
  }

  Widget _buildVersioningStrategyContent() {
    return _buildDocumentationPage(
      'Versioning Strategy',
      'Versioning strategy content...',
    );
  }

  Widget _buildGitHubReleasesContent() {
    return _buildDocumentationPage(
      'GitHub Releases',
      'GitHub releases workflow content...',
    );
  }

  Widget _buildSelfHostingContent() {
    return _buildDocumentationPage(
      'Self Hosting',
      'Self hosting guide content...',
    );
  }

  Widget _buildInfrastructureContent() {
    return _buildDocumentationPage(
      'Infrastructure Guide',
      'Infrastructure guide content...',
    );
  }

  Widget _buildPrivacyContent() {
    return _buildDocumentationPage(
      'Privacy Policy',
      'Privacy policy content...',
    );
  }

  Widget _buildTermsContent() {
    return _buildDocumentationPage(
      'Terms of Service',
      'Terms of service content...',
    );
  }
}
