---
name: intent
description: Extract the underlying intent behind a request, issue, PR, or diff. Focus on problem and desired outcome; do not propose implementation, testing strategy, or rollout plans.
---

# Intent

Identify what the author is trying to accomplish, even when proposed code quality is weak.

## Inputs
Accept any of:
- Raw text request
- GitHub issue URL
- GitHub PR URL
- Commit hash + message + diff snippet

Optional controls (soft extensions):
- `context_budget`: `minimal` | `standard` | `broad` (default `standard`)
- `external_findings`: prior findings, review notes, or claim lists to reconcile
- `alignment_check`: `true` | `false` (default `false`) or explicit natural-language request
- `pr_body_draft`: `true` | `false` (default `false`) or explicit natural-language request
- `pr_body_style`: `concise` | `standard` | `detailed` (default `standard`)

Consider a control "requested" when either:
- The structured flag is provided in input, or
- The prompt explicitly asks for that behavior (for example: "validate alignment" or "draft PR body").

If a URL is provided and `gh` is available, fetch only the context needed for the selected budget.

## Default workflow
1. Gather enough context to infer intent, scoped by `context_budget`.
2. Infer core problem, desired outcome, affected users/systems, and non-goals.
3. Ground every inference in concrete evidence from primary artifacts.
4. If evidence is ambiguous or conflicting, state the conflict explicitly and lower confidence.
5. If inputs are missing, ask for the minimum needed inputs and provide a provisional draft with assumptions.
6. Choose output shape from request intent:
   - General intent request: use the default 7-section contract.
   - Intent + optional extensions: return default contract, then append requested extension block(s).
   - Explicit extension-only request: return only requested extension block(s), anchored to intent.

## Context budget rubric
- `minimal`: prompt plus one primary artifact (issue body, PR description, or diff summary)
- `standard`: add linked issue/PR context, diff direction, and recent discussion/review comments
- `broad`: add related artifacts that could materially change intent inference
- Stop when additional context no longer changes inferred intent.

## External findings reconciliation (optional)
- Treat each `external_findings` item as a claim, not ground truth.
- Validate claims against primary evidence before accepting them.
- Use statuses: `valid` | `partially_valid` | `invalid` | `unverified`.
- Keep unresolved conflicts explicit and carry them into confidence + missing inputs.

## Default output contract
For general intent requests, return exactly these seven sections in this order:

1. **Intent (one sentence)**
2. **Who/what is affected**
3. **Evidence for inferred intent** (concrete signals only)
4. **Non-goals** (what this request is not trying to solve)
5. **Confidence** (`high` | `medium` | `low`) + one-line rationale
6. **Missing inputs** (max 5 bullets)
7. **PR-ready intent summary** (copy/paste text)

## Optional extensions (only when requested)
When requested, use one of:
- `default + extension(s)`: keep sections 1-7 unchanged, then append extension block(s).
- `extension-only`: return only requested extension block(s) when the user explicitly asks for only alignment validation or only PR body drafting.

- Alignment check: include
  - `Intent Baseline`
  - `Alignment Verdict` (`aligned` | `partially_aligned` | `misaligned`)
  - `Claim Validation Table` with columns: `Claim | Status | Evidence | Impact`
  - Use statuses in every row: `valid` | `partially_valid` | `invalid` | `unverified`
  - `Gaps vs Intent`
  - `Confidence` (`high` | `medium` | `low`) + one-line rationale
  - `Missing Inputs` (max 5 bullets)
- PR body draft: include
  - `Proposed PR Body` (lead with intent; keep implementation detail secondary)
  - `Applied?` (`no` by default)
  - If explicitly requested to apply and tooling allows: include `Target URL` and `Fields Changed`

## Rules
- Treat poor implementation quality as separate from intent quality.
- Use implementation details only as evidence to infer intent.
- Do not propose implementation, architecture, testing strategy, or rollout plans.
- Prefer user-facing outcomes over code-churn descriptions.
- If evidence is weak, ambiguous, or conflicting, say so explicitly.
- If uncertainty can be resolved, ask direct missing-input questions.

## GitHub handling
- Issue: prioritize stated pain, repro details, and impact.
- PR: prioritize stated pain plus diff direction, linked issues, and review comments.
- In all cases, avoid over-fetching; gather only enough context to infer intent.

## If input is insufficient
Return `Missing inputs` first, then provide a provisional intent draft with explicit assumptions.
