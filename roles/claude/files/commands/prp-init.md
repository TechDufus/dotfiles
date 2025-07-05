---
description: "Initialize a feature file through interactive interrogation: /prp-init <initial-description>"
---

# Initialize Feature File

## Initial Description: $ARGUMENTS

Create a comprehensive feature file by analyzing the codebase and interrogating the user for missing details.

## Process

1. **Parse Initial Description**
   - Extract the core feature request
   - Identify what type of feature (UI, API, CLI, service, etc.)
   - Note any mentioned constraints or requirements

2. **Codebase Analysis**
   - Search for similar features to understand patterns
   - Identify relevant files and modules
   - Check existing conventions and architecture
   - Look for potential integration points
   - Review test patterns for similar features

3. **Context Gathering**
   - Analyze tech stack and frameworks in use
   - Check for existing utilities that could be leveraged
   - Identify potential dependencies
   - Review configuration patterns

4. **Interrogation Phase**
   Ask targeted questions to fill gaps:

   **Core Questions:**
   - Who will use this feature? (end users, developers, system)
   - What problem does this solve?
   - What's the expected behavior/workflow?
   - What are the success criteria?

   **Technical Questions:**
   - Any specific libraries/APIs to use or avoid?
   - Performance requirements?
   - Security considerations?
   - Data persistence needs?
   - Integration with existing features?

   **Implementation Questions:**
   - Preferred patterns from the codebase to follow?
   - Any similar features to model after?
   - Specific error handling requirements?
   - Logging/monitoring needs?

   **Scope Questions:**
   - MVP vs full implementation?
   - Any features explicitly out of scope?
   - Future extensibility considerations?

5. **Feature File Generation**
   Create a structured feature file with:
   ```markdown
   # Feature: [Name]
   
   ## Overview
   [Brief description from initial input + gathered context]
   
   ## Problem Statement
   [Why this feature is needed]
   
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
   [How it fits in the system]
   
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
   [Code snippets, API calls, UI mockups if applicable]
   
   ## References
   - [Relevant docs, similar features]
   ```

6. **Validation**
   - Show the generated feature file
   - Ask: "Does this capture your vision? What needs adjustment?"
   - Refine based on feedback

## Output
Save as: `PRPs/features/{feature-name}.feature.md`

## Notes
- Be concise but thorough in interrogation
- Focus on uncovering implicit requirements
- Reference existing code patterns discovered
- Ensure the feature file has enough context for /prp-generate