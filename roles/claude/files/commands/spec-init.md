---
description: "Initialize a specification-driven feature with SPARC methodology: /spec-init <feature-name> [description]"
---

# Initialize Specification-Driven Feature

## Feature: $ARGUMENTS

Create a comprehensive specification using SPARC methodology (Specification, Pseudocode, Architecture, Refinement, Completion) with enhanced context gathering and artifact management.

## Process

### Phase 1: Parse & Validate

1. **Parse Arguments**
   - Extract feature name (kebab-case enforced)
   - Extract initial description if provided
   - Validate against naming conventions
   - Check for existing features with same name

2. **Initialize SPECS Infrastructure**
   First, ensure SPECS structure exists:
   ```
   SPECS/
   ├── active/          # Features in development
   ├── completed/       # Archived features
   ├── templates/       # Reusable patterns
   ├── agents/          # Specialized agent configs
   └── .sparc/          # Framework metadata
   ```
   
   Generate template files if missing:
   - `templates/specification.md` - Requirements & constraints
   - `templates/pseudocode.md` - Implementation blueprint
   - `templates/architecture.md` - Technical design
   - `templates/refinement.md` - Iteration patterns
   - `templates/completion.md` - Finalization checklist
   - `templates/validation-gates.md` - Quality criteria
   - `templates/.progress.json` - State tracking schema
   
   Display: "✅ SPECS infrastructure ready with SPARC templates"

3. **Create Feature Workspace**
   ```bash
   SPECS/active/{feature-name}/
   ├── specification/   # Requirements & discovery
   ├── pseudocode/      # Implementation blueprints
   ├── architecture/    # Technical designs
   ├── context/         # Cached research & patterns
   ├── artifacts/       # Generated outputs
   ├── validation/      # Test scenarios & gates
   └── .state/          # Progress tracking & rollback points
   ```

### Phase 2: Specification Discovery

4. **Interactive Requirements Gathering**
   Progressive interrogation with context awareness:
   
   **Problem Domain:**
   - What specific problem does this solve?
   - What's the current pain point or inefficiency?
   - What would success look like?
   - Are there existing workarounds?
   
   **Stakeholders & Users:**
   - Primary users and their technical level?
   - Secondary beneficiaries?
   - Who maintains this long-term?
   - Integration touchpoints with other teams?
   
   **Functional Requirements:**
   - Core functionality (must-have)?
   - Nice-to-have features?
   - Explicit non-goals?
   - User interaction flow?
   
   **Non-Functional Requirements:**
   - Performance targets (latency, throughput)?
   - Scale expectations (users, data volume)?
   - Security constraints?
   - Compliance requirements?
   - Observability needs?
   
   **Technical Constraints:**
   - Required tech stack components?
   - Forbidden dependencies?
   - API compatibility needs?
   - Platform limitations?
   
   **Scope Definition:**
   - MVP deliverables?
   - Phase 2 considerations?
   - Migration strategy if replacing existing?
   - Rollback plan requirements?

5. **Context Research & Caching**
   Parallel research operations:
   ```python
   research_tasks = [
       search_similar_features(),      # Find patterns in codebase
       identify_dependencies(),         # Map integration points
       analyze_conventions(),          # Extract coding standards
       find_test_patterns(),          # Discover testing approach
       check_security_patterns(),      # Security requirements
       locate_config_patterns()        # Configuration approach
   ]
   ```
   Cache all findings with metadata in `context/`

6. **Generate Specification Document**
   Create `specification/requirements.md`:
   - Problem statement with measurable impact
   - User stories with acceptance criteria
   - Functional requirements matrix
   - Non-functional requirements with SLAs
   - Constraints and assumptions
   - Risk assessment with mitigation
   - Success metrics and KPIs
   - Decision rationale log

### Phase 3: Initial Architecture

7. **Pseudocode Blueprint**
   Generate `pseudocode/initial.md`:
   - High-level algorithm design
   - Data flow diagrams
   - State machine definitions
   - Error handling strategy
   - Integration touchpoints

8. **Architecture Sketch**
   Create `architecture/initial.md`:
   - Component diagram
   - Sequence diagrams for key flows
   - Data model proposal
   - API contract drafts
   - Infrastructure requirements

### Phase 4: Validation Setup

9. **Define Validation Gates**
   Create `validation/gates.md`:
   ```yaml
   gates:
     syntax:
       - linting rules
       - type checking
     unit:
       - coverage target: 80%
       - critical path coverage: 100%
     integration:
       - API contract tests
       - Database migrations
     performance:
       - latency p99 < 100ms
       - throughput > 1000 rps
     security:
       - OWASP scan clean
       - No exposed secrets
   ```

10. **Initialize Progress Tracking**
    Create `.state/progress.json`:
    ```json
    {
      "feature": "{name}",
      "phase": "specification",
      "started": "{timestamp}",
      "checkpoints": [],
      "decisions": [],
      "blockers": [],
      "metrics": {
        "research_items": {count},
        "requirements": {count},
        "open_questions": {count}
      }
    }
    ```

## Output

```
✅ Specification initialized: SPECS/active/{feature-name}/

📊 Discovery Metrics:
   • Requirements captured: {X}
   • Open questions: {Y}
   • Similar patterns found: {Z}
   • Context items cached: {N}

📁 Structure Created:
   • specification/requirements.md - {status}
   • pseudocode/initial.md - {status}
   • architecture/initial.md - {status}
   • validation/gates.md - {status}
   • .state/progress.json - tracking enabled

🎯 Confidence Score: {score}/10

Next Commands:
   /spec-architect {feature-name}  - Detailed technical design
   /spec-status {feature-name}     - View progress & metrics
   
Or delegate to agents:
   @@spec-architect on SPECS/active/{feature-name}
```

## Quality Checklist
- [ ] All stakeholder groups identified
- [ ] Success metrics are measurable
- [ ] Validation gates are executable
- [ ] Context cache has relevant patterns
- [ ] No ambiguous requirements remain
- [ ] Rollback strategy defined

## Notes
- Uses SPARC methodology for structured development
- Emphasizes comprehensive upfront specification
- Maintains decision rationale for future reference
- Supports multi-agent orchestration patterns
- Enables checkpoint-based rollback if needed