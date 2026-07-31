# Deterministic `/herd` extension contract

Owns repository-managed `/herd` current-workspace preflight/launch mechanics. Self-contained for non-mutating inspection/dry runs; router adds prompt-construction or ownership rules when needed.

Runtime: `$PI_CODING_AGENT_DIR/extensions/herd.ts` when set; else `$HOME/.omp/agent/extensions/herd.ts`. Repository executable contract: `roles/omp/files/extensions/herd.ts` plus `roles/omp/tests/test_herd_extension.sh`.

## Resolve the caller and preflight without mutation

`/herd` always uses the explicit current-workspace topology. Load `skill://worktrunk` before any checkout operation. Give Worktrunk sole checkout ownership, keep its automation and hooks enabled, and never bypass hooks, use an automatic approval flag, or approve hooks for the user; stop for required approval. Require the source checkout to be on a named local branch even when the user supplies an explicit base. The checked-out source branch establishes source identity only; never substitute it when `--base` is omitted.

Before mutation resolve source repository, exact branch, collisions, status, caller session, and issue metadata needed for naming. Report dirty/untracked changes; never stash or copy into isolated checkout.

Run a fresh structured `herdr pane list`; require exactly one pane whose `agent_session.value` equals that session file. Resolve caller workspace/tab/pane from it. Stop on zero/ambiguous matches; do not require unavailable inherited public IDs.

Never infer caller from focus; never use focus as a fallback. Repeat fresh pane-list/session-file matching immediately before Worktrunk and again before every Herdr topology mutation; require exactly one result.

### Base ref

With an explicit `--base=<ref>`, verify `<ref>^{commit}` as a Git commit before any mutation and pass `<ref>` unchanged. With omitted `--base`, use literal `^`, Worktrunk's detected-default shortcut. Do not pre-resolve `^` or invoke `wt config state default-branch`; resolve the shortcut only inside the real, preflighted `wt switch` call.

A dry run reports that detected-default resolution is deferred to the real handoff and performs no Worktrunk mutation.

### Herd-only OMP overlay

For a real handoff, before any mutation, resolve the effective OMP agent base from non-empty `PI_CODING_AGENT_DIR`; otherwise require `$HOME` and use `$HOME/.omp/agent`. The selected base must be absolute; reject a relative or missing selected base. Append `overlays/herd.yml` and require the resulting absolute path to be an existing readable regular file for the installed repo-managed overlay.

The overlay contains only `paste.largeMenuThreshold: 0` and applies only to OMP sessions started by `/herd`; never disable the menu globally. It makes automated prompts above 100 lines collapse synchronously, so the same atomic Enter sent by `herdr agent prompt` submits the prompt instead of selecting OMP's interactive large-paste menu.

## Execute only argv-backed bounded calls

The extension must invoke every external program as `pi.exec(command, argv, { cwd, timeout })`, never through a shell command string, `sh -c`, interpolation, or `wt --execute`. Every prompt is one exact `argv` element.

Use a cryptographically random suffix in the unique agent name. Never enable OMP auto-approval.

For a real handoff, perform these steps in order:

1. Re-resolve the caller from its native session identity. Run `wt -C <root> switch --create <branch> --base <explicit-ref|^> --no-cd --format=json`, hooks enabled; pass the exact explicit ref or literal `^`. In default mode this single preflighted call atomically resolves shortcut and creates checkout. Never pass `--yes`, `--no-hooks`, or `--clobber`; approval failure stops and is reported. Five-minute bound; parse absolute checkout `path` from JSON.
2. Confirm that the checkout is on the requested named branch before any Herdr mutation.
3. Re-resolve the caller by uniquely matching its OMP session file against a fresh structured pane listing.
4. Run `herdr tab create --workspace <workspace-id> --cwd <path> --label <label> --env <cleanup-ledger-entry> --no-focus`. Pass every cleanup-ledger environment entry at tab creation for root-pane inheritance. Parse tab/root pane; that root pane is the sole OMP/agent pane.
5. Re-resolve caller. In existing root pane run `herdr agent start <unique-name> --kind omp --pane <root-pane-id> --timeout 30000 -- --config <absolute-overlay-path>`, with preflighted overlay and using a wrapper deadline longer than 30 seconds. Agent start activates the pane and creates no tab, split, or other layout resource. Validate identity; require Herdr's returned native argv to equal `["omp", "--config", "<absolute-overlay-path>"]` exactly.
6. Submit exact prompt/bounded acceptance via `herdr agent prompt <name> <prompt> --wait --until working --until blocked --until idle --until done --timeout 15000`, using a wrapper deadline longer than 15 seconds. It atomically submits literal prompt plus Enter. States accept work, approval/question block, or fast completion without indefinite wait. Return after acceptance-only observation; no separate completion wait.

After tab creation, this is the only retry: retry the post-tab root-pane Agent-start call only for an exact structured `agent_pane_busy` error with `error.code` exactly `agent_pane_busy`; reuse the same generated Agent name, root-pane ID, and complete argv for every attempt, within a 5-second monotonic grace window checked at 100ms intervals. Never retry killed calls, malformed error JSON, or any other error code. On grace exhaustion, follow the existing retained-resource failure path.

Never fetch, focus, use pane-run, roll back, or automatically clean up during `/herd`. Failed/timed-out/killed mutation: apply ownership and cleanup rules.