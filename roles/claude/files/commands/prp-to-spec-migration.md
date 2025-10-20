---
description: "Migration guide for transitioning from PRP to SPEC methodology"
---

# PRP to SPEC Migration Guide

## Overview

This guide helps transition from the PRP (Problem-Research-Plan) methodology to the enhanced SPEC (Specification-driven) approach using SPARC principles.

## Why Migrate to SPEC?

### Key Advantages
- **Industry Alignment**: SPARC/SPEC widely recognized in 2024-2025
- **Better State Management**: Built-in progress tracking and checkpoints
- **Iterative Refinement**: Not limited to single-pass implementation
- **Granular Control**: Five distinct phases vs three
- **Risk Mitigation**: Rollback capabilities and validation gates
- **Multi-Agent Support**: Designed for orchestration patterns

### Comparison Matrix

| Aspect | PRP | SPEC |
|--------|-----|------|
| **Phases** | 3 (Init, Build, Execute) | 5 (S.P.A.R.C) |
| **Progress Tracking** | Manual | Automated with .state/ |
| **Validation** | End-of-process | Continuous gates |
| **Rollback** | Not built-in | Checkpoint-based |
| **Refinement** | Limited | Dedicated phase |
| **Artifacts** | Single output | Organized structure |
| **Metrics** | Basic | Comprehensive analytics |

## Migration Strategy

### Phase 1: Command Mapping

#### Direct Command Equivalents
```bash
# PRP Commands → SPEC Commands
/prp-init       → /spec-init        # Enhanced requirements gathering
/prp-build      → /spec-architect    # Technical design with pseudocode
/prp-execute    → /spec-implement    # Implementation with validation

# New SPEC Commands (no PRP equivalent)
                → /spec-validate     # Run quality gates
                → /spec-refine       # Iterative improvement
                → /spec-rollback     # Checkpoint recovery
                → /spec-complete     # Finalization & archive
                → /spec-status       # Progress tracking
```

#### Workflow Comparison
```
PRP Workflow:
init → build → execute → done

SPEC Workflow:
init → architect → implement → validate → refine → complete
  ↑                                ↓
  └────── rollback (if needed) ────┘
```

### Phase 2: File Structure Migration

#### From PRP Structure
```
PRPs/
├── features/
│   └── {feature}.feature.md
└── {feature}.md
```

#### To SPEC Structure
```
SPECS/
├── active/              # In-progress features
│   └── {feature}/
│       ├── specification/
│       ├── pseudocode/
│       ├── architecture/
│       ├── context/
│       ├── artifacts/
│       ├── validation/
│       └── .state/
├── completed/           # Archived features
├── templates/           # Reusable patterns
└── .sparc/             # Framework metadata
```

### Phase 3: Content Migration

#### Migrating Existing PRP Files

1. **Feature Files** (`*.feature.md`)
   ```python
   # Convert PRP feature file to SPEC specification
   def migrate_feature_file(prp_feature):
       spec = {
           "specification/requirements.md": extract_requirements(prp_feature),
           "specification/scope.md": extract_scope(prp_feature),
           "specification/users.md": extract_users(prp_feature),
           "validation/acceptance.md": extract_success_criteria(prp_feature)
       }
       return spec
   ```

2. **PRP Build Files**
   ```python
   # Convert PRP to SPEC architecture
   def migrate_prp_file(prp_content):
       spec = {
           "pseudocode/algorithm.md": extract_implementation_blueprint(prp_content),
           "architecture/design.md": extract_technical_spec(prp_content),
           "context/research.md": extract_research_findings(prp_content),
           "validation/gates.md": extract_validation_commands(prp_content)
       }
       return spec
   ```

### Phase 4: Enhanced Keywords

#### Terminology Updates
```yaml
# PRP Terms → SPEC Terms
old_terms:
  - "interrogation" → "requirements gathering"
  - "generate" → "architect"
  - "PRP file" → "specification"
  - "validation commands" → "validation gates"
  - "one-pass implementation" → "iterative development"

new_concepts:
  - "checkpoints": Rollback points during implementation
  - "gates": Automated quality checks
  - "artifacts": Organized output collection
  - "refinement": Optimization phase
  - "progress tracking": State management
```

#### Information-Dense Keywords
```yaml
enhanced_keywords:
  process:
    - "orchestration": Multi-agent coordination
    - "guardrails": Safety constraints
    - "decision rationale": Documented reasoning
    - "phase execution": Structured progression
    - "continuous validation": Ongoing quality checks

  artifacts:
    - "specification/": Requirements & constraints
    - "pseudocode/": Implementation blueprints
    - "architecture/": Technical designs
    - "context/": Cached research
    - "validation/": Quality gates
    - ".state/": Progress tracking

  metrics:
    - "velocity tracking": Speed measurement
    - "efficiency score": Resource utilization
    - "quality score": Code quality metrics
    - "risk level": Project health indicator
    - "confidence score": Success probability
```

