---
description: "Intelligent work orchestration: /work <task>"
---

# /work - Smart Task Router

Unified entry point for all development work. Routes to the workflow-router skill for intelligent task analysis and execution.

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

## Execution

### Handle --status Flag

If `--status` flag is present:
1. Read CLAUDE.md
2. Display the `## Active Work` section
3. Exit without further processing

### Route to Workflow Router

For all other invocations, invoke the workflow-router skill:

```
Skill(workflow-router)
```

The skill receives the task from `$ARGUMENTS` and handles:
- Task classification (Quick/Research/Parallel/Orchestrated/Structured)
- GitHub-linked detection and bookends
- Sub-agent delegation and synthesis
- Validation and learning

### Flag Passthrough

Pass any flags to the skill for override behavior:
- `--quick` → Skip analysis, execute directly
- `--structured` → Force structured mode
- `--parallel` → Force parallel decomposition
- `--orchestrate` → Force full orchestration

---

## Examples

```
/work fix typo in README
→ Routes to skill → Quick mode

/work where is authentication handled
→ Routes to skill → Research mode

/work update tests AND fix docs
→ Routes to skill → Parallel mode

/work implement OAuth2 with tests, docs, config, migration
→ Routes to skill → Orchestrated mode

/work #42
→ Routes to skill → GitHub-linked workflow

/work --status
→ Displays Active Work section from CLAUDE.md
```
