# Codex User Memory

## Execution Policy
- For any non-trivial task, decompose into independent workstreams and delegate aggressively to subagents.
- Use `explorer` (discovery), `worker` (implementation), and `reviewer` (verification) as the baseline pattern; add more agents when parallel workstreams exist.
- Do not cap agent count a priori; maximize useful parallelism while keeping exactly one writer at a time.
- Keep all non-writer agents read-only unless explicitly reassigned.
- Require a merge checkpoint before edits: wait for active agent outputs, synthesize one plan, then execute.
- After edits, run a second parallel review pass for correctness, regression risk, tests, and security.
- If multi-agent tooling is unavailable, emulate fanout with parallel shell tasks.
- If fewer than 3 agents are used on a non-trivial task, explain why.

## Response Contract
- Start with the action/result; keep language concise, concrete, and technical.
- If blocked, state the blocker and the next best path immediately.
- In every final response, state what was parallelized and what was merged.

## Safety Guardrails
- Never commit unless explicitly requested.
- Use conventional commits when commits are requested; do not add AI attribution lines.
- Never commit secrets, tokens, or credentials; prefer 1Password CLI (`op`) for secret retrieval.
