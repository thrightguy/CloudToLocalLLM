# Contributing to CloudToLocalLLM

## 🎉 Welcome Contributors!

Thank you for your interest in contributing to CloudToLocalLLM! This project aims to bridge cloud-based LLM interfaces with local execution, and we welcome contributions from developers of all skill levels.

**Current Version**: v3.4.0+ (Unified Flutter-Native Architecture)

---

## 🚀 **Quick Start**

### **1. Get Started**
```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/CloudToLocalLLM.git
cd CloudToLocalLLM

# Set up development environment
flutter pub get
flutter config --enable-linux-desktop

# Run the application
flutter run -d linux
```

### **2. Make Your First Contribution**
- 🐛 **Fix a Bug**: Check [good first issues](https://github.com/imrightguy/CloudToLocalLLM/labels/good%20first%20issue)
- 📝 **Improve Documentation**: Help us keep docs current and clear
- ✨ **Add a Feature**: Implement something from our roadmap
- 🧪 **Write Tests**: Improve test coverage

---

## 📋 **How to Contribute**

### **Types of Contributions**

#### **🐛 Bug Reports**
- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include steps to reproduce
- Provide system information (OS, Flutter version, etc.)
- Add screenshots or logs if helpful

#### **✨ Feature Requests**
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md)
- Explain the use case and benefits
- Consider implementation complexity
- Discuss in GitHub Discussions first for major features

#### **📝 Documentation**
- Fix typos and improve clarity
- Add missing documentation
- Update outdated information
- Create tutorials and examples

#### **💻 Code Contributions**
- Bug fixes and improvements
- New features and enhancements
- Performance optimizations
- Test coverage improvements

---

## 🛠️ **Development Setup**

### **Prerequisites**
- **Flutter SDK**: 3.8.0 or later
- **Git**: For version control
- **IDE**: VS Code (recommended) or Android Studio
- **Platform Tools**: Linux/Windows/macOS development tools

### **Environment Setup**
```bash
# Verify Flutter installation
flutter doctor

# Install dependencies
flutter pub get

# Enable desktop development
flutter config --enable-linux-desktop
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop

# Run tests to verify setup
flutter test
```

### **Project Structure**
```
lib/
├── components/     # Reusable UI components
├── config/        # App configuration
├── models/        # Data models
├── screens/       # UI screens
├── services/      # Core services (tray, connections, etc.)
├── shared/        # Shared utilities
└── widgets/       # Custom widgets
```

---

## 📝 **Contribution Workflow**

### **1. Before You Start**
- 🔍 **Check Existing Issues**: Avoid duplicate work
- 💬 **Discuss Major Changes**: Use GitHub Discussions
- 📖 **Read Documentation**: Understand the architecture
- 🎯 **Follow Roadmap**: Align with project priorities

### **2. Development Process**

#### **Create a Branch**
```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Or bug fix branch
git checkout -b fix/issue-description
```

