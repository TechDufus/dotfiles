---
name: work
description: Coordinate non-trivial engineering work with the right level of analysis, planning, delegation, implementation, and validation. Use for multi-step requests, multi-file changes, or work that benefits from explicit execution strategy.
metadata:
  short-description: Coordinate non-trivial work
---

# Work

Use this skill for non-trivial engineering tasks. Choose the lightest execution mode that
preserves quality. Keep this skill focused on routing and execution strategy; rely on broader
agent instructions for general operating policy.

## Use It To

- classify work as quick, research, structured, parallel, or orchestrated
- decide when planning or delegation is warranted
- enforce validation and clear closeout reporting

## Modifiers

- `--status`: summarize current work from `AGENTS.md` and relevant git state; do not edit files
- `--quick`: skip deep analysis and execute directly
- `--structured`: force plan-first sequential execution
- `--parallel`: force independent subtasks only; fall back if write scopes overlap
- `--orchestrate`: allow multi-wave decomposition for large tasks

## Workflow

1. Parse the task and any modifiers.
2. If `--status` is present, read `AGENTS.md`, summarize active work if present, add a short git
   snapshot if useful, and stop.
3. If no override was provided, classify the task using
   [references/mode-reference.md](references/mode-reference.md).
4. For substantial work, report the chosen mode and core reasoning briefly before execution.
5. Execute by mode:
   - **Quick**: handle locally with minimal ceremony.
   - **Research**: prefer local inspection or a read-heavy subagent when it materially speeds up
     discovery.
   - **Structured**: call `update_plan`, execute sequentially, and validate after major steps.
   - **Parallel**: split into 2-3 independent units with disjoint write scopes and delegate only
     bounded tasks with explicit ownership.
   - **Orchestrated**: decompose into waves, keep the critical path local, and only wait on
     delegated work when blocked.
6. Validate using [references/validation-reference.md](references/validation-reference.md).
7. Finish with outcome, verification status, and unresolved risks.

## Rules

- Keep this skill focused on classification, decomposition, delegation, and validation.
- Do not over-orchestrate simple tasks.
- Do not delegate blocking work that should be handled locally right now.
- Keep delegated prompts minimal: objective, context, constraints, success criteria, output.
- When using subagents, assign disjoint ownership and require summary, files touched, and
  verification.
- If delegated work conflicts, fails validation, or overlaps in write scope, fall back to
  local structured execution.
- Ask clarifying questions only when ambiguity would materially risk the result.
