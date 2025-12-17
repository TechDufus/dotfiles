---
description: "Intelligent work orchestration: /work <task>"
---

# /work - Smart Task Router

Unified entry point for all development work. Analyzes task complexity and selects optimal execution strategy.

## Usage

```
/work <task-description>
/work --quick <task>         # Skip analysis, direct execution
/work --structured <task>    # Force structured mode with TodoWrite
/work --parallel <task>      # Force parallel decomposition
/work --orchestrate <task>   # Force full orchestration with sub-agents
/work --status               # Show active work from CLAUDE.md
```

## Task: $ARGUMENTS

---

## Core Principle

**Your value is not doing work—it's ensuring work gets done correctly.**

Before executing anything, ask: "Can this be broken into independent pieces that benefit from parallel execution?" If yes, decompose and delegate. Your sub-agents are as capable as you.

---

## Phase 1: Handle Special Cases

### --status Flag

If `--status` flag is present:
1. Read CLAUDE.md
2. Display the `## Active Work` section
3. Exit without further processing

### Override Flags

When flags are provided, they override normal classification:

| Flag | Effect |
|------|--------|
| `--quick` | Skip analysis, execute directly, minimal validation |
| `--structured` | Force structured mode regardless of classification |
| `--parallel` | Force parallel decomposition, fail if conflicts |
| `--orchestrate` | Force full orchestration with sub-agent delegation |

---

## Phase 2: ANALYZE (< 30 seconds)

Before doing anything, classify this task:

### Check Learned Patterns

Scan `## Learned Patterns` section in CLAUDE.md for similar past tasks. Apply relevant insights.

### Complexity Classification

| Classification | Signals | Action |
|----------------|---------|--------|
| **Quick** | Single file, < 3 steps, "typo", "rename", config change | Direct execution |
| **Research** | "what is", "where is", "find", "how does", exploration | @explore [query] |
| **Parallel** | 2-3 independent tasks, no file conflicts | Multiple @general calls |
| **Orchestrated** | 4+ work streams, complex dependencies, system-wide | Full decomposition + @general waves |
| **Structured** | Multi-file, tests needed, sequential dependencies | Plan mode + TodoWrite |
| **Unclear** | Vague scope, ambiguous requirements | Clarify first |

### GitHub-Linked Detection

If task references GitHub issues/PRs (`#123`, "issue #N", "fix #N"):
- This is a **modifier**, not a separate mode
- Apply GitHub workflow as bookends around normal routing
- The actual implementation routes through classification above

### Decomposition Check

For any task not classified as Quick:

```
1. Can this be split into independent work units?
2. Would parallel execution provide meaningful benefit?
3. Do any units have dependencies on others?
4. What's the critical path?
```

If 3+ independent units exist → upgrade to Parallel or Orchestrated mode.

### Output Analysis

```markdown
**Task**: <restate the task>
**Classification**: <quick|research|parallel|orchestrated|structured|unclear>
**GitHub-Linked**: <yes|no> (if yes, will wrap execution with branch/commit/PR workflow)
**Reasoning**: <why this classification>
**Work Units**: <if decomposed, list them>
**Dependencies**: <sequential requirements if any>
**Estimated complexity**: <trivial|simple|moderate|complex|system-wide>
```

---

## Phase 3: CLARIFY (if needed)

**Gate**: Requirements must be unambiguous before proceeding.

