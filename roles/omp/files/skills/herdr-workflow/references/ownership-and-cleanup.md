# Ownership, failures, and cleanup

This reference owns resource ledger, retained/partial state, post-mutation failures, and owner-specific cleanup.

## Per-request resource ledger

Maintain a ledger containing:

- the confirmed Worktrunk checkout path and verified named branch;
- the Herdr workspace or tab identifier, its root/agent pane identifier, and the agent name, as applicable;
- each resource's owner (`Herdr` or `Worktrunk`) and whether this workflow created it or merely reused it;
- each resource's last observed lifecycle state, or `unknown` when a timeout or kill prevents confirmation.

Confirm a resource only after confirmed create/reuse. Timed-out/killed mutation without an identifier: separately record a possibly created resource with unknown identity and state, never confirmed absent.

Use bounded inspect, create/open, start, wait, and read steps; no opaque command.

## Timeout and partial-failure rules

A timeout or killed result is not success, even when its exit code is zero; never poll forever. On timeout: re-resolve JSON state once, bounded recent-output read once, report timeout and blocked/unavailable/unknown state.

For a failed, timed-out, or killed `/herd` acceptance prompt, perform exactly one fresh get and one bounded read. Report the structured agent status when available; otherwise report it as unavailable.

Killed Worktrunk/tab-create may create an unidentified resource; killed agent-start/prompt may start unconfirmed work. Mark affected state unknown, retain confirmed resources, direct the user to inspect current Worktrunk and Herdr state; no cleanup attempt.

Partial failure: report detailed ledger, failed stage/error or status, possible running visible OMP, and safe next action: inspect current Worktrunk and Herdr state.

Never automatically close, delete, clean up, or roll back after partial failure; never force cleanup with unknown identity/state/ownership/cleanliness.

## Owner-specific cleanup

Never delete or close pre-existing resources.

Close a workflow-created tab or workspace only when explicitly requested or clearly part of requested cleanup.

Before removing a Herdr-owned isolated checkout, require explicit cleanup intent, fresh ownership and cleanliness checks, and current identifier resolution; never force removal of a dirty worktree.

Current-workspace topology: Herdr may close its workflow-created tab. Remove a Worktrunk-owned checkout only through the loaded Worktrunk workflow with hooks and approval gates intact.

Modes: plain and `--force|-f` pass `--no-delete-branch`; force skips only merged-PR proof. `--delete|-d` alone passes `--force-delete`. All: two fresh exact ownership/cleanliness checks; validated foreground Worktrunk success; never Worktrunk `--force`. Remote deletion only after confirmed local-ref deletion: configured branch remote; exactly one raw local credential-free GitHub fetch endpoint and zero/one push endpoint, read without includes or URL rewrites; both resolve to the same canonical immutable repository. Delete exact upstream ref once, no retry, using canonical HTTPS plus full-OID lease from an isolated bare repository excluding system/global/ambient/template/source-local Git configuration. Report skipped/unknown state truthfully.