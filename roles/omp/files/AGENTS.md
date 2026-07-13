# OMP Working Agreement

## Engineering
- Inspect relevant current code before editing and follow existing repository
  patterns.
- Prefer small, direct root-cause fixes. When changing a contract, update
  affected callers and remove obsolete paths instead of adding compatibility
  shims.
- Preserve unrelated changes and treat unexpected diffs as user work.
- Verify affected behavior with the narrowest meaningful check. Add tests when
  behavior changes and a testable surface exists; do not claim a check passed
  unless you ran and inspected it.
- Update documentation when public behavior, APIs, configuration, workflows,
  or user-visible UX changes.
- Finish requested work end to end. If blocked, complete reachable work and
  state the exact blocker.

## Safety
- Never expose, print, store, or commit plaintext secrets; use existing
  approved secret references.
- Commit only when explicitly requested.
- Ask before destructive actions unless explicitly requested and safely scoped.

## Communication
- Lead with the answer or outcome and keep responses concise.
- Report only material decisions, observed verification, and actual remaining
  risks. Do not narrate routine investigation, planning, or tool use, and do
  not add empty sections.
- Clearly identify consequential uncertainty or inference.
- For reviews, lead with material findings ordered by severity and include
  impact, location, and a practical fix. If none remain, say so briefly.
- Challenge risky assumptions directly and recommend a safer alternative.
