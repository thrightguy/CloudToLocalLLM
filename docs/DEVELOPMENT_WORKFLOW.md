# CloudToLocalLLM Development Workflow

This document describes the automated development workflow for CloudToLocalLLM, designed to streamline the development process and ensure consistent code quality.

## Overview

The development workflow includes automated tools for:
- ✅ Code quality validation (flutter analyze, PSScriptAnalyzer)
- ✅ Documentation completeness checking
- ✅ Automatic commit message generation
- ✅ Automated commit and push when documentation is complete
- ✅ Platform abstraction pattern compliance

## Quick Start

### 1. Daily Development Workflow

When you've completed development work and documentation:

```bash
# Quick commit and push with auto-generated message
.\push-dev.ps1

# With custom commit message
.\push-dev.ps1 -m "Implement zrok service with platform abstraction"

# Preview changes without committing
.\push-dev.ps1 -dry
```

### 2. Comprehensive Development Workflow

For full validation and workflow automation:

```bash
# Complete workflow with all validations
.\scripts\powershell\Complete-DevWorkflow.ps1

# Skip static analysis (faster, but not recommended)
.\scripts\powershell\Complete-DevWorkflow.ps1 -SkipAnalysis

# Create development release after push
.\scripts\powershell\Complete-DevWorkflow.ps1 -CreateDevRelease
```

## Workflow Components

### 1. Auto-Commit Script (`Auto-CommitAndPush.ps1`)

**Purpose**: Quickly commit and push development changes
**Features**:
- Automatic commit message generation based on file changes
- Quick flutter analyze validation
- Dry run mode for previewing changes
- Force mode to skip validations

**Usage**:
```bash
.\scripts\powershell\Auto-CommitAndPush.ps1 [options]
```

### 2. Complete Development Workflow (`Complete-DevWorkflow.ps1`)

**Purpose**: Comprehensive development workflow automation
**Features**:
- Documentation completeness validation
- Full static analysis (flutter analyze + PSScriptAnalyzer)
- Automatic commit message generation
- Git hooks installation
- Development release creation

**Usage**:
```bash
.\scripts\powershell\Complete-DevWorkflow.ps1 [options]
```

### 3. Quick Push Script (`push-dev.ps1`)

**Purpose**: Simple shortcut for daily development
**Features**:
- Minimal interface with short parameter names
- Calls Auto-CommitAndPush.ps1 with simplified parameters

**Usage**:
```bash
.\push-dev.ps1 [-m "message"] [-f] [-dry]
```

### 4. Git Hooks (Optional)

**Purpose**: Automatic push when documentation is complete
**Setup**:
```bash
Copy-Item scripts/git-hooks/post-commit .git/hooks/post-commit -Force
chmod +x .git/hooks/post-commit  # Linux/macOS only
```

## Validation Checks

### 1. Flutter Analysis
- Runs `flutter analyze` to check for Dart/Flutter issues
- Must pass with zero issues (unless forced)
- Ensures code quality and consistency

### 2. PowerShell Script Analysis
- Runs `PSScriptAnalyzer` on all PowerShell scripts
- Checks for syntax errors and best practices
- Maintains script quality standards

### 3. Documentation Completeness
- Validates presence of required documentation files
- Checks for proper documentation in new service implementations
- Ensures zrok service has appropriate documentation

### 4. Platform Abstraction Compliance
- Validates that new services follow platform abstraction patterns
- Ensures cross-platform compatibility
- Maintains CloudToLocalLLM architectural standards

## Commit Message Generation

The workflow automatically generates commit messages based on detected changes:

### Change Detection
- **Zrok changes**: "zrok service implementation"
- **Ngrok deletions**: "ngrok service removal"
- **Documentation**: "documentation updates"
- **Tests**: "test updates"

### Message Format
```
Development: [detected components]

Changes:
- New files: X
- Modified files: Y
- Deleted files: Z

Maintains platform abstraction patterns and CloudToLocalLLM standards.
```

## Best Practices

### 1. Regular Commits
- Use `.\push-dev.ps1` frequently during development
- Don't let uncommitted changes accumulate
- Commit logical units of work

### 2. Documentation First
- Complete documentation before running workflow
- Ensure new services have proper documentation
- Update README.md for significant changes

### 3. Validation Compliance
- Fix flutter analyze issues before committing
- Ensure PowerShell scripts pass PSScriptAnalyzer
- Don't use `-Force` unless absolutely necessary

### 4. Platform Abstraction
- Follow established patterns for new services
- Maintain cross-platform compatibility
- Use conditional imports and platform-specific implementations

## Troubleshooting

### Common Issues

**Flutter analyze fails**:
```bash
# Fix issues manually, then retry
flutter analyze
.\push-dev.ps1
```

**PSScriptAnalyzer issues**:
```bash
# Check specific script
Invoke-ScriptAnalyzer -Path scripts/powershell/YourScript.ps1
```

**Documentation incomplete**:
- Ensure all new services have proper documentation
- Update README.md for significant changes
- Add documentation comments to new classes/methods

**Git push fails**:
```bash
# Check remote status
git status
git pull origin master
.\push-dev.ps1
```

### Force Options

Use force options sparingly and only when necessary:

```bash
# Skip all validations (use with caution)
.\push-dev.ps1 -f

# Skip specific validations
.\scripts\powershell\Complete-DevWorkflow.ps1 -SkipAnalysis -Force
```

## Integration with Release Workflow

The development workflow integrates with the release workflow:

1. **Development**: Use `push-dev.ps1` for daily commits
2. **Pre-release**: Use `Complete-DevWorkflow.ps1` for validation
3. **Release**: Use release scripts for version management and deployment

This ensures a smooth transition from development to release while maintaining code quality throughout the process.

## Summary

The CloudToLocalLLM development workflow provides:
- 🚀 **Speed**: Quick commits with `.\push-dev.ps1`
- 🔍 **Quality**: Automated validation and analysis
- 📚 **Documentation**: Completeness checking and enforcement
- 🔄 **Consistency**: Standardized commit messages and patterns
- 🛡️ **Safety**: Validation checks prevent broken commits

Use these tools to maintain high code quality while streamlining your development process.
