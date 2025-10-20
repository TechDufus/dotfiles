---
description: "Implement feature from architecture with continuous validation: /spec-implement <feature-name>"
---

# Implement from Architecture

## Feature: $ARGUMENTS

Execute the technical architecture with test-driven development, continuous validation, and checkpoint-based progress tracking.

## Prerequisites
- Architecture complete in `SPECS/active/{feature-name}/`
- Pseudocode blueprints finalized
- Validation gates defined
- Task breakdown available
- Development environment ready

## Process

### Phase 1: Pre-Implementation Setup

1. **Load Complete Context**
   ```python
   # Load all specifications and architecture
   context = load_feature_context({feature-name})
   tasks = parse_task_breakdown()
   validation = load_validation_gates()
   progress = initialize_progress_tracker()
   ```

2. **Environment Validation**
   ```bash
   # Verify clean workspace
   git status --porcelain

   # Check dependencies
   make deps-check

   # Run baseline tests
   make test-baseline

   # Create implementation branch
   git checkout -b spec/{feature-name}
   ```

3. **ULTRATHINK: Implementation Strategy**
   Before coding, deeply consider:
   - Task execution order for minimal rework
   - Parallel vs sequential implementation
   - Integration points and dependencies
   - Potential blockers and mitigations
   - Checkpoint strategy for rollback

4. **Initialize Todo Tracking**
   Use TodoWrite tool to create implementation plan:
   - Break down tasks into atomic units
   - Set realistic time estimates
   - Identify critical path
   - Mark dependencies

### Phase 2: Test-Driven Implementation

5. **For Each Task - TDD Cycle**
   ```python
   for task in tasks:
       # 1. Create checkpoint
       checkpoint = create_checkpoint(task.id)

       # 2. Write failing tests first
       write_tests(task.acceptance_criteria)
       verify_tests_fail()

       # 3. Implement minimal code
       implement_from_pseudocode(task.pseudocode)

       # 4. Make tests pass
       while not all_tests_pass():
           refine_implementation()

       # 5. Refactor if needed
       if needs_refactoring():
           refactor_with_tests()

       # 6. Validate gates
       run_validation_gates(task.gates)

       # 7. Update progress
       update_progress(task, "completed")
   ```

6. **Implementation Patterns**
   Follow architecture specifications:
   ```python
   # Component implementation
   class Component:
       """Implements pseudocode from architecture/pseudocode/detailed.md"""

       def __init__(self):
           # Initialize per architecture/components.md
           pass

       def process(self, input):
           # Follow algorithm from pseudocode
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

7. **Automated Gate Execution**
   After each task completion:
   ```bash
   # Syntax & Style
   make lint || fix_lint_errors()

   # Type Safety
   make typecheck || fix_type_errors()

   # Unit Tests
   make test-unit || debug_test_failures()

   # Integration Tests
   make test-integration || fix_integration_issues()

   # Security Scan
   make security-scan || address_vulnerabilities()

   # Performance Check
   make perf-check || optimize_bottlenecks()
   ```

8. **Progress Tracking**
   Continuously update `.state/progress.json`:
   ```json
   {
     "current_phase": "implementation",
     "tasks_completed": [{task_ids}],
     "current_task": {task_id},
     "checkpoints": [
       {
         "id": "checkpoint-{timestamp}",
         "task": {task_id},
         "files_modified": [paths],
         "tests_added": [test_files],
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

9. **Component Integration**
   Following architecture/integrations.md:
   - Connect components per sequence diagrams
   - Implement API contracts
   - Set up message queues
   - Configure external services
   - Enable monitoring/logging

10. **End-to-End Validation**
    ```bash
    # Run full test suite
    make test-all

    # Execute E2E scenarios
    make test-e2e

    # Performance benchmarks
    make benchmark

    # Security audit
    make security-full
    ```

### Phase 5: Artifact Collection

11. **Organize Outputs**
    Save to `artifacts/`:
    ```
    artifacts/
    ├── code/           # Implementation files
    ├── tests/          # Test files
    ├── configs/        # Configuration changes
    ├── migrations/     # Database migrations
    ├── docs/           # Generated documentation
    └── metrics/        # Performance/coverage reports
    ```

12. **Documentation Generation**
    - API documentation from code
    - Update README with usage
    - Generate architecture diagrams
    - Create deployment guide

### Phase 6: Final Validation

13. **Quality Gate Verification**
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

14. **Rollback Decision Point**
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

    # Try alternative approach
    if has_alternative(task):
        implement_alternative(task)
    else:
        # Rollback to checkpoint
        rollback_to_checkpoint(task.checkpoint)

        # Seek clarification
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
   • Syntax/Lint: ✅ Passing
   • Type Check: ✅ No errors
   • Unit Tests: ✅ {X} passing
   • Integration: ✅ {Y} passing
   • Performance: ✅ Targets met
   • Security: ✅ No issues

📁 Artifacts Generated:
   • Code files: {count}
   • Test files: {count}
   • Configs: {count}
   • Documentation: {count}

🚀 Ready for Next Phase:
   /spec-refine {feature-name}    - Optimize implementation
   /spec-validate {feature-name}  - Run comprehensive validation
   /spec-complete {feature-name}  - Finalize and archive

💾 Checkpoint Available:
   Latest: checkpoint-{timestamp}
   Rollback: /spec-rollback {feature-name} {checkpoint-id}
```

## Quality Checklist
- [ ] All tasks from architecture completed
- [ ] Tests written before implementation (TDD)
- [ ] Validation gates passing continuously
- [ ] Code follows pseudocode blueprints
- [ ] Integration points connected
- [ ] Performance targets achieved
- [ ] Security controls implemented
- [ ] Documentation generated
- [ ] Artifacts organized
- [ ] Checkpoints enable rollback

## Notes
- ULTRATHINK before starting implementation
- Use TodoWrite tool for task tracking
- Create checkpoints before risky changes
- Run validation gates after each task
- Follow TDD: Red → Green → Refactor
- Reference pseudocode continuously
- Keep progress.json updated in real-time
- Never skip validation to "save time"
- Document all deviations from architecture