#### **Make Changes**
- Follow [coding standards](#coding-standards)
- Write tests for new functionality
- Update documentation as needed
- Test on target platforms

#### **Commit Guidelines**
```bash
# Use conventional commit format
git commit -m "feat: add system tray connection status indicator"
git commit -m "fix: resolve memory leak in chat service"
git commit -m "docs: update installation guide for v3.4.0"

# Commit types:
# feat: new feature
# fix: bug fix
# docs: documentation
# style: formatting
# refactor: code restructuring
# test: adding tests
# chore: maintenance
```

### **3. Pull Request Process**

#### **Before Submitting**
- ✅ All tests pass (`flutter test`)
- ✅ Code follows style guidelines (`flutter analyze`)
- ✅ Documentation is updated
- ✅ No merge conflicts with main branch

#### **Create Pull Request**
1. **Push Branch**: `git push origin feature/your-feature-name`
2. **Open PR**: Use the provided PR template
3. **Describe Changes**: Explain what and why
4. **Link Issues**: Reference related issues with `Fixes #123`
5. **Request Review**: Tag relevant maintainers

#### **PR Requirements**
- **Clear Title**: Descriptive and concise
- **Detailed Description**: What changes and why
- **Testing**: How you tested the changes
- **Screenshots**: For UI changes
- **Breaking Changes**: Clearly marked if any

---

## 🎨 **Coding Standards**

### **Flutter/Dart Guidelines**
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter_lints` package rules (already configured)
- Prefer composition over inheritance
- Use meaningful names for variables and functions

### **Code Organization**
```dart
// File structure
/// Brief description of the file's purpose
/// 
/// Longer description if needed with usage examples.

// Imports (grouped and sorted)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

// Class definition
/// Widget for displaying chat messages with proper formatting
class ChatMessageWidget extends StatelessWidget {
  // Implementation
}
```

### **Documentation Standards**
```dart
/// Service for managing native system tray functionality.
/// 
/// Provides cross-platform system tray integration using the tray_manager
/// package with real-time connection status updates.
/// 
/// Example usage:
/// ```dart
/// final trayService = NativeTrayService();
/// await trayService.initialize(
///   tunnelManager: tunnelManager,
///   onShowWindow: () => showMainWindow(),
/// );
/// ```
class NativeTrayService {
  /// Initialize the native tray service with required callbacks.
  /// 
  /// Returns `true` if initialization was successful, `false` otherwise.
  Future<bool> initialize({
    required TunnelManagerService tunnelManager,
    VoidCallback? onShowWindow,
  }) async {
    // Implementation
  }
}
```

---

## 🧪 **Testing Guidelines**

### **Test Types**
- **Unit Tests**: Test individual functions and classes
- **Widget Tests**: Test UI components
- **Integration Tests**: Test complete user flows

### **Writing Tests**
```dart
// Unit test example
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/chat_service.dart';

void main() {
  group('ChatService', () {
    late ChatService chatService;
    
    setUp(() {
      chatService = ChatService();
    });
    
    test('should create new conversation', () {
      final conversation = chatService.createConversation();
      expect(conversation.id, isNotNull);
      expect(chatService.conversations, contains(conversation));
    });
  });
}
```

### **Running Tests**
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/chat_service_test.dart

# Run with coverage
flutter test --coverage
```

---

## 🔍 **Review Process**

### **What We Look For**
- ✅ **Functionality**: Does it work as intended?
- ✅ **Code Quality**: Is it readable and maintainable?
- ✅ **Tests**: Are there adequate tests?
- ✅ **Documentation**: Is it properly documented?
- ✅ **Performance**: Does it impact app performance?
- ✅ **Compatibility**: Works across target platforms?

### **Review Timeline**
- **Initial Response**: Within 48 hours
- **Full Review**: Within 1 week
- **Follow-up**: Within 24 hours of updates

### **Addressing Feedback**
- Respond to all review comments
- Make requested changes promptly
- Ask questions if feedback is unclear
- Update tests and docs as needed

---

## 🏷️ **Issue Labels**

- `good first issue`: Perfect for newcomers
- `bug`: Something isn't working
- `enhancement`: New feature or improvement
- `documentation`: Documentation improvements
- `help wanted`: Extra attention needed
- `priority: high`: Important issues
- `platform: linux`: Linux-specific issues
- `platform: windows`: Windows-specific issues
- `component: tray`: System tray related

---

## 📞 **Getting Help**

### **Where to Ask**
- **GitHub Discussions**: General questions and ideas
- **GitHub Issues**: Bug reports and feature requests
- **PR Comments**: Code-specific questions
- **Developer Onboarding**: See [docs/DEVELOPMENT/DEVELOPER_ONBOARDING.md](docs/DEVELOPMENT/DEVELOPER_ONBOARDING.md)

### **Response Times**
- **Discussions**: 1-2 days
- **Issues**: 2-3 days
- **PRs**: 1 week for review

---

## 🎯 **Project Priorities**

### **Current Focus (v3.4.0+)**
1. **Unified Architecture**: Completing Flutter-native integration
2. **Cross-Platform Support**: Windows and macOS compatibility
3. **Performance**: Optimizing system tray and connection handling
4. **Documentation**: Keeping docs current with architecture changes

### **Future Roadmap**
- Enhanced web interface features
- Mobile platform support
- Advanced LLM integration options
- Plugin system for extensibility

---

## 📜 **Code of Conduct**

We are committed to providing a welcoming and inclusive environment. Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

### **Our Standards**
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain professional communication

---

## 🙏 **Recognition**

Contributors are recognized in:
- **README.md**: Major contributors listed
- **Release Notes**: Contributions acknowledged
- **GitHub**: Contributor graphs and statistics

---

**Thank you for contributing to CloudToLocalLLM! Together, we're building the future of local AI with cloud convenience.**
