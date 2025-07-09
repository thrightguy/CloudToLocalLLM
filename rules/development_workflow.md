# Development Workflow Rules

## Core Principles

### 1. Fix First, Enhance Later
- **ALWAYS** prioritize fixing broken functionality over adding new features
- When user reports issues, focus on root cause analysis and direct fixes
- Avoid suggesting "improvements" or "enhancements" unless explicitly requested
- Ask for clarification if unsure whether to fix or enhance

### 2. Information Gathering First
- **ALWAYS** call `codebase-retrieval` before making any code changes
- Gather comprehensive information about ALL symbols involved in the edit
- Ask for classes, methods, properties, and dependencies in a single detailed call
- Never assume you understand the codebase without current information

### 3. Use Established Tools and Patterns
- Use `flutter pub` commands for dependency management, never edit package files manually
- Follow existing platform abstraction patterns
- Use established logging prefixes (🦙 [ModelManager], ⚙️ [Settings], etc.)
- Leverage existing scripts in `/scripts` folder rather than creating new ones

## Workflow Steps

### Before Any Code Changes
1. Use `codebase-retrieval` to understand current implementation
2. Identify the specific problem or requirement
3. Check for existing solutions or patterns in the codebase
4. Plan the minimal change needed to fix the issue

### During Implementation
1. Use `str-replace-editor` for modifications, never rewrite entire files
2. Make conservative changes that respect existing architecture
3. Follow platform abstraction patterns (AuthServicePlatform factory, etc.)
4. Maintain cross-platform compatibility

### After Changes
1. Suggest running `flutter analyze` to check for issues
2. Recommend writing/updating tests
3. Verify changes work across supported platforms
4. Document any breaking changes or new requirements

## Testing Requirements
- Always suggest testing after code changes
- Use existing test patterns and infrastructure
- Write unit tests for services using mockito
- Use integration tests for end-to-end workflows
- Test platform-specific functionality on appropriate platforms

## Version and Release Management
- Use `scripts/powershell/version_manager.ps1` for version updates
- Follow established build and deployment workflows
- Never manually edit version files
- Commit ALL related changes in comprehensive commits with descriptive messages

## Error Handling
- If stuck in loops or rabbit holes, ask user for help immediately
- Don't repeatedly call the same tools without progress
- When build issues occur, focus on root cause analysis
- Use systematic troubleshooting approach, not workarounds
