---
name: test-audit
description: Authoring gates and evidence-led audits for tests that protect real behavior, independent contracts, and credible regressions.
condition: Use whenever writing, changing, reviewing, or auditing tests, including subsystem-wide test-audit campaigns.
---

# Test audit

Use one value bar in three modes:

- **Authoring:** assess every new or changed test before writing it.
- **Audit:** investigate a focused set of suspect tests and any test-only seams
  they keep alive; edit only evidence-backed candidates.
- **Campaign:** audit a subsystem's complete test surface. Read
  [CAMPAIGN.md](CAMPAIGN.md) before starting.

Optimize for trustworthy coverage and maintainability, not deletion totals.
This skill is portable: use the current repository's testing, review, and
contribution conventions, its actual tooling, and already-loaded repository
instructions. Do not introduce a framework, assume a directory layout, or
search for guidance files just because this skill is active. Resolve commands
from the repository's documented workflow and existing scripts/configuration.

## Authoring gate

Before adding or materially changing a test, answer all four questions:

1. **Contract:** What observable behavior, invariant, or independently meaningful
   consumer contract does it protect?
2. **Failure:** What credible regression would make it fail, and would it fail
   for that reason rather than a setup error or unrelated guard?
3. **Ownership:** Why does existing coverage not already catch that failure?
   Give each contract a primary owner at the strongest practical boundary.
   Another layer needs a distinct risk, such as transport encoding, persistence,
   or lifecycle behavior the primary test cannot exercise. Prefer an additional
   table case or existing fixture over a near-duplicate suite; consolidate
   repeated setup when doing so is coherent with the change.
4. **Seams:** Does the test require an export, global, flag, wrapper, reset hook,
   or injection parameter that no production caller needs? Prefer the real
   boundary. Distinguish legitimate production interfaces from test-only access;
   do not introduce a seam solely to inspect private implementation.

An unanswered question means the test is not ready. Check every junk pattern
below as well. A matching test needs the independent contract and evidence
specified by the retention bar, not an exception based on convenience.

A test that breaks under a behavior-preserving refactor is suspect. Rewrite it
around its consumer-visible contract rather than pinning a new implementation.
For regression tests, verify the pre-fix code fails for the intended reason and
the repaired owner passes on the same scenario. If that control cannot safely
run, state the missing evidence; do not claim a demonstrated regression. Use
an isolated copy when a control requires reverting or mutating production
code. Do not replay one bug at every layer without a distinct risk.

## Junk patterns

Use this checklist for both authoring and audits:

- Assertion-free coverage probes, bare not-throw checks without a meaningful
  contract, self-comparisons, and identity/copy/forwarding checks.
- Copied fixtures, file inventories, manifests, export lists, or declarations
  that merely mirror the implementation.
- Exact source/import/string greps; incidental wording, snapshots, names, or
  defaults that are not an independent consumer contract.
- Private predicates, call shapes, wiring, or mock interactions already covered
  at a real boundary.
- Duplicate invocations of the same contract, including implementation-specific
  replays of a shared helper.
- Tests whose only purpose is preserving test-only exports, globals, wrappers,
  or dead production code with no non-test caller.
- Expected values computed by the helper, renderer, or algorithm under test.
- Mocks that implement the asserted behavior, or an identical mock substituted
  for APIs with different semantics.
- Fixtures that supply the receipt, admission decision, callback ordering, or
  persistence result the production owner is supposed to produce.
- Persistence assertions against a store the exercised path never writes.
- Capability tests that restate declared flags rather than exercising the
  delivery, acknowledgement, or observable effect promised by those flags.
- Negative controls that pass for an unrelated reason, such as another guard's
  denial or a rejection the exercised path cannot reach.
- Names or fixtures that claim more than the inputs and assertions exercise.
- Incidental wording or implementation assertions that are repaired by copying
  the latest output into an expected value without identifying a contract.

Do not re-pin incidental wording, source text, inventories, or implementation
snapshots. Remove the low-value assertion, or replace it only when a distinct,
independent contract warrants proof. A passing test with a misleading name is
not evidence for the behavior its name advertises.

## Value and retention bar

Keep coverage that independently protects public API or integration behavior,
protocol compatibility, configuration semantics, migrations, storage integrity,
security boundaries, platform behavior, packaging/release consumption, or other
observable consumer contracts. Preserve real regressions and nonredundant
boundary checks even if they are static, slow, or superficially resemble an
implementation test.

In particular, retain:

- Ordering when consumers can observe it, not merely internal call order.
- Stable keys, paths, exact bytes, or defaults when a real external contract
  requires them, with an independent oracle rather than copied source text.
- Generated or cross-language compatibility checks that compare independently
  defined contracts or actually exercise consumers.
- Security negatives that demonstrably reach the intended guard and would
  succeed or violate the invariant without it.
- Migration, persistence, transport, and platform cases that cover distinct
  failure modes unreachable through stronger existing proof.

