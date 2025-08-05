---
description: "Build implementation from design spec: /spec-build <feature-name>"
---

# Build from Specification

## Feature: $ARGUMENTS

Execute the technical design and implement the feature with continuous validation.

## Prerequisites
- Feature has complete design in `SPECS/active/{feature-name}/`
- Technical design is approved
- Task breakdown is complete
- Validation criteria defined
- If SPECS structure doesn't exist, run `/spec-init` first

## Process

1. **Load Full Context**
   ```python
   # Load all specifications
   requirements = load("requirements.md")
   design = load("design.md") 
   tasks = load("tasks.md")
   validation = load("validation.md")
   progress = load(".progress.json")
   context = load_dir("context/")
   ```

2. **Pre-Implementation Setup**
   - Verify clean working directory
   - Check dependencies installed
   - Run existing tests (baseline)
   - Update progress tracking

3. **Phased Implementation**
   For each phase in tasks.md:
   
   **Phase Execution:**
   - Mark phase as "in_progress"
   - Execute tasks in dependency order
   - Run validation after each task
   - Save artifacts to `artifacts/`
   - Update progress.json

   **Task Execution Pattern:**
   ```python
   for task in phase.tasks:
       # 1. Mark task in_progress
       update_progress(task, "in_progress")
       
       # 2. Implement based on design
       implement_task(task, context)
       
       # 3. Validate immediately
       result = run_validation(task.validation)
       
       # 4. Fix if needed
       while not result.passed:
           fix_issues(result.errors)
           result = run_validation(task.validation)
       
       # 5. Mark complete
       update_progress(task, "completed")
   ```

4. **Continuous Validation**
   After each task:
   - Syntax/lint checks
   - Type checking  
   - Unit tests for new code
   - Integration smoke tests
   - Update coverage metrics

5. **Progress Tracking**
   Continuously update:
   - Task completion status
   - Actual time vs estimates
   - Blockers encountered
   - Patterns learned
   - Decisions made

6. **Artifact Collection**
   Save to `artifacts/`:
   - Generated code files
   - Test files
   - Configuration changes
   - Migration scripts
   - Documentation updates

7. **Final Validation**
   Run complete validation suite:
   - All quality gates
   - Full test suite
   - Performance tests
   - Security scans
   - Documentation checks

8. **Completion Report**
   Generate summary:
   - Tasks completed
   - Tests passed
   - Coverage achieved
   - Performance metrics
   - Next steps

## Error Handling
- If validation fails: Read errors, fix, retry
- If blocked: Document in progress.json, seek clarification
- If design gap found: Update design.md, continue

## Output
```
✅ Implementation complete!

📊 Metrics:
- Tasks: {X}/{Y} completed
- Tests: {Z} passing
- Coverage: {N}%
- Time: {H} hours

📁 Artifacts saved to: SPECS/active/{feature-name}/artifacts/
📝 Full report in: .progress.json

Next steps:
1. Review implementation
2. Run: /spec-deploy {feature-name}
3. Move to completed: /spec-complete {feature-name}
```

## Notes
- Never skip validation to "save time"
- Document all deviations from design
- Keep progress.json updated in real-time
- Use artifacts/ for code organization before final placement