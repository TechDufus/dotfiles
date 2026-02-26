# Codex User Memory

## Execution Policy
- Default to a single-agent flow; use subagents only for clearly independent workstreams.
- Use the smallest effective fanout and keep exactly one writer at a time.
- Keep non-writer agents read-only unless explicitly reassigned.
- Before edits, wait for active agent outputs and merge into one plan.
- After substantial edits, run a targeted review pass for correctness, regression risk, tests, and security.
- Close each completed/failed agent immediately after harvesting results.
- Before spawning new agents, run a cleanup pass for completed/idle agents; if spawn hits thread limit, cleanup and retry once with smaller fanout.
- If multi-agent tooling is unavailable, emulate fanout with parallel shell tasks.

## Response Contract
- Start with the action/result; keep language concise, concrete, and technical.
- If blocked, state the blocker and the next best path immediately.
- In every final response, state what was parallelized and what was merged.

## Safety Guardrails
- Never commit unless explicitly requested.
- Use conventional commits when commits are requested; do not add AI attribution lines.
- Never commit secrets, tokens, or credentials; prefer 1Password CLI (`op`) for secret retrieval.