Prefer executing the real consumer or validating its produced artifacts.
Static checks may protect an independent schema or compatibility contract,
but do not use greps of source text, imports, or inventories as permanent
coverage. A claimed "architecture contract" still needs consumer-visible
behavior and an independent oracle.

A retained test failing at baseline is a possible product defect, not a deletion
opportunity. Reproduce and investigate it. Distinguish product bugs from
harness/environment failures and unjustified assertions using evidence, not
whether removing the test makes the suite green.

## Read-only discovery

Keep discovery read-only; report candidate evidence before editing. First map
the real ownership boundaries and test routing. For broad scope, use parallel
read-only lanes when available, with complete ownership and a cross-cutting
pattern pass rather than assumed folder names. Outside campaigns, prefer a few
high-confidence candidates over a speculative deletion inventory.

Before judging a candidate, read the full test, including parameter rows, and
its production owner, entry points, relevant callers/callees, sibling
implementations, overlapping tests, CI routing, and relevant history. Inspect
actual dependency source, types, or contract documentation when the claim
rests on dependency behavior. Identify generated files and external consumers
before proposing seam removal. Do not infer that a symbol has no production
callers from one narrow search.

## Candidate evidence

Record all fields before a deletion or consolidation; missing evidence means
retain provisionally and continue investigating:

- Exact test name and location, including separately judged parameter rows.
- What failure the assertions actually detect, and any junk pattern found.
- Non-test callers/consumers of the covered code or support seam, including
  public or dynamic use where relevant.
- Stronger remaining owner-boundary proof, with its location and distinct
  contract, or a substantiated reason no contract needs proof.
- Relevant history and why the test or seam exists; disclose unavailable
  history rather than inventing intent.
- The production or support simplification unlocked, if any.
- Risk, preservation needs, and the smallest credible validation commands or
  executable scenario resolved from the repository.

For retained false positives, record the independent contract and failure mode
that justify them. For consolidation, name the keeper and assertions it must
absorb before removing the old test.

## Coherent edits

Choose one owner-boundary batch. Move meaningful regressions to their canonical
owners and consolidate genuinely duplicate dependency or package checks where
one independent contract can cover them. Preserve distinct risks at different
layers; deduplication is not a quota.

Remove test-only exports, wrappers, globals, reset hooks, or dead paths only
when caller/consumer evidence proves they are obsolete after cutover. Do not
preserve compatibility aliases solely for deleted tests. Do not turn the audit
into a broad production redesign, add replacement implementation checks, or
convert uncertain candidates into deletion targets. Product defects require
explicit scoping and owner-boundary repair, not suppressed failures.

Update affected test routing and existing inventories only when necessary.
Follow applicable documentation requirements, but do not invent workflow
artifacts, mandatory ownership files, line caps, or deletion metrics.

## Validation

Use the repository's existing runner, review gates, and relevant formatting or
static checks. Never edit a checkout while its tests or validation processes
are running. Avoid concurrent validation of half-applied shared edits; finish
a coherent cutover first.

1. Run the smallest credible keeper/owner and affected sibling checks. Confirm
   assertions detect their stated failure, not just that the runner exits zero.
2. Exercise the changed path through an actual consumer scenario or executable
   smoke/dry-run. For removed source or plan assertions, run the real executable
   or artifact consumer that owns the contract. Tests alone are not scenario
   proof.
3. Verify regression controls fail for the intended reason before the repair
   and pass after it. Perform mutation/reversion controls only in a disposable
   isolated copy or worktree, never by overwriting a user's dirty checkout.
4. Run the changed-scope gates required by repository policy and any mandatory
   review. Broaden checks when affected routing, shared support, or boundaries
   justify it; do not substitute an unrelated full suite for focused proof.
5. Report results and limitations honestly: exact checks/scenarios exercised,
   expected versus observed failures, and unrun proof. Separate production,
   tooling, tests, and support changes if reporting counts; counts are context,
   not success criteria.

Do not install tools, access live providers, or mutate shared services merely
to satisfy this skill. Use safe local fixtures and existing tooling where they
exercise the real boundary; obtain authorization for consequential external
proof or report the unavailable prerequisite.

## Review, continuation, and handoff

Follow applicable repository authorization for local commits. Pushes,
deployments, opening/updating PRs, and merges require user permission. No
particular branch, PR, merge strategy, or companion skill is assumed. Continue
with another coherent batch only after reviewing the current change and
refreshing read-only discovery against the actual working revision.

Hand off:

- Scope, root cause, low-value categories removed, and candidate evidence.
- Owner simplifications and where contracts now have their primary proof.
- Retained false positives and why they remain valuable.
- Exact focused checks, wider gates, regression controls, and scenario smoke
  actually run; failures, limitations, and unresolved defects.
- Production/tooling versus test/support changes when useful, without a
  deletion target.
- Local/remote review or commit state, only if applicable and actually known.
- Specific unresolved findings and their evidence, not speculative cleanup.

Adapted from the upstream [OpenClaw test-audit skill](https://github.com/openclaw/openclaw/blob/main/.agents/skills/test-audit/SKILL.md).
The upstream project is provenance, not a runtime or workflow dependency.
