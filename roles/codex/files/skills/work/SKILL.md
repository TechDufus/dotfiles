---
name: work
description: Use when the user explicitly invokes $work or asks for execution strategy for complex engineering work with unclear scope, dependent steps, or separable workstreams.
metadata:
  short-description: Route complex work
---

# Work

Route complex work into the smallest execution shape that preserves evidence, focus, and
momentum. Do not duplicate narrower skills; let debugging, TDD, review, PR, or platform-specific
skills own their lanes.

## First Pass

- Outcome: name the concrete deliverable.
- Scope: identify files, systems, and non-goals.
- Evidence: find the source of truth before editing.
- Risk: decide what can break and how to check it.

## Mode

- `quick`: one obvious local step. Execute directly.
- `research`: user needs location, explanation, or confidence. Inspect source and answer.
- `structured`: dependent steps or multi-file edits. Use `update_plan`, then work sequentially.
- `parallel`: independent units with disjoint write scopes. Delegate only sidecar tasks when
  permitted; keep the blocking path local.
- `orchestrated`: large, staged work. Decompose into waves; wait only when blocked.
- `unclear`: ambiguity risks the outcome. Ask the smallest question.

## Noise Filter

- No plan for a one-step fix.
- No broad repo tour before the owning file or API is checked.
- No delegation for trivial or blocking work.
- No unrelated cleanup, refactor, or commentary.
- No completion claim without evidence.

## Closeout

Report what changed, what verified it, and any remaining risk or unverified edge.
