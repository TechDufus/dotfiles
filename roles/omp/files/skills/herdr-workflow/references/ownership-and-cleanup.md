# Ownership, failures, and cleanup

When the router includes this reference, it owns the resource ledger, retained-state handling, failures after mutation, and owner-specific cleanup.

## Per-request resource ledger

Maintain a ledger containing:

- the confirmed Worktrunk checkout path and verified named branch;
- the Herdr workspace or tab identifier, its root/agent pane identifier, and the agent name, as applicable;
- each resource's owner (`Herdr` or `Worktrunk`) and whether this workflow created it or merely reused it;
- each resource's last observed lifecycle state, or `unknown` when a timeout or kill prevents confirmation.

Record a resource as confirmed only after its creation or reuse is confirmed. A timed-out or killed mutation with no returned identifier is recorded separately as a possibly created resource with unknown identity and state, not as confirmed absent.

Execute the workflow as bounded inspect, create or open, start, wait, and read steps rather than as one opaque command.

## Timeout and partial-failure rules

A timeout or killed result is not success, even when its exit code is zero, and is not permission to poll forever. On timeout, re-resolve current JSON state once, read a bounded amount of recent output once, and report the timeout and any blocked, unavailable, or unknown state.

For a failed, timed-out, or killed `/herd` acceptance prompt, perform exactly one fresh get and one bounded read. Report the structured agent status when available; otherwise report it as unavailable.

A killed Worktrunk or tab-create mutation may have created a resource without returning its identifier. A killed agent-start or agent-prompt mutation may have started work without returning confirmation. Record the affected state as unknown, retain every confirmed resource, and direct the user to inspect current Worktrunk and Herdr state rather than attempting cleanup.

On partial failure, report the detailed ledger, the failed stage and observed error or status, whether a visible OMP process may still be running, and the safe next action: inspect current Worktrunk and Herdr state.

Never automatically close, delete, clean up, or roll back after partial failure. Never force cleanup of a resource whose identity, state, ownership, or cleanliness is unknown.

## Owner-specific cleanup

Never delete or close pre-existing resources.

Close a workflow-created tab or workspace only when explicitly requested or clearly part of requested cleanup.

Before removing a Herdr-owned isolated checkout, require explicit cleanup intent, fresh ownership and cleanliness checks, and current identifier resolution; never force removal of a dirty worktree.

For the explicit current-workspace topology, Herdr may close a workflow-created tab, but Worktrunk alone owns checkout removal. Remove a Worktrunk-owned checkout only through the loaded Worktrunk workflow with hooks and approval gates intact.