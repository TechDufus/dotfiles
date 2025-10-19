---
description: "Initialize specification with SPARC: /spec-init <feature-name> [description]"
---

Create comprehensive specification using SPARC methodology (Specification, Pseudocode, Architecture, Refinement, Completion).

## Feature: $ARGUMENTS

## Process

### Phase 1: Parse & Validate

**1. Parse Arguments**
- Extract feature name (kebab-case enforced)
- Extract initial description if provided
- Validate naming conventions
- Check for existing features

**2. Initialize SPECS Infrastructure**
Ensure structure exists:
```
SPECS/
├── active/          # Features in development
├── completed/       # Archived features
├── templates/       # Reusable patterns
├── agents/          # Specialized agent configs
└── .sparc/          # Framework metadata
```

**3. Create Feature Workspace**
```
SPECS/active/{feature-name}/
├── specification/   # Requirements & discovery
├── pseudocode/      # Implementation blueprints
├── architecture/    # Technical designs
├── context/         # Cached research & patterns
├── artifacts/       # Generated outputs
├── validation/      # Test scenarios & gates
└── .state/          # Progress tracking & rollback
```

### Phase 2: Specification Discovery

**4. Interactive Requirements Gathering**

Progressive interrogation:

*Problem Domain:*
- What problem does this solve?
- Current pain point or inefficiency?
- What would success look like?
- Existing workarounds?

*Stakeholders & Users:*
- Primary users and technical level?
- Secondary beneficiaries?
- Who maintains long-term?
- Integration touchpoints?

*Functional Requirements:*
- Core functionality (must-have)?
- Nice-to-have features?
- Explicit non-goals?
- User interaction flow?

*Non-Functional Requirements:*
- Performance targets?
- Scale expectations?
- Security constraints?
- Compliance requirements?
- Observability needs?

*Technical Constraints:*
- Required tech stack?
- Forbidden dependencies?
- API compatibility?
- Platform limitations?

*Scope Definition:*
- MVP deliverables?
- Phase 2 considerations?
- Migration strategy?
- Rollback plan?

**5. Context Research & Caching**

Parallel research:
- Search similar features
- Identify dependencies
- Analyze conventions
- Find test patterns
- Check security patterns
- Locate config patterns

Cache findings in `context/` directory.

**6. Generate Specification Document**

Create `specification/requirements.md`:
- Problem statement with impact
- User stories with acceptance criteria
- Functional requirements matrix
- Non-functional requirements with SLAs
- Constraints and assumptions
- Risk assessment with mitigation
- Success metrics and KPIs
- Decision rationale log

### Phase 3: Initial Architecture

**7. Pseudocode Blueprint**

Generate `pseudocode/initial.md`:
- High-level algorithm design
- Data flow diagrams
- State machine definitions
- Error handling strategy
- Integration touchpoints

**8. Architecture Sketch**

Create `architecture/initial.md`:
- Component diagram
- Sequence diagrams
- Data model proposal
- API contract drafts
- Infrastructure requirements

### Phase 4: Validation Setup

**9. Define Validation Gates**

Create `validation/gates.md`:
```yaml
gates:
  syntax:
    - linting rules
    - type checking
  unit:
    - coverage target: 80%
    - critical path: 100%
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

**10. Initialize Progress Tracking**

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
    "research_items": 0,
    "requirements": 0,
    "open_questions": 0
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
   • specification/requirements.md
   • pseudocode/initial.md
   • architecture/initial.md
   • validation/gates.md
   • .state/progress.json

🎯 Confidence Score: {score}/10

Next Commands:
   /spec-architect {feature-name}
   /spec-status {feature-name}
```

## Quality Checklist
- [ ] All stakeholder groups identified
- [ ] Success metrics measurable
- [ ] Validation gates executable
- [ ] Context cache has patterns
- [ ] No ambiguous requirements
- [ ] Rollback strategy defined

## Notes
- SPARC methodology for structured development
- Comprehensive upfront specification
- Maintains decision rationale
- Supports multi-agent orchestration
- Enables checkpoint-based rollback
