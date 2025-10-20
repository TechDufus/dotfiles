---
description: "Initialize feature file through interrogation: /prp-init <description>"
---

Create a comprehensive feature file by analyzing the codebase and gathering requirements.

## Initial Description: $ARGUMENTS

## Process

### 1. Parse Initial Description
- Extract core feature request
- Identify feature type (UI, API, CLI, service, etc.)
- Note constraints and requirements

### 2. Codebase Analysis
Search for patterns and existing implementations:
- Similar features and their patterns
- Relevant files and modules
- Existing conventions and architecture
- Potential integration points
- Test patterns for similar features

### 3. Interactive Interrogation

Ask targeted questions to fill gaps:

**Core Questions:**
- Who will use this feature?
- What problem does this solve?
- Expected behavior/workflow?
- Success criteria?

**Technical Questions:**
- Specific libraries/APIs to use or avoid?
- Performance requirements?
- Security considerations?
- Data persistence needs?
- Integration with existing features?

**Implementation Questions:**
- Patterns from codebase to follow?
- Similar features to model after?
- Error handling requirements?
- Logging/monitoring needs?

**Scope Questions:**
- MVP vs full implementation?
- Features explicitly out of scope?
- Future extensibility considerations?

### 4. Generate Feature File

Create structured feature file in `PRPs/features/{feature-name}.feature.md`:

```markdown
# Feature: [Name]

## Overview
[Brief description + context]

## Problem Statement
[Why needed]

## Users/Stakeholders
[Who benefits and how]

## Requirements

### Functional
- [User-facing behaviors]

### Non-Functional
- Performance: [specifics]
- Security: [considerations]
- Scalability: [needs]

## Technical Specification

### Architecture
[How it fits in system]

### Dependencies
- External: [libraries, APIs]
- Internal: [modules, services]

### Data Model
[If applicable]

### API Design
[Endpoints, schemas if applicable]

## Implementation Notes

### Patterns to Follow
- [Reference specific files/patterns]

### Testing Strategy
- Unit: [approach]
- Integration: [approach]
- E2E: [if applicable]

## Success Criteria
- [ ] [Measurable outcomes]

## Out of Scope
- [What's not included]

## Future Considerations
- [Extensibility notes]

## Examples
[Code snippets, API calls, UI mockups]

## References
- [Relevant docs, similar features]
```

### 5. Validation
- Show generated feature file
- Ask for adjustments
- Refine based on feedback

## Notes
- Be concise but thorough
- Focus on uncovering implicit requirements
- Reference existing code patterns
- Ensure enough context for implementation
