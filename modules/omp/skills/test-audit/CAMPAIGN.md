# Subsystem test-audit campaign

Campaign mode applies the value bar to a subsystem's **whole owned test
surface**, not just its easiest deletion candidates. The authoring gate,
retention bar, candidate evidence, safety, authorization, validation, and
handoff requirements in [SKILL.md](SKILL.md) apply throughout.

Work in the stages below; each completion criterion is a gate, not permission
to stop before the requested campaign is complete. Optimize for preserved
contracts and simpler ownership, not shrinkage. Use the repository's actual
layout, testing tools, review conventions, and already-loaded instructions.
Do not introduce frameworks, workflow files, test-ownership rules, or line-cap
policies as campaign prerequisites. A ledger can be part of the existing
review/handoff format; no new repository artifact is required.

## 1. Establish the baseline

Define the subsystem and record the actual baseline revision and any local
changes affecting it. Do not reset, stash, overwrite, or discard user-owned
work to get a cleaner baseline. Use an isolated copy when baseline comparison
cannot safely be performed in the current checkout; do not claim a commit SHA
fully identifies a dirty snapshot.

Inventory all in-scope test files and scenarios. Run the repository's applicable
checks to record each file's pass/fail state and baseline scenario behavior.
Record skipped, unavailable, or unrouted cases explicitly and explain what
would be needed to exercise them. Test/support line counts may provide context,
with production counted separately; no deletion target follows from them.

Keep failures in a separate list with their actual failure reasons. A baseline
failure may be a product bug, harness/environment problem, or unjustified
assertion. Investigate rather than classifying it as disposable coverage.

**Complete when:** every in-scope test file/scenario has a recorded baseline
result or an explicit unavailable-proof limitation, and the baseline state is
reproducibly identified. Unavailable proof remains a limitation in the final
claim, not a passing result.

## 2. Map owner-boundary lanes and complete inventory

Split the surface into lanes by **production owner boundaries**, not file
prefixes or assumed directories. Include shared-boundary cases, integration
suites, fixtures/support, generated tests, CI routing, and executable QA or
live scenarios that the subsystem actually owns. Cross-cutting support needs
one editing owner; identify consumers in other subsystems as preservation
constraints rather than silently expanding scope.

Give every test file and owned scenario exactly one inventory lane. For a file
spanning several owners, assign one accountable lane and record its boundary
cross-references; do not count it repeatedly or lose contracts between lanes.
Parallel read-only agents may investigate genuinely independent lanes when
available. A cross-cutting pattern sweep supplements, not replaces, complete
inventory.

**Complete when:** all owned files/scenarios are assigned, the routing that
executes them is known, and shared support and external consumers have owners.

## 3. Build a read-only R/F/C/D ledger

Read each assigned test in full, including parameter rows. Read its production
owner, entry points, relevant callers/callees, sibling implementations,
overlapping proof, history, and CI routing. Inspect dependencies where their
semantics determine the contract. Keep this stage read-only.

Give every declaration one mark. A parameterized declaration can have one mark
only when all rows share that judgment; otherwise mark individual rows.

- **R — Retain:** name the independent contract and credible failure it catches.
  A move to a better owner stays R, with the destination recorded.
- **F — Fix the assertion:** retain the contract but repair inadequate proof,
  such as a vacuous negative that passes when an unrelated guard fires. Name
  the intended failure and how the repaired assertion will detect it.
- **C — Consolidate:** name the keeper that will absorb the contract and
  assertions first, and explain why the retired layer has no distinct risk.
- **D — Delete:** name stronger remaining proof or substantiate why there is no
  meaningful independent contract to preserve.

Judge assertions, exercised inputs, and reachability, not titles. Attach the
candidate evidence required by [SKILL.md](SKILL.md) before proposing removal.
Uncertain candidates remain provisionally R with an investigation note; do not
use C/D as a convenient way to clear failing tests.

**Complete when:** every declaration/necessary row has a mark and evidence,
with retained failures and unresolved judgments explicitly recorded.

## 4. Plan keepers and redundant layers

Make a second read-only pass over the ledger. Treat it as input, not a deletion
script: whole layers may replay one mocked collaborator while a stronger
boundary suite exercises the actual owner. Conversely, similar-looking layers
may cover different transport, lifecycle, security, migration, storage, or
platform risks and must remain.

Name a **keeper** for each contract. Prefer the real owner/consumer boundary
with safe controlled dependencies over a mock that supplies the behavior being
asserted. Plan which assertions and parameter cases move into each keeper
before retiring their old home. Correct ledger mistakes found during this
pass. Check CI routing and non-test consumers before declaring a seam obsolete.

**Complete when:** each lane names keepers, retained distinct risks, retired
files/layers, assertions to carry over, required routing changes, and
caller-evidence-backed test-only seams that cutover can remove.

## 5. Perform a controlled cutover

Apply one coherent lane/boundary batch at a time. Serialize edits to shared
harnesses/support through one owner. Do not edit while validation is running
in that checkout, and do not run checks against half-applied shared changes.

