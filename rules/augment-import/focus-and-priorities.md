# CloudToLocalLLM Focus and Priorities

## Primary Focus
**Fix existing functionality. Do not add new features unless explicitly requested.**

## Problem Identification Protocol
- **ALWAYS** ask "What is broken?" before "What can be improved?"
- Focus on user-reported issues and failing functionality
- Prioritize fixes that impact release process, core features, or cross-platform compatibility
- Address TODO/FIXME comments indicating broken functionality

## Priority Hierarchy
### Critical (Immediate Action)
- Build failures preventing releases
- Authentication/security vulnerabilities
- Cross-platform compatibility breaks
- Data loss or corruption issues
- Service crashes or infinite loops

### High Priority (Same Session)
- Feature functionality completely broken
- Performance issues affecting user experience
- Integration failures between services
- Platform-specific functionality not working
- Static analysis errors preventing clean builds

### Medium Priority (Next Session)
- Partial feature functionality issues
- Minor UI/UX problems
- Documentation inaccuracies
- Non-critical performance optimizations

### Low Priority (Future Consideration)
- Feature enhancements
- New functionality requests
- Cosmetic improvements
- Experimental features

## Decision Framework
### When User Reports an Issue
1. Understand the problem completely before proposing solutions
2. Gather all relevant information using codebase-retrieval
3. Identify the minimal fix that resolves the issue
4. Implement the fix without adding unrelated changes
5. Test the fix and suggest verification steps

### When Tempted to Add Features
1. Stop and ask: "Did the user request this feature?"
2. If no: Focus on the original issue only
3. If unclear: Ask for clarification before proceeding
4. If yes: Implement after fixing any existing issues first

### When Multiple Issues Exist
1. Prioritize by impact: Release-blocking > User-facing > Internal
2. Consider dependencies: Fix foundational issues first
3. Ask user for priority guidance if unclear
4. Complete one issue fully before starting another

## Scope Management Rules
- Fix the specific issue without expanding scope
- Resist urge to "improve while we're here"
- Ask user for permission before adding enhancements
- Complete current fix before suggesting related improvements

## Anti-Patterns to Avoid
### Feature Creep
- Adding "helpful" features not requested
- Improving code "while we're here"
- Suggesting enhancements during bug fixes
- Expanding scope without permission

### Over-Engineering
- Creating complex solutions for simple problems
- Adding abstractions not needed for the fix
- Implementing future-proofing not requested
- Building frameworks when fixes are needed

### Assumption Making
- Assuming user wants improvements
- Guessing at requirements instead of asking
- Implementing based on what "should" be done
- Making decisions without user input

## Communication Guidelines
- Ask specific questions when requirements are unclear
- Don't assume user wants enhancements beyond stated needs
- Confirm scope before implementing significant changes
- Present the minimal fix first, mention enhancements separately