If classification is "unclear" or requirements are ambiguous, ask:
- Scope boundaries (what's in/out)
- Approach preferences (if multiple valid options)
- Priority trade-offs (speed vs thoroughness)

Ask specific questions, not open-ended. Maximum 2-3 questions.

---

## Phase 4: ROUTE & EXECUTE

### GitHub-Linked Work (Bookends)

When task references GitHub issues/PRs (contains `#123`, "issue #N", "fix #N"):

**Before execution:**
1. Fetch issue context: `gh issue view <number> --json title,body,labels,comments`
2. Create branch if needed: `git checkout -b <type>/issue-<num>-<slug>`
   - Infer type from issue labels: `bug` → fix/, `enhancement` → feat/, `documentation` → docs/
   - Generate slug from issue title (lowercase, hyphenated, truncated)
3. Extract requirements from issue body into task understanding

**During execution:**
- Route to appropriate mode based on task complexity (Quick/Structured/Parallel/Orchestrated)
- All normal execution rules apply

**After completion:**
1. Commit with issue reference: `<type>: <description> (closes #<num>)`
2. Push branch: `git push -u origin <branch>`
3. Create PR linking issue:
   ```bash
   gh pr create --title "<type>: <description>" --body "$(cat <<'EOF'
   Closes #<num>

   ## Summary
   <what was done>

   ## Test Plan
   <how it was verified>
   EOF
   )"
   ```

---

### Quick Mode

For trivial tasks (single file, obvious fix, < 3 steps):

1. Execute directly without ceremony
2. Skip TodoWrite unless 3+ distinct steps
3. Skip validation if change is trivial (typo, config)
4. Complete in single response

### Research Mode

For exploration and information gathering, use the explore subagent:

@explore [Your specific search query here. Be specific about what files, patterns, or code you're looking for. Return file paths, relevant code sections, and brief analysis.]

After @explore returns:
1. Synthesize findings
2. If findings reveal complexity, upgrade to appropriate mode
3. Report findings clearly

### Parallel Mode

For 2-3 independent subtasks, use multiple @general subagents:

1. **Conflict Analysis**: Verify subtasks don't touch same files
2. **Gate**: If file conflicts detected, fall back to Structured mode
3. **Launch parallel subagents** using @mentions:

@general **Task 1**: [Specific objective]. Context: [relevant files, constraints]. Success criteria: [verifiable outcomes]. Return: summary of changes, files modified, verification results.

@general **Task 2**: [Specific objective]. Context: [relevant files, constraints]. Success criteria: [verifiable outcomes]. Return: summary of changes, files modified, verification results.

@general **Task 3**: [Specific objective]. Context: [relevant files, constraints]. Success criteria: [verifiable outcomes]. Return: summary of changes, files modified, verification results.

4. **Validate Each Result** before synthesis
5. **Synthesize**: Merge results using Synthesis Protocol
6. **Final Validation**: Run validation across all changes

### Orchestrated Mode

For complex work requiring 4+ parallel streams or sophisticated coordination:

1. **Decompose Completely**
   - List all work units
   - Map dependencies between units
   - Identify critical path
   - Group parallelizable units

2. **Design Verification First**
   - Define success criteria for EACH work unit
   - Define integration criteria (how units combine)
   - Define final acceptance criteria

3. **Delegate with Precision via @general**
   - Each sub-agent gets ONE focused task
   - Use Sub-Agent Prompt Template (below)
   - Include only necessary context per agent

4. **Execute in Waves**
   - Wave 1: Independent tasks (parallel @general calls)
   - Wave 2: Tasks depending on Wave 1 (after validation)
   - Continue until complete

5. **Validate and Iterate**
   - Check each result against its criteria
   - If validation fails, use Failure Recovery Protocol
   - Do not synthesize until all validations pass

6. **Synthesize**
   - Use Synthesis Protocol to combine results
   - Verify integration criteria
   - Run final acceptance validation

### Structured Mode

For complex work with sequential dependencies:

1. **Plan**: Use native plan mode or extended thinking to design approach
2. **TodoWrite**: Create task list with clear steps
3. **Execute**: Work through tasks, marking progress
4. **Gate**: Validate after each significant task before proceeding
5. **Complete**: Mark all todos done, run final validation

---

## Sub-Agent Prompt Template

When delegating via @general or @explore, structure your prompts clearly:

```
@general **Task**: [Single, specific objective - one sentence]

**Context**:
- Relevant file locations: [paths]
- Key constraints: [from parent task]
- NO extraneous background

**Approach** (optional): [Suggested method if preferred]

**Constraints**:
- [What to avoid]
- [Boundaries not to cross]
- [Style/pattern requirements]

**Success Criteria**:
- [ ] [Verifiable outcome 1]
- [ ] [Verifiable outcome 2]

**Return**: Summary of changes made, files modified, any issues encountered, verification results.
```

### Prompt Quality Checklist

Before launching a sub-agent, verify:
- [ ] Objective is single and focused (not compound)
- [ ] Context is minimal but sufficient
- [ ] Success criteria are verifiable (not vague)
- [ ] Output format is specified
- [ ] No overlap with other sub-agent scopes

---

## Failure Recovery Protocol

When a sub-agent fails or returns invalid results:

### Diagnose

1. Was the task poorly defined? → Re-decompose with different boundaries
2. Was context missing? → Enrich prompt and retry
3. Was the task too complex? → Further decompose into smaller units
4. Was it a transient failure? → Retry same prompt (max 2 retries)
5. Is this a capability limitation? → Adjust approach or escalate

### Recovery Actions

| Failure Type | Action |
|--------------|--------|
| Unclear output | Re-prompt with explicit output format |
| Partial completion | Launch continuation task for remainder |
| Wrong approach | Re-prompt with approach constraint |
| File conflicts | Serialize the conflicting tasks |
| Validation failure | Launch fix task with failure details |
| Repeated failure | Escalate to user with diagnosis |

### Iteration Limit

- Max 3 attempts per sub-agent task
- After 3 failures, report issue and request guidance
- Never silently retry indefinitely

---

## Synthesis Protocol

When combining results from parallel work:

### Pre-Synthesis Checks

1. All sub-agents returned valid results
2. Each result passed its verification criteria
3. No file conflicts between results
4. Results are compatible (no contradicting changes)

### Synthesis Steps

1. **Inventory**: List all changes from all sub-agents
2. **Conflict Detection**: Check for overlapping modifications
3. **Integration Order**: Determine safe application order
4. **Apply**: Integrate changes (or identify manual resolution needed)
5. **Verify Integration**: Run combined validation
6. **Report**: Summarize what was combined and final state

### Conflict Resolution

If sub-agent results conflict:
- **Same file, different sections**: Merge carefully
- **Same file, same section**: Serialize execution (re-run second task after first)
- **Incompatible approaches**: Escalate to user for decision

---

## Phase 5: VALIDATE

**Gate**: Validation must pass (or be explicitly skipped with reason) before completion.

### Automatic Validation

Detect project type and run appropriate checks:

| Project Type | Validation Commands |
|--------------|---------------------|
| **TypeScript/JS** | `npm run typecheck && npm run lint && npm test` |
| **Python** | `ruff check . && pytest` |
| **Go** | `go vet ./... && go test ./...` |
| **Rust** | `cargo check && cargo test` |
| **Ansible** | `ansible-lint && yamllint .` |
| **Kubernetes** | `kubectl --dry-run=client -f <file>` |
| **Terraform** | `terraform validate && terraform plan` |
| **Generic** | Check for syntax errors, run available linters |

### Validation Rules

- **Always validate** if tests were modified or created
- **Always validate** if multiple files changed
- **Always validate** after Parallel or Orchestrated mode
- **Skip validation** only for trivial changes (typos, comments)
- **Report failures** clearly with fix suggestions
- **Never mark complete** with failing validation

---

## Phase 6: LEARN

After task completion, evaluate if learning should be captured.

### Learning Triggers

Update CLAUDE.md when ANY of these apply:
- Task took > 5 minutes
- Non-obvious solution discovered
- Orchestration pattern worked well (or didn't)
- User says "remember this"
- Gotcha or pitfall encountered
- Sub-agent prompt needed refinement

### What to Capture

**In `## Learned Patterns` section:**
```markdown
### <date> - <category>
- Task: <what was done>
- Mode: <which execution mode>
- Pattern: <reusable insight>
- Sub-agent notes: <if delegation was used, what worked>
```

**In `## Decisions Log` section (for significant choices):**
```markdown
### <date> - <decision>
- Context: <situation>
- Chosen: <option selected>
- Rationale: <why>
```

### Active Work Tracking

**At start of Structured/Orchestrated work**, update CLAUDE.md:
```markdown
## Active Work
- **Current**: <task description>
- **Mode**: <execution mode>
- **Phase**: analyze | clarify | execute | validate | learn
- **Sub-agents**: <count if applicable>
- **Started**: <timestamp>
```

**On completion**, clear the Active Work section.

---

## Mode Selection Heuristics

When classification is ambiguous:

```
Single file, < 5 minutes          → Quick
Exploration, no changes           → Research
2-3 independent changes           → Parallel
4+ independent streams            → Orchestrated
Sequential dependencies           → Structured
Mixed dependencies               → Orchestrated (let decomposition sort it)
```

**Upgrade triggers** (during execution):
- Quick mode taking > 5 minutes → Consider Structured
- Structured revealing parallelism → Switch to Orchestrated
- Parallel hitting conflicts → Fall back to Structured

**Downgrade triggers:**
- Orchestrated with only 2 actual units → Simplify to Parallel
- Parallel where tasks are trivial → Just do them sequentially

---

## Anti-Patterns

Avoid these failure modes:

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Monolithic delegation | One sub-agent gets entire task | Decompose further |
| Vague verification | "Make sure it works" | Define specific criteria |
| Context overload | Sub-agent gets full project context | Minimize to necessary only |
| Premature synthesis | Combining before validation | Validate each result first |
| Silent retry loops | Retrying failures indefinitely | Limit to 3, then escalate |
| Over-orchestration | 2-step task split into 5 sub-agents | Match complexity to task |

---

## Philosophy

- **Intelligent routing** beats manual workflow selection
- **Decomposition thinking** scales your impact
- **Quality sub-agent prompts** determine orchestration success
- **Continuous validation** catches issues early
- **Learning from outcomes** improves future work
- **Minimal ceremony** for simple tasks, full rigor for complex ones
- **Fail fast, iterate** rather than patch around problems
- **Git is the safety net** - no custom checkpoint infrastructure