Establish keeper assertions before removing the redundant layer. Remove only
seams proven test-only and obsolete after cutover; public/dynamic consumers
count. Update existing routing or inventories needed to execute moved suites.
Preserve user changes and contracts discovered since baseline. Do not impose
a shrink-only budget, add source redesigns, or manufacture replacement tests
that restate implementation.

After each coherent batch, run the smallest credible owner/sibling checks and
an actual executable consumer scenario using existing tooling. A passing
keeper alone does not prove a deleted contract had a home.

**Complete when:** every lane plan is applied, affected routing remains valid,
and keepers plus relevant executable scenarios have observed proof. Report
unavailable proof explicitly rather than marking it complete and passing.

## 6. Review preservation independently

Have an independent reviewer, or a separate evidence-led review pass if one
is unavailable, compare removed coverage against keepers by boundary group.
Look for contracts that lost their only proof, weakened parameter cases,
assertions whose negatives are unreachable, and mocks that manufacture the
outcome. Review retained failures rather than hiding them in the audit delta.

Restore each real gap at its canonical owner. Reject a reported gap only with
source/consumer evidence, not deletion goals. For each restored contract, use a
controlled mutation of the production owner to prove the keeper fails for the
intended reason:

1. Create a **disposable isolated copy or worktree** of the candidate state,
   including relevant uncommitted changes without modifying the original.
   Identify the revision/snapshot and ensure the keeper executes this copy,
   not a cached build or source from the user's checkout.
2. Change one relevant behavior deliberately and run the focused keeper.
   Record the mutation and the observed assertion failure; a compiler, setup,
   network, or unrelated guard failure does not demonstrate detection.
3. Restore the isolated source exactly, rerun the same check, and observe the
   passing control. Clean up only the disposable artifacts created for this
   proof, preserving any user-owned files or worktrees.

Never mutate/revert the user's dirty checkout or shared services for proof.
Do not copy secrets or invoke live provider operations for a local control.
If isolation or a meaningful mutation is unavailable, disclose the missing
proof instead of claiming preservation has been demonstrated.

**Complete when:** every gap is restored or rejected with evidence, and each
restored contract has intended-failure mutation proof and a passing restored
control, or an explicit unresolved proof limitation.

## 7. Handle product defects without hiding them

A baseline failure that survives as meaningful keeper coverage is a possible
product defect. Reproduce through the real owner flow and separate the failure
from environment/harness problems before proposing a repair. Do not delete or
weaken its assertions to make the campaign green.

Keep owner-boundary bug fixes distinct from pruning edits. Repair them only
when within the authorized scope; otherwise hand off a concrete defect with
reproduction evidence. Local commits follow repository authorization, not an
automatic campaign mandate. Unrelated product discrepancies become findings,
not a license for broad changes.

For each scoped repair, demonstrate the pre-fix failure and post-fix behavior
on the same harness and consumer scenario. If a reversion control is needed,
use the disposable isolation procedure above. Confirm both controls reach the
intended behavior rather than failing at different setup or guard stages.

**Complete when:** every suspected defect is explained or handed off with
reproduction evidence, and every claimed repair has an intended failing
control and passing candidate scenario. Unrepaired defects remain visible.

## 8. Reconcile current state and hand off

Campaigns may span incoming changes. Follow the actual repository integration
workflow and applicable authorization; no default branch, merge strategy,
PR, or automatic remote action is assumed. Inspect changes since the recorded
baseline before finalizing.

If incoming work changed a retired file, review its contracts rather than
blindly keeping the deletion or resurrecting the old suite. Port any new
regression into its keeper, or retain a genuinely distinct boundary. Confirm
all incoming contracts still have an owner. Preserve unrelated user work.
Rerun the subsystem's applicable checks and repeat changed-path executable
smoke on the reconciled state. Ensure preservation review considered the
whole affected surface; split large diffs if tooling truncates them rather
than accepting an incomplete review.

Use the handoff in [SKILL.md](SKILL.md), plus:

- Baseline/final revision or dirty-snapshot identity and inventory completeness.
- Lanes, R/F/C/D decisions, retired layers, keepers, and contract destinations.
- Baseline/final test/support counts if collected, production counted separately.
- Preservation findings, restored contracts, mutations, and observed controls.
- Product defects, authorized repairs, real-flow evidence, and unresolved bugs.
- Reconciliation decisions and exact validation actually run on the final state.
- Any unavailable proof, missing prerequisites, or unresolved preservation risk.

**Complete when:** every owned declaration and scenario is accounted for,
contracts have credible keepers, reconciliation is reviewed, and the handoff
accurately distinguishes observed proof from limitations. Do not claim an
unresolved preservation gap is a completed audit.

Adapted from the upstream [OpenClaw campaign guide](https://github.com/openclaw/openclaw/blob/main/.agents/skills/test-audit/CAMPAIGN.md),
with portable ownership, safety, and evidence requirements.