## Migration Steps

### For New Projects

1. **Start with SPEC directly**
   ```bash
   /spec-init my-feature "Description of the feature"
   ```

2. **Follow SPARC phases**
   - Specification: Detailed requirements
   - Pseudocode: Algorithm design
   - Architecture: Technical blueprint
   - Refinement: Optimization
   - Completion: Finalization

### For Existing PRP Projects

#### Option 1: Complete with PRP, New with SPEC
```bash
# Finish current PRP
/prp-execute existing-prp.md

# Start new features with SPEC
/spec-init new-feature
```

#### Option 2: Migrate Mid-Flight
```python
# 1. Create SPEC structure
mkdir -p SPECS/active/{feature-name}

# 2. Convert existing PRP files
/migrate-prp-to-spec {prp-file}

# 3. Continue with SPEC workflow
/spec-implement {feature-name}
```

#### Option 3: Hybrid Approach
```bash
# Use PRP commands as aliases to SPEC
alias /prp-init="/spec-init"
alias /prp-build="/spec-architect"
alias /prp-execute="/spec-implement"

# Gradually adopt new commands
/spec-validate {feature}
/spec-refine {feature}
```

## Migration Script

```bash
#!/bin/bash
# migrate-prp-to-spec.sh

migrate_prp_to_spec() {
    local prp_file="$1"
    local feature_name=$(basename "$prp_file" .md)

    echo "🔄 Migrating $prp_file to SPEC format..."

    # Create SPEC structure
    mkdir -p "SPECS/active/$feature_name"/{specification,pseudocode,architecture,context,artifacts,validation,.state}

    # Parse PRP content
    if [[ -f "$prp_file" ]]; then
        # Extract sections
        awk '/## Requirements/,/## /' "$prp_file" > "SPECS/active/$feature_name/specification/requirements.md"
        awk '/## Implementation/,/## /' "$prp_file" > "SPECS/active/$feature_name/pseudocode/initial.md"
        awk '/## Validation/,/## /' "$prp_file" > "SPECS/active/$feature_name/validation/gates.md"

        # Copy research context
        grep -E "http|https" "$prp_file" > "SPECS/active/$feature_name/context/references.md"
    fi

    # Initialize progress tracking
    cat > "SPECS/active/$feature_name/.state/progress.json" << EOF
{
    "feature": "$feature_name",
    "migrated_from": "prp",
    "phase": "architecture",
    "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "checkpoints": [],
    "status": "migrated"
}
EOF

    echo "✅ Migration complete: SPECS/active/$feature_name/"
    echo "Next: /spec-architect $feature_name"
}

# Run migration
migrate_prp_to_spec "$1"
```

## Best Practices

### 1. Gradual Adoption
- Start with new features using SPEC
- Complete existing PRP work before migrating
- Use hybrid approach for transition period

### 2. Team Training
- Review SPARC methodology documentation
- Practice with simple features first
- Share lessons learned

### 3. Preserve History
- Archive PRP files before migration
- Document migration decisions
- Keep rollback path available

### 4. Leverage New Features
- Use checkpoint system for safety
- Implement continuous validation
- Take advantage of refinement phase
- Utilize progress tracking

## Common Questions

### Q: Can I use both PRP and SPEC simultaneously?
**A:** Yes, but recommend using SPEC for new work and completing existing PRP projects first.

### Q: Will my existing PRPs still work?
**A:** Yes, PRP commands remain functional. Consider them legacy with SPEC as the recommended approach.

### Q: How long does migration take?
**A:**
- New projects: Immediate (just use SPEC)
- Existing PRPs: 10-15 minutes per feature to migrate
- Team adoption: 1-2 weeks for comfort with new workflow

### Q: What about my existing templates?
**A:** PRP templates can be adapted to SPEC structure. The migration script helps convert content.

### Q: Is SPEC more complex than PRP?
**A:** SPEC has more structure but provides better guardrails, making complex projects easier to manage.

## Support Resources

- SPARC Methodology: [Research findings in context]
- SPEC Command Reference: `/help spec-*`
- Migration Support: Create issue in repository
- Community: 100K+ using SPARC globally

## Summary

The migration from PRP to SPEC represents an evolution toward:
- **Better structure** with SPARC phases
- **Enhanced safety** with checkpoints
- **Improved quality** with validation gates
- **Greater visibility** with progress tracking
- **Industry alignment** with modern practices

Start small, migrate gradually, and leverage the enhanced capabilities for better software delivery.