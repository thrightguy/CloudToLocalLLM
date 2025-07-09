---
type: "manual"
---

# CloudToLocalLLM AI Assistant Guidelines

## PRIMARY DIRECTIVE
**ALWAYS prioritize fixing broken functionality over adding new features.**

## MANDATORY WORKFLOW
1. **BEFORE ANY CODE CHANGES**: Call `codebase-retrieval` with detailed requests for ALL symbols involved
2. **IDENTIFY**: The specific problem or requirement
3. **CHECK**: For existing solutions or patterns in the codebase
4. **PLAN**: The minimal change needed to fix the issue
5. **IMPLEMENT**: Using `str-replace-editor` for targeted changes only
6. **TEST**: Suggest running `flutter analyze` and appropriate tests

## CODE MODIFICATION RULES
- **NEVER** rewrite entire files
- **ALWAYS** use `flutter pub` commands for dependency management
- **PRESERVE** existing code structure, formatting, and imports
- **FOLLOW** platform abstraction patterns (AuthServicePlatform factory)
- **MAINTAIN** cross-platform compatibility (web/desktop/mobile)
- **USE** conditional imports with stub files for unsupported platforms

## PRIORITY HIERARCHY
### Critical (Immediate)
- Build failures preventing releases
- Authentication/security vulnerabilities
- Cross-platform compatibility breaks
- Data loss or corruption issues

### High Priority
- Feature functionality completely broken
- Performance issues affecting user experience
- Integration failures between services
- Static analysis errors preventing clean builds

### Medium Priority
- Partial feature functionality issues
- Minor UI/UX problems
- Documentation inaccuracies

### Low Priority
- Feature enhancements
- New functionality requests
- Cosmetic improvements

## DECISION FRAMEWORK
### When User Reports Issue
1. Understand problem completely before proposing solutions
2. Gather all relevant information using codebase-retrieval
3. Identify minimal fix that resolves the issue
4. Implement fix without adding unrelated changes

### When Tempted to Add Features
1. Ask: "Did the user request this feature?"
2. If no: Focus on original issue only
3. If unclear: Ask for clarification before proceeding
4. If yes: Fix existing issues first

## SCOPE MANAGEMENT
- Fix specific issue without expanding scope
- Resist urge to "improve while we're here"
- Ask user permission before adding enhancements
- Complete current fix before suggesting improvements

## TECHNICAL STANDARDS
### Authentication & Security
- Use Auth0 with platform-specific redirect URIs
- Implement JWT validation with RS256 tokens
- Follow PKCE flow for desktop authentication

### Configuration
- Centralize settings in AppConfig.dart
- Use compile-time constants for feature flags
- Follow established configuration patterns

### Testing
- Write unit tests using mockito for services
- Create integration tests for end-to-end workflows
- Ensure zero `flutter analyze` issues

## PROHIBITED ACTIONS
- Don't manually edit package configuration files
- Don't create new scripts when existing ones work
- Don't bypass established build and deployment workflows
- Don't create platform-specific code in shared modules
- Don't add features when fixing bugs
- Don't suggest improvements unless requested

## ERROR HANDLING
- If stuck in loops, ask user for help immediately
- Don't repeatedly call same tools without progress
- Focus on root cause analysis, not workarounds
- Use systematic troubleshooting approach

## SUCCESS CRITERIA
- Original problem completely fixed
- No new issues introduced
- Solution is minimal and targeted
- Zero flutter analyze issues
- User confirms issue resolved
