---
description: "Create technical design from requirements: /spec-design <feature-name>"
---

# Design Technical Specification

## Feature: $ARGUMENTS

Transform requirements into detailed technical design with implementation blueprint.

## Prerequisites
- Feature directory exists in `SPECS/active/{feature-name}/`
- Requirements.md is complete
- Open questions are resolved
- If SPECS structure doesn't exist, run `/spec-init` first

## Process

1. **Load Context**
   - Read `requirements.md`
   - Load `.progress.json`
   - Check cached context
   - Update phase to "design"

2. **Deep Codebase Analysis**
   - Search for architectural patterns
   - Identify similar implementations
   - Review tech stack usage
   - Check existing integrations
   - Document findings in context/

3. **Technical Research**
   - Library documentation (specific versions)
   - Best practices for chosen approach
   - Known issues and workarounds
   - Performance considerations
   - Security implications

4. **Design Decisions**
   For each major component:
   - **Approach**: How to implement
   - **Alternatives**: Other options considered
   - **Rationale**: Why this approach
   - **Trade-offs**: Pros and cons

5. **Create Technical Design**
   Using `templates/design.md`:
   - Architecture diagrams
   - Data models
   - API specifications
   - Integration points
   - Error handling strategy
   - Performance approach
   - Security measures

6. **Generate Detailed Tasks**
   Create `tasks.md` with:
   - Granular task breakdown
   - Dependencies mapped
   - Time estimates
   - Acceptance criteria
   - Validation commands

7. **Prepare Validation Plan**
   Create `validation.md` with:
   - Test strategies
   - Quality gates
   - Performance benchmarks
   - Security checks

8. **Cache Research Artifacts**
   Save to `context/`:
   - Code snippets
   - Documentation links
   - Example implementations
   - Decision rationale

## Validation
Before completing:
- [ ] All requirements addressed
- [ ] No ambiguous implementations
- [ ] Tasks are atomic and clear
- [ ] Validation is executable
- [ ] Context is comprehensive

## Output
```
✅ Technical design complete
📐 Architecture documented with {X} components
📋 Generated {Y} implementation tasks
🔍 Cached {Z} reference artifacts

Design confidence score: {8.5}/10

Ready for implementation:
- Run: /spec-build {feature-name}
- Or use agent: @@spec-builder on SPECS/active/{feature-name}
```

## Notes
- Use ULTRATHINK to ensure design completeness
- Include enough context for one-pass implementation
- Reference specific files and line numbers
- Document all assumptions explicitly