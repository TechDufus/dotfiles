---
description: "Implement from architecture with TDD: /spec-implement <feature-name>"
---

Execute technical architecture with test-driven development, continuous validation, and checkpoint-based tracking.

## Feature: $ARGUMENTS

## Prerequisites
- Architecture complete in `SPECS/active/{feature-name}/`
- Pseudocode blueprints finalized
- Validation gates defined
- Task breakdown available

## Process

### Phase 1: Pre-Implementation Setup

**1. Load Complete Context**
Load all specifications, architecture, tasks, and validation gates.

**2. Environment Validation**
```bash
# Verify clean workspace
git status --porcelain

# Check dependencies
make deps-check || npm install || pip install -r requirements.txt

# Run baseline tests
make test-baseline || npm test || pytest

# Create implementation branch
git checkout -b spec/{feature-name}
```

**3. ULTRATHINK: Implementation Strategy**

Before coding, consider:
- Task execution order
- Parallel vs sequential
- Integration points
- Potential blockers
- Checkpoint strategy

**4. Initialize Todo Tracking**

Use TodoWrite tool:
- Break tasks into atomic units
- Set time estimates
- Identify critical path
- Mark dependencies

### Phase 2: Test-Driven Implementation

**5. TDD Cycle for Each Task**

```
For each task:
  1. Create checkpoint
  2. Write failing tests first
  3. Implement minimal code
  4. Make tests pass
  5. Refactor if needed
  6. Validate gates
  7. Update progress
```

**6. Implementation Patterns**

Follow architecture specifications:
```python
# Example: Component implementation
class Component:
    """Implements pseudocode from architecture/pseudocode/detailed.md"""
    
    def process(self, input):
        # Step 1: Validate
        self._validate(input)
        
        # Step 2: Transform
        result = self._transform(input)
        
        # Step 3: Handle edge cases
        result = self._handle_edge_cases(result)
        
        # Step 4: Return
        return result
```

### Phase 3: Continuous Validation

**7. Automated Gate Execution**

After each task:
```bash
# Syntax & Style
make lint || npm run lint || ruff check

# Type Safety  
make typecheck || npm run typecheck || mypy .

# Unit Tests
make test-unit || npm test || pytest tests/unit

# Integration Tests
make test-integration || pytest tests/integration

# Security Scan
make security-scan || npm audit

# Performance Check
make perf-check || npm run benchmark
```

**8. Progress Tracking**

Update `.state/progress.json`:
```json
{
  "current_phase": "implementation",
  "tasks_completed": [],
  "current_task": "",
  "checkpoints": [
    {
      "id": "checkpoint-{timestamp}",
      "task": "",
      "files_modified": [],
      "tests_added": [],
      "validation_status": "passed"
    }
  ],
  "metrics": {
    "test_coverage": "85%",
    "performance": "meets_targets",
    "security_issues": 0
  }
}
```

### Phase 4: Integration & Assembly

**9. Component Integration**

Following architecture/integrations.md:
- Connect components per sequence diagrams
- Implement API contracts
- Set up message queues
- Configure external services
- Enable monitoring/logging

**10. End-to-End Validation**
```bash
# Full test suite
make test-all || npm test

# E2E scenarios
make test-e2e || npm run test:e2e

# Performance benchmarks
make benchmark

# Security audit
make security-full
```

### Phase 5: Artifact Collection

**11. Organize Outputs**

Save to `artifacts/`:
```
artifacts/
├── code/           # Implementation files
├── tests/          # Test files
├── configs/        # Configuration changes
├── migrations/     # Database migrations
├── docs/           # Generated docs
└── metrics/        # Performance reports
```

**12. Documentation Generation**
- API documentation from code
- Update README with usage
- Generate architecture diagrams
- Create deployment guide

### Phase 6: Final Validation

**13. Quality Gate Verification**
```yaml
final_gates:
  code_quality:
    - lint: passing
    - typecheck: no_errors
    - complexity: within_limits
  
  testing:
    - unit_coverage: ≥85%
    - integration: all_passing
    - e2e: scenarios_complete
  
  performance:
    - latency_p99: <100ms
    - throughput: >1000rps
    - memory: <500MB
  
  security:
    - vulnerabilities: none
    - secrets: none_exposed
    - permissions: least_privilege
```

**14. Rollback Decision Point**

If validation fails:
- Identify failed gates
- Attempt fixes
- If unresolvable: `/spec-rollback {checkpoint-id}`

## Error Recovery

```python
try:
    implement_task(task)
except ImplementationError as e:
    # Document blocker
    log_blocker(task, e)
    
    # Try alternative or rollback
    if has_alternative(task):
        implement_alternative(task)
    else:
        rollback_to_checkpoint(task.checkpoint)
        request_user_input(task, e)
```

## Output

```
✅ Implementation Complete!

📊 Implementation Metrics:
   • Tasks completed: {X}/{Y}
   • Time elapsed: {hours}
   • Tests written: {count}
   • Test coverage: {percent}%
   • Checkpoints created: {count}

✓ Validation Results:
   • Syntax/Lint: ✅
   • Type Check: ✅
   • Unit Tests: ✅ {X} passing
   • Integration: ✅ {Y} passing
   • Performance: ✅ Targets met
   • Security: ✅ No issues

📁 Artifacts Generated:
   • Code files: {count}
   • Test files: {count}
   • Configs: {count}
   • Documentation: {count}

🚀 Next Phase:
   /spec-refine {feature-name}
   /spec-validate {feature-name}
   /spec-complete {feature-name}

💾 Checkpoint Available:
   Latest: checkpoint-{timestamp}
   Rollback: /spec-rollback {feature-name} {checkpoint-id}
```

## Quality Checklist
- [ ] All tasks completed
- [ ] Tests written before code (TDD)
- [ ] Validation gates passing
- [ ] Code follows pseudocode
- [ ] Integration points connected
- [ ] Performance targets met
- [ ] Security controls implemented
- [ ] Documentation generated
- [ ] Artifacts organized
- [ ] Checkpoints enable rollback

## Notes
- ULTRATHINK before starting
- Use TodoWrite for tracking
- Create checkpoints before risky changes
- Run validation after each task
- TDD: Red → Green → Refactor
- Reference pseudocode continuously
- Keep progress.json updated
- Never skip validation
- Document deviations from architecture
