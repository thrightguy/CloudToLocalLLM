# Focus and Priorities Guidelines

## Primary Focus: Fix Existing Functionality

### 1. Problem Identification
- **ALWAYS** ask "What is broken?" before "What can be improved?"
- Focus on user-reported issues and failing functionality
- Prioritize fixes that impact release process, core features, or cross-platform compatibility
- Address TODO/FIXME comments that indicate broken or incomplete functionality

### 2. Root Cause Analysis
- Investigate the underlying cause, not just symptoms
- Use systematic troubleshooting approach
- Avoid workarounds when direct fixes are possible
- Document findings to prevent regression

### 3. Scope Management
- Fix the specific issue without expanding scope
- Resist urge to "improve while we're here"
- Ask user for permission before adding enhancements
- Complete current fix before suggesting related improvements

## Priority Hierarchy

### 1. Critical Issues (Immediate Action)
- Build failures preventing releases
- Authentication/security vulnerabilities
- Cross-platform compatibility breaks
- Data loss or corruption issues
- Service crashes or infinite loops

### 2. High Priority (Same Session)
- Feature functionality completely broken
- Performance issues affecting user experience
- Integration failures between services
- Platform-specific functionality not working
- Static analysis errors preventing clean builds

### 3. Medium Priority (Next Session)
- Partial feature functionality issues
- Minor UI/UX problems
- Documentation inaccuracies
- Non-critical performance optimizations
- Code quality improvements

### 4. Low Priority (Future Consideration)
- Feature enhancements
- New functionality requests
- Cosmetic improvements
- Nice-to-have optimizations
- Experimental features

## Decision Framework

### When User Reports an Issue
1. **Understand the problem completely** before proposing solutions
2. **Gather all relevant information** using codebase-retrieval
3. **Identify the minimal fix** that resolves the issue
4. **Implement the fix** without adding unrelated changes
5. **Test the fix** and suggest verification steps

### When Tempted to Add Features
1. **Stop and ask**: "Did the user request this feature?"
2. **If no**: Focus on the original issue only
3. **If unclear**: Ask for clarification before proceeding
4. **If yes**: Implement after fixing any existing issues first

### When Multiple Issues Exist
1. **Prioritize by impact**: Release-blocking > User-facing > Internal
2. **Consider dependencies**: Fix foundational issues first
3. **Ask user for priority guidance** if unclear
4. **Complete one issue fully** before starting another

## Communication Guidelines

### 1. Clarification Requests
- Ask specific questions when requirements are unclear
- Don't assume user wants enhancements beyond stated needs
- Confirm scope before implementing significant changes
- Request priority guidance when multiple issues exist

### 2. Progress Updates
- Focus on fixing the reported issue
- Mention if additional issues are discovered
- Ask permission before expanding scope
- Report when stuck and need guidance

### 3. Solution Proposals
- Present the minimal fix first
- Mention potential enhancements separately
- Let user decide on additional improvements
- Focus on solving the immediate problem

## Anti-Patterns to Avoid

### 1. Feature Creep
- Adding "helpful" features not requested
- Improving code "while we're here"
- Suggesting enhancements during bug fixes
- Expanding scope without permission

### 2. Over-Engineering
- Creating complex solutions for simple problems
- Adding abstractions not needed for the fix
- Implementing future-proofing not requested
- Building frameworks when fixes are needed

### 3. Assumption Making
- Assuming user wants improvements
- Guessing at requirements instead of asking
- Implementing based on what "should" be done
- Making decisions without user input

## Success Metrics

### 1. Issue Resolution
- Original problem is completely fixed
- No new issues introduced by the fix
- Solution is minimal and targeted
- User confirms issue is resolved

### 2. Code Quality
- Zero flutter analyze issues
- Existing tests pass
- New tests added if appropriate
- Code follows established patterns

### 3. User Satisfaction
- User's immediate need is met
- No unexpected changes or additions
- Clear communication throughout process
- Efficient resolution without scope creep
