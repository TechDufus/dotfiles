# Work Mode Reference

## Mode Selection

| Mode | Use When | Default Behavior |
|------|----------|------------------|
| `quick` | Single-file or obvious fix, low risk, under a few steps | Execute locally |
| `research` | The user mainly needs discovery, explanation, or codebase location | Use `explorer` or local inspection |
| `structured` | Sequential dependencies, multi-file changes, testing likely required | `update_plan` plus stepwise execution |
| `parallel` | Two or three independent work units with disjoint write scopes | Run bounded agents in parallel |
| `orchestrated` | Four or more work streams or wave-based coordination | Multi-wave decomposition with critical path control |
| `unclear` | Scope, constraints, or success criteria are ambiguous | Clarify before execution |

## Classification Signals

- `quick`: typo, rename, tiny config change, one obvious edit
- `research`: "what is", "where is", "find", "how does", architecture discovery
- `structured`: migrations, refactors, test updates, sequential dependencies
- `parallel`: separable implementation slices, non-overlapping files, independent verification
- `orchestrated`: system-wide changes, staged dependency graph, multiple slices that can run in waves

## Upgrade Triggers

- A quick task expands beyond a few clear steps
- Discovery reveals multiple independent work units
- Validation becomes non-trivial or spans several subsystems
- Conflicts or blockers require more deliberate planning

## Downgrade Triggers

- An orchestrated task collapses into one or two real edits
- Parallel work reveals overlapping write scopes
- The task turns out to be simple enough to finish locally faster

## Delegation Template

Use this shape when spawning agents:

```text
Task: one focused objective
Context: only the files and constraints needed
Success criteria: specific, checkable outcomes
Output: summary, files touched, verification
```

## Anti-Patterns

- Splitting trivial work into many agents
- Delegating the immediate blocking step
- Sending full-project context when only two files matter
- Letting multiple agents edit the same files
- Retrying failed delegation without changing the prompt or scope
