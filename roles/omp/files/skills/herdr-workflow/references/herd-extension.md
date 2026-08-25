# Deterministic `/herd` extension contract

Scope: repository-managed `/herd` current-workspace mechanics; self-contained read-only inspection/dry run. Runtime: `$PI_CODING_AGENT_DIR/extensions/herd.ts`, else `$HOME/.omp/agent/extensions/herd.ts`. Executable contract: `roles/omp/files/extensions/herd.ts` + `roles/omp/tests/test_herd_extension.sh`.

## Resolve the caller and preflight without mutation

`/herd`: explicit current workspace. Load `skill://worktrunk` before any checkout operation. Give Worktrunk sole checkout ownership; keep its automation and hooks enabled; never bypass or approve hooks. Stop when approval required. Require a named local branch even when the user supplies an explicit base. The checked-out source branch establishes source identity only; never substitute it when `--base` is omitted.

Before mutation: resolve repository, branch, collisions, status, caller session, naming metadata. Report dirty/untracked changes; never stash/copy.

Run fresh structured `herdr pane list`; require exactly one pane whose `agent_session.value` equals that session file. Resolve workspace/tab/pane. Stop on zero/ambiguity; do not require inherited public IDs. Never infer caller from focus; never use focus as a fallback. Repeat fresh matching immediately before Worktrunk and again before every Herdr topology mutation.

### Base ref

With an explicit `--base=<ref>`, verify `<ref>^{commit}` as a Git commit before any mutation and pass `<ref>` unchanged. With omitted `--base`, use literal `^`, Worktrunk's detected-default shortcut. Do not pre-resolve `^` or invoke `wt config state default-branch`; resolve the shortcut only inside the real, preflighted `wt switch` call.

A dry run reports that detected-default resolution is deferred to the real handoff and performs no Worktrunk mutation.

### Model/effort override

Explicit modes optionally accept one `--model=<selector>:<effort>`; split final colon, allowing internal colons. Require selector plus `off|minimal|low|medium|high|xhigh|max|auto`; reject missing/unknown/duplicate values and separate flags. Task still requires `-- <exact task>`. Dry run reports pair without mutation; omission preserves argv.

### Herd-only OMP overlay

For a real handoff, before any mutation, resolve the effective OMP agent base from non-empty `PI_CODING_AGENT_DIR`; otherwise require `$HOME` and use `$HOME/.omp/agent`. The selected base must be absolute; reject a relative or missing selected base. Append `overlays/herd.yml` and require the resulting absolute path to be an existing readable regular file for the installed repo-managed overlay.

The overlay contains only `paste.largeMenuThreshold: 0` and applies only to OMP sessions started by `/herd`; never disable the menu globally. It makes automated prompts above 100 lines collapse synchronously, so the same atomic Enter sent by `herdr agent prompt` submits the prompt instead of selecting OMP's interactive large-paste menu.

## Execute only argv-backed bounded calls

The extension must invoke every external program as `pi.exec(command, argv, { cwd, timeout })`, never through a shell command string, `sh -c`, interpolation, or `wt --execute`. Every prompt is one exact `argv` element.

Use a cryptographically random suffix in the unique agent name. Never enable OMP auto-approval.

For a real handoff, perform these steps in order:

1. Re-resolve the caller from its native session identity. Run `wt -C <root> switch --create <branch> --base <explicit-ref|^> --no-cd --format=json`, hooks enabled, exact explicit ref or `^`. Never pass `--yes`, `--no-hooks`, or `--clobber`; approval failure stops. Five-minute bound; parse absolute checkout `path`.
2. Confirm checkout requested named branch before Herdr mutation.
3. Re-resolve caller from fresh pane list/session-file match.
4. Run `herdr tab create --workspace <workspace-id> --cwd <path> --label <label> --env <cleanup-ledger-entry> --no-focus`. Pass every cleanup-ledger environment entry at tab creation. Parse tab/root pane; that root pane is the sole OMP/agent pane.
5. Re-resolve caller. Run `herdr agent start <unique-name> --kind omp --pane <root-pane-id> --timeout 30000 -- --config <absolute-overlay-path> [--model <selector> --thinking <effort>]` using a wrapper deadline longer than 30 seconds. Agent start activates the pane and creates no tab, split, or other layout resource. Validate identity; require Herdr's returned native argv to equal the exact dynamic expected array: base `["omp", "--config", "<absolute-overlay-path>"]`, plus requested `["--model", "<selector>", "--thinking", "<effort>"]` only, in order.
6. Submit `herdr agent prompt <name> <prompt> --wait --until working --until blocked --until idle --until done --timeout 15000`; wrapper deadline exceeds 15 seconds. Accept working/blocked/idle/done; return without completion wait.

After tab creation, this is the only retry: retry the post-tab root-pane Agent-start call only for an exact structured `agent_pane_busy` error with `error.code` exactly `agent_pane_busy`; reuse the same generated Agent name, root-pane ID, and complete argv for every attempt, within a 5-second monotonic grace window checked at 100ms intervals. Never retry killed calls, malformed error JSON, or any other error code. On grace exhaustion, follow the existing retained-resource failure path.

Never fetch, focus, use pane-run, roll back, or automatically clean up during `/herd`. Failed/timed-out/killed mutation: apply ownership and cleanup rules.