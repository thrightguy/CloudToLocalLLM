# Augment Import Guidelines for CloudToLocalLLM

## Overview
These markdown files are specifically formatted for import into Augment's settings interface. They contain streamlined guidelines to help the AI assistant stay focused on fixing existing functionality rather than adding new features.

## Import Instructions
1. Open Augment settings in VSCode
2. Navigate to the "Import Guidelines" section
3. Import each file individually in this order:
   - `core-workflow-guidelines.md` (Primary workflow rules)
   - `focus-and-priorities.md` (Priority management and scope control)
   - `technical-standards.md` (Code quality and technical requirements)

## File Descriptions

### core-workflow-guidelines.md
- Primary directive to fix before enhancing
- Mandatory information gathering requirements
- Code modification rules and platform abstraction
- Testing and quality assurance standards

### focus-and-priorities.md
- Problem identification protocol
- Priority hierarchy for different issue types
- Decision framework for scope management
- Anti-patterns to avoid (feature creep, over-engineering)

### technical-standards.md
- Code editing standards and dependency management
- Platform abstraction requirements
- Service implementation and security standards
- Quality assurance checklist and prohibited actions

## Key Benefits
- **Concise Format**: Optimized for Augment's import system
- **Actionable Directives**: Clear, specific instructions
- **Scope Control**: Prevents feature creep and over-engineering
- **Quality Focus**: Maintains code standards and testing requirements
- **Platform Compliance**: Ensures cross-platform compatibility

## Usage Notes
- These guidelines complement the detailed rules in the main `rules/` folder
- Import all three files for complete coverage
- The guidelines are specifically tailored for the CloudToLocalLLM project
- They emphasize fixing existing functionality over adding new features

## Troubleshooting
If import issues occur:
1. Ensure files are in valid markdown format
2. Check that file sizes are reasonable (under 10KB each)
3. Import files one at a time rather than in bulk
4. Restart VSCode if guidelines don't appear to be applied
