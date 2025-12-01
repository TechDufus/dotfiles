---
name: workflow-router
description: "Intelligent task routing for development work. This skill should be used to analyze task complexity and select optimal execution strategy (quick, research, parallel, structured). Triggers automatically on complex tasks or via /work command."
---

# Workflow Router

This skill provides intelligent routing logic for development tasks, selecting the optimal execution strategy based on task analysis.

## Purpose

Eliminate decision paralysis about which workflow to use. Analyze the task and route to the right approach automatically.

## When to Use

This skill activates when:
- User invokes `/work <task>`
- Complex development task detected that would benefit from routing
- Task could be executed via multiple strategies

## Routing Decision Tree

### Step 1: Quick Classification (< 30 seconds)

Evaluate the task against these patterns:

| Signal | Classification |
|--------|---------------|
| Single file, obvious change, "typo", "rename" | **Quick** |
| "what is", "where is", "find", "how does" | **Research** |
| Multiple independent items, "and also", numbered list | **Parallel** |
| Multi-file, "feature", "implement", tests needed | **Structured** |
| Vague, ambiguous, multiple interpretations | **Unclear** |

### GitHub-Linked Detection

If task references GitHub issues/PRs (`#123`, "issue #N", "fix #N"), apply GitHub workflow as bookends:

**Before execution:**
1. Fetch issue: `gh issue view <number> --json title,body,labels,comments`
2. Create branch: `git checkout -b <type>/issue-<num>-<slug>`

**After execution:**
1. Commit: `<type>: <description> (closes #<num>)`
2. Push and create PR linking to issue

The actual implementation routes through normal classification below.

### Step 2: Execute by Classification

#### Quick → Direct Execution
- Execute immediately without ceremony
- Skip TodoWrite unless 3+ steps
- Skip validation for trivial changes

#### Research → Explore Subagent
```
Task(subagent_type: "Explore", prompt: "<research question>")
```
May upgrade to Structured if findings reveal complexity.

#### Parallel → Concurrent Tasks
1. Verify no file conflicts between subtasks
2. If conflicts exist, fall back to Structured
3. Launch all Tasks in single message:
```
Task(subagent_type: "general-purpose", prompt: "Subtask 1...")
Task(subagent_type: "general-purpose", prompt: "Subtask 2...")
```
4. Synthesize results

#### Structured → Full Workflow
1. Use native plan mode for design
2. Create TodoWrite task list
3. Execute with validation between tasks
4. Run final validation before completion

#### Unclear → Clarify First
Use AskUserQuestion with specific options:
- Scope boundaries
- Approach preferences
- Trade-off decisions

## Validation Integration

After execution, run appropriate validation:

| Project Type | Commands |
|--------------|----------|
| TypeScript/JS | `npm run typecheck && npm run lint && npm test` |
| Python | `ruff check . && pytest` |
| Go | `go vet ./... && go test ./...` |
| Ansible | `ansible-lint && yamllint .` |

Validation rules:
- Always validate if tests modified
- Always validate if multiple files changed
- Skip only for trivial changes (typos, comments)

## Learning Integration

After notable tasks (> 5 min, non-obvious solution, user request):

1. Check if pattern is reusable
2. Update `## Learned Patterns` in CLAUDE.md
3. Update `## Decisions Log` for significant choices

## Complexity Heuristics

Use these signals to gauge complexity:

**Simple (Quick mode):**
- Single file mentioned
- Task description < 10 words
- Common operation (typo, config, rename)

**Moderate (Research or Parallel):**
- 2-5 files mentioned
- Exploration or investigation needed
- Multiple independent subtasks

**Complex (Structured mode):**
- "Feature", "implement", "add support"
- Tests required or mentioned
- Architecture decisions needed
- Security or performance implications
