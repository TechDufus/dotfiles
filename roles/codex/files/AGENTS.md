# Codex User Memory

## Communication
- Start with the direct answer or action.
- Keep language concise, concrete, and technical.
- If blocked, state the blocker and the next best path immediately.

## Coding Standards
- Prefer simple, maintainable solutions over clever abstractions.
- Add or update tests when behavior changes.
- Keep diffs focused on the requested scope.

## Git Rules
- Never commit unless explicitly requested.
- Use conventional commits when commits are requested.
- Do not add AI attribution lines to commit messages.

## Security
- Never commit secrets, tokens, or credentials.
- Prefer 1Password CLI (`op`) for secret retrieval.

## Execution Strategy (Maximum Effort)
- For any non-trivial task, decompose into independent workstreams and run them in parallel with sub-agents.
- Default to 3 parallel roles: `explorer` (read-only discovery), `worker` (implementation), `reviewer` (tests/risk/regression).
- Keep exactly one writer at a time; all other agents stay read-only unless reassigned.
- Wait for all agent outputs, synthesize a single plan, then execute.
- After edits, run a second parallel review pass for correctness, tests, and security.
- Prefer end-to-end completion in one run; do not stop at partial progress unless blocked.
- If multi-agent tooling is unavailable, emulate fanout with parallel shell tasks and continue.
- In every final response, state what was parallelized and what was merged.

## Skill Shorthand
- Use `$commit` to explicitly invoke the `commit` skill.
- If the user types `/commit`, treat it as an intent to use `$commit` even though it is not a built-in slash command.
