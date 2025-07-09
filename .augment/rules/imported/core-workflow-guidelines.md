---
type: "manual"
---

# CloudToLocalLLM Core Workflow Guidelines

## Primary Directive
**ALWAYS prioritize fixing broken functionality over adding new features.**

## Before Any Code Changes
1. **MANDATORY**: Call `codebase-retrieval` with detailed requests for ALL symbols involved
2. Identify the specific problem or requirement
3. Check for existing solutions or patterns in the codebase
4. Plan the minimal change needed to fix the issue

## Code Modification Rules
1. **NEVER** rewrite entire files - use `str-replace-editor` for targeted changes
2. **ALWAYS** use `flutter pub` commands for dependency management
3. Follow existing platform abstraction patterns (AuthServicePlatform factory)
4. Preserve existing code structure, formatting, and imports
5. Maintain cross-platform compatibility (web/desktop/mobile)

## Information Gathering Requirements
- Ask for classes, methods, properties, and dependencies in a single detailed call
- Include context about how components interact
- Get information about platform-specific implementations
- Never assume understanding without current codebase information

## Platform Abstraction Compliance
- Use conditional imports with stub files for unsupported platforms
- Use `kIsWeb` for web-specific code detection
- Maintain single codebase across all platforms
- Follow established service factories and dependency injection

## Testing and Quality Assurance
- Always suggest running `flutter analyze` after changes
- Recommend writing/updating tests using existing patterns
- Use mockito for unit tests, integration tests for end-to-end workflows
- Ensure zero static analysis issues before completion

## Error Handling Protocol
- If stuck in loops or rabbit holes, ask user for help immediately
- Don't repeatedly call the same tools without progress
- Focus on root cause analysis, not workarounds
- Use systematic troubleshooting approach

## Version and Release Management
- Use `scripts/powershell/version_manager.ps1` for version updates
- Follow established build and deployment workflows
- Never manually edit version files
- Commit ALL related changes with descriptive messages

## Established Tools and Patterns
- Use established logging prefixes (🦙 [ModelManager], ⚙️ [Settings])
- Leverage existing scripts in `/scripts` folder
- Follow existing error handling and logging patterns
- Maintain service isolation and independence
