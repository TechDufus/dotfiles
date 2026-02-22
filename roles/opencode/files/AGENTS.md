# Codex User Memory

## Communication
- Start with the direct answer or action.
- Keep language concise, concrete, and technical.
- If blocked, state the blocker and the next best path immediately.

## Coding Standards
- Prefer simple, maintainable solutions over clever abstractions.
- Keep files small and focused (prefer <400 LOC; split when growing).
- Add or update tests when behavior changes.
- Keep diffs focused on the requested scope.

## Git Rules
- Never commit unless explicitly requested.
- Use conventional commits when commits are requested.
- Do not add AI attribution lines to commit messages.
- Prefer atomic commits per blast-radius unit (small/medium/large).

## Security
- Never commit secrets, tokens, or credentials.
- Prefer 1Password CLI (`op`) for secret retrieval.
- For infrastructure/security-impacting changes, require explicit human checkpoint before apply/delete/migrate.
- Always provide rollback steps for medium/large changes.

## Execution Strategy (High Throughput, Controlled Risk)
- Default to parallel execution for non-trivial work.
- Use blast-radius labels before starting:
  - `small`: isolated file/task, low merge risk
  - `medium`: cross-file change in one subsystem
  - `large`: architecture/infra/migration change
- Run max one `large` task at a time.
- Prefer 3 parallel roles:
  - `explorer` (read-only discovery)
  - `worker` (implementation)
  - `reviewer` (tests/risk/regression)
- Keep exactly one writer at a time; all others read-only unless reassigned.
- If multi-agent tooling is unavailable, emulate fanout with parallel shell tasks.

## Prompt Contract (Default)
For implementation tasks, include:
1) Goal (1 sentence)
2) Constraints (security/perf/compliance)
3) Acceptance checks (exact commands)
4) Rollback command/path
5) Scope limit (what NOT to touch)

Keep prompts short unless architecture-level complexity requires expansion.

## Verification Loop (Required)
For each completed feature/fix:
1) Implement smallest viable patch
2) Run validation in same context
3) Ask model to generate/update tests immediately
4) Re-run checks
5) Prepare atomic commit summary

## Tooling Preferences
- Prefer local CLIs over MCP where possible for lower context overhead and better debuggability.
- Favor reproducible command-driven workflows (`gh`, `jq`, `yq`, `kubectl`, `helm`, `go test`, linters, scanners).
- Use screenshots for UI debugging when faster than prose.

## Final Response Contract
In final responses, always include:
- What was parallelized
- What was merged
- Validation commands run + results
- Risks/known gaps
- Suggested next step
