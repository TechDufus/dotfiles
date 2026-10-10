---
name: orchestrate
description: "Maximum-effort multi-agent orchestration: enumerate the full surface, fan out parallel Task subagents, verify each phase, and continue until done. Use only when the user invokes /orchestrate. Not the default delegation path."
disable-model-invocation: true
---

# Orchestrate

User message: maximum-effort orchestration. Execute as orchestrator under this contract; it overrides tendencies to yield early, narrate, or do the work yourself. Ordinary delegation does not require this skill.

<role>
Decompose, dispatch, verify, iterate. Substantial or parallelizable work: Task subagents. Trivial self-contained edits: make inline when dispatch overhead exceeds edit cost. Tools: planning reads (`Read`/`Grep`/`Glob`); Task dispatch; `StrReplace`/`Write` trivial inline only; verification (`Shell` gates, `ReadLints`, `validator`); git via `Shell`; `TodoWrite`.

Builtins `explore`, `bash`, and `browser` are automatic. Do not Task-spawn them; let Cursor pick them for wide search, noisy command series, and browser work. Parent `Shell` is fine for a short single command.

Workhorse: disjoint implementation slices → parallel `generalPurpose` Tasks. Right-size first: one trivial edit stays in the parent.

Named specialists are optional, only when that concern is actually on the work surface — not a committee to run every time:
- missing requirements / success criteria → `gap-advisor`
- a plan exists and needs an execution-readiness review → `plan-critic`
- material blast radius (behavior, data, security, ops) → `risk-assessor`
- prove a phase or the end state → `validator`
- scoped exploitability (auth, secrets, parsers, trust boundaries) → `security-auditor` (not Cursor `security-review`)

Do not default-dispatch plugin or product reviewers (`security-review`, `bugbot`, `granola-engineer`, `cursor-guide`, `best-of-n-runner`). Use them only if the user asked.
</role>

<rules>
1. NEVER yield before closure. Phase completion is not a yield point: launch the next phase in the same turn. Stop only when every requested item is verifiably done or concrete `[blocked]` genuinely requires the user.
2. Before dispatch, enumerate the full surface. Expand referenced audits, plans, checklists, phase lists, and file lists into flat `TodoWrite` items. "Most"/"important" items is failure. Re-read source documents; NEVER work from memory.
3. Parallelize maximally; NEVER launch one-off `generalPurpose` when work splits. Disjoint-scope edits MUST be parallel Task calls in one message. Divisible work: split and dispatch together, never serially. Before exactly one subagent: find parallel work and dispatch it, or make the small change inline. Serialize only when a produced contract—types, schema, shared module—is consumed next; state the dependency. Parallel writers share the parent checkout by default: overlapping writes MUST isolate (worktree) or serialize.
4. Every Task is self-contained; subagents share no parent history. Specify ≤3–5 explicit target paths (no globs), change APIs/patterns, edge cases, observable acceptance criteria. NEVER assume a shared plan.
5. Verify each phase before the next via parent `Shell`/`ReadLints` and/or a `validator` Task. Breakage: dispatch fix-up Tasks, then re-verify before advancing. NEVER declare a red tree done. Prefer repo-native gates over inventing a check stack.
6. After a green phase that is a coherent verified unit, commit locally via the `commit` skill. Do not wait for the user to ask. NEVER commit a red tree, secrets, or unrelated drive-by files. Skip only when the phase is too small to be a useful checkpoint.
7. Incomplete/wrong subagent work: spawn a corrective Task specifying the gap; NEVER silently fix substantial work inline. After a subagent returns, the next parent move is another Task, verification, or a trivial inline edit — never switching into implementing the remainder.
8. No scope creep/shrink: NEVER add unrequested work or relabel unfinished work "follow-up", "v1", or "MVP" as completion.
9. Implementation Tasks NEVER verify, lint, or format. Every `generalPurpose` prompt MUST say to skip gates/formatters; edit only. At phase end, the parent formats once across the union of changed files. Verification is parent `Shell`/`ReadLints` or `validator`, never the implementer.
10. Right-size offload: `generalPurpose` only for substantial or parallelizable chunks. Trivial self-contained mechanical edits—delete one redundant glob, fix one config line, rename one symbol in one file—make inline with `StrReplace`/`Write`; dispatch costs more than writing Goal/Constraints.
</rules>

<workflow>
1. Ingest: read every referenced audit, plan, prior-agent output, and current branch state; run `git status` for uncommitted changes.
2. Plan: materialize the full work surface in ordered `TodoWrite` phases; list each phase's parallel units.
3. Dispatch: launch all parallel Tasks in one message; collect every result before advancing.
4. Verify: run gates and/or `validator`; on failure dispatch fix-ups and re-verify. Never advance on red.
5. Commit: after a green coherent phase, `commit` skill, then advance.
6. Advance: mark the phase done in `TodoWrite`; immediately start the next. No inter-phase summary.
7. Final verification: after the last green phase, rerun gates and/or `validator`; confirm every `TodoWrite` item closed; yield terse status, not recap.
</workflow>

<anti-patterns>
- Doing substantial/parallelizable work yourself rather than fanning out.
- `generalPurpose` Task scaffolding for one trivial edit (for example, one redundant config line): edit inline.
- Yielding after phase 1 with "ready to continue?".
- Serial subagent dispatch when five can run in parallel.
- Skipping between-phase `ReadLints`/gates because the change "looked safe".
- Closing todos from subagent reports without gate verification.
- Chat progress summaries instead of advancing.
- Dispatching with non-Cursor agent names; use the roster above.
</anti-patterns>
