---
description: "Initialize a new spec-driven feature: /spec-init <feature-name> <description>"
---

# Initialize Spec-Driven Feature

## Feature: $ARGUMENTS

Create a new spec-driven development workflow with proper structure and tracking.

## Process

1. **Parse Arguments**
   - Extract feature name (kebab-case)
   - Extract initial description
   - Validate naming conventions

2. **Ensure SPECS Structure Exists**
   First, check if SPECS directory exists. If not:
   - Create `SPECS/{active,completed,templates,agents}` directories
   - Generate all template files in `SPECS/templates/`:
     - `requirements.md` - Business requirements template
     - `design.md` - Technical design template
     - `tasks.md` - Task breakdown template
     - `validation.md` - Quality gates template
     - `.progress.json` - Progress tracking template
   - Create `SPECS/README.md` with system overview
   - Display message: "✅ Created SPECS structure for spec-driven development"

3. **Create Feature Directory**
   ```bash
   mkdir -p SPECS/active/{feature-name}/context
   mkdir -p SPECS/active/{feature-name}/artifacts
   ```

3. **Initialize Progress Tracking**
   - Copy `.progress.json` template
   - Set initial timestamps
   - Update feature name and status

4. **Interactive Requirements Gathering**
   Ask targeted questions based on feature type:
   
   **Business Context:**
   - What problem does this solve?
   - Who are the users?
   - What's the expected outcome?
   - What's the business value?
   
   **Technical Context:**
   - What type of feature? (API, UI, CLI, Service, Library)
   - Any existing patterns to follow?
   - Integration points?
   - Performance requirements?
   
   **Scope & Constraints:**
   - MVP vs full implementation?
   - Timeline constraints?
   - Resource constraints?
   - What's explicitly out of scope?

5. **Generate Requirements Document**
   - Use `templates/requirements.md` as base
   - Fill in gathered information
   - Mark open questions
   - Save to `SPECS/active/{feature-name}/requirements.md`

6. **Initial Context Research**
   - Search codebase for similar features
   - Identify relevant documentation
   - Cache findings in `context/` directory

7. **Create Initial Task Outline**
   - Generate high-level phases
   - Estimate complexity
   - Note dependencies

8. **Set Up Validation Criteria**
   - Identify test requirements
   - Set coverage goals
   - Define success metrics

## Output

Display created structure and next steps:
```
✅ Created spec structure at: SPECS/active/{feature-name}/
📄 Requirements documented with {X} open questions
🔍 Found {Y} similar patterns in codebase
📋 Generated {Z} high-level tasks

Next steps:
1. Review requirements.md and answer open questions
2. Run: /spec-design {feature-name}
3. Or use agent: @@spec-designer on SPECS/active/{feature-name}
```

## Notes
- Encourage user to review and refine requirements
- Suggest using specialized agents for complex features
- Track all interactions in progress.json