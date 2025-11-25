---
description: "Intelligent work orchestration: /work <task>"
---

# /work - Smart Task Router

Unified entry point for all development work. Analyzes your task, picks the right approach, validates continuously, and learns from outcomes.

## Usage

```
/work <task-description>
/work --quick <task>         # Skip analysis, direct execution
/work --structured <task>    # Force structured mode with TodoWrite
/work --parallel <task>      # Force parallel decomposition
/work --status               # Show active work from CLAUDE.md
```

## Task: $ARGUMENTS

---

## Phase 1: ANALYZE (< 30 seconds)

Before doing anything, classify this task:

### Check Learned Patterns

Scan `## Learned Patterns` section in CLAUDE.md for similar past tasks. Apply relevant insights.

### Complexity Classification

| Classification | Signals | Action |
|----------------|---------|--------|
| **GitHub** | Contains `#123`, "issue", "bug fix", "PR" | Delegate to `/gh-work` |
| **Quick** | Single file, < 3 steps, "typo", "rename", config change | Direct execution |
| **Research** | "what is", "where is", "find", "how does", exploration | Task(subagent_type: Explore) |
| **Parallel** | Multiple independent tasks, "and also", numbered list, comma-separated items | Multiple Task calls |
| **Structured** | Multi-file, tests needed, "feature", "implement", "add support" | Plan mode + TodoWrite |
| **Unclear** | Vague scope, ambiguous requirements, multiple interpretations | Clarify first |

### Output Analysis

```markdown
**Task**: <restate the task>
**Classification**: <quick|research|parallel|structured|unclear>
**Reasoning**: <why this classification>
**Files likely affected**: <list if known>
**Estimated complexity**: <trivial|simple|moderate|complex>
```

---

## Phase 2: CLARIFY (if needed)

**Gate**: Requirements must be unambiguous before proceeding.

If classification is "unclear" or requirements are ambiguous, use AskUserQuestion with:
- Scope boundaries (what's in/out)
- Approach preferences (if multiple valid options)
- Priority trade-offs (speed vs thoroughness, etc.)

Ask specific questions, not open-ended. Maximum 2-3 questions.

---

## Phase 3: ROUTE & EXECUTE

### GitHub Mode

If task references GitHub issues/PRs, delegate:
```
Invoke: /gh-work <issue-number>
```
Do not proceed with other modes.

### Quick Mode

For trivial tasks (single file, obvious fix, < 3 steps):

1. Execute directly without ceremony
2. Skip TodoWrite unless 3+ distinct steps
3. Skip validation if change is trivial (typo, config)
4. Complete in single response

### Research Mode

For exploration and information gathering:

1. Launch Task with Explore subagent:
```
Task(subagent_type: "Explore", prompt: "<specific research question>")
```
2. Synthesize findings
3. If findings reveal complexity, upgrade to Structured mode
4. Report findings clearly

### Parallel Mode

For multiple independent subtasks:

1. **Conflict Analysis**: Verify subtasks don't touch same files
2. **Gate**: If file conflicts detected, fall back to Structured mode
3. **Launch parallel Tasks** (all in single message):
```
Task(subagent_type: "general-purpose", prompt: "Subtask 1: ...")
Task(subagent_type: "general-purpose", prompt: "Subtask 2: ...")
Task(subagent_type: "general-purpose", prompt: "Subtask 3: ...")
```
4. **Synthesize**: Merge results, resolve any conflicts
5. **Validate**: Run validation across all changes

### Structured Mode

For complex, multi-file, or test-requiring work:

1. **Plan**: Use native plan mode or extended thinking to design approach
2. **TodoWrite**: Create task list with clear steps
3. **Execute**: Work through tasks, marking progress
4. **Gate**: Validate after each significant task before proceeding
5. **Complete**: Mark all todos done, run final validation

---

## Phase 4: VALIDATE

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
| **Generic** | Check for syntax errors, run available linters |

### Validation Rules

- **Always validate** if tests were modified or created
- **Always validate** if multiple files changed
- **Skip validation** only for trivial changes (typos, comments, config)
- **Report failures** clearly with fix suggestions
- **Never mark complete** with failing validation unless explicitly acknowledged

---

## Phase 5: LEARN

After task completion, evaluate if learning should be captured.

### Learning Triggers

Update CLAUDE.md when ANY of these apply:
- Task took > 5 minutes
- Non-obvious solution discovered
- User says "remember this"
- Pattern used successfully 2+ times
- Gotcha or pitfall encountered

### What to Capture

**In `## Learned Patterns` section:**
```markdown
### <date> - <category>
- Task: <what was done>
- Pattern: <reusable insight>
- Files: <relevant locations>
```

**In `## Decisions Log` section (for significant choices):**
```markdown
### <date> - <decision>
- Context: <situation>
- Chosen: <option selected>
- Rationale: <why>
```

### Active Work Tracking

**At start of structured work**, update CLAUDE.md:
```markdown
## Active Work
- **Current**: <task description>
- **Phase**: analyze | clarify | execute | validate | learn
- **Started**: <timestamp>
```

**On completion**, clear the Active Work section.

---

## Override Behavior

| Flag | Effect |
|------|--------|
| `--quick` | Skip analysis, execute directly, minimal validation |
| `--structured` | Force structured mode regardless of classification |
| `--parallel` | Force parallel decomposition, fail if conflicts |
| `--status` | Show Active Work section from CLAUDE.md, don't execute |

---

## Examples

```
/work fix typo in README
→ Quick mode: Direct fix, no TodoWrite

/work where is authentication handled
→ Research mode: Launch Explore subagent

/work update all test files to use new API and fix linting in docs
→ Parallel mode: Two independent tasks executed concurrently

/work implement OAuth2 authentication
→ Structured mode: Plan, TodoWrite, validate at each step

/work #42
→ GitHub mode: Delegate to /gh-work 42
```

---

## Philosophy

- **Intelligent routing** beats manual workflow selection
- **Continuous validation** catches issues early
- **Learning from outcomes** improves future work
- **Minimal ceremony** for simple tasks, full rigor for complex ones
- **Git is the safety net** - no custom checkpoint infrastructure
