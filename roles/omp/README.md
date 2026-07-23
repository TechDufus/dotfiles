# OMP role

`roles/omp` manages this dotfiles repo's global Oh My Pi user base at `~/.omp/agent`. Keep it OMP-specific: do not import external Claude/Codex guidance wholesale, and do not document unrelated Worktrunk launcher, Neovim worktree, MCP pinning, or marketplace-install behavior here.

## Managed files

- `config.yml` and `lsp.json` are repo-managed symlinks into `~/.omp/agent/`. If a destination regular file exists and differs, the role fails; copy live changes back into `roles/omp/files/` or remove the unmanaged file before rerunning. Normal `omp` should use OMP's default home; do not relocate it with `PI_CONFIG_DIR` or `PI_CODING_AGENT_DIR` for the default profile.
- Both managed `config.yml` files contain only intentional overrides of the installed OMP defaults. Omit a setting when the desired value equals the current default; add it only when this role deliberately diverges. Re-audit after OMP upgrades because inherited behavior follows upstream default changes.
- Repo-managed `modelRoles` use `openai-codex/gpt-5.6-sol:xhigh` for `default`, `openai-codex/gpt-5.6-sol:medium` for `task` and `designer`, `openai-codex/gpt-5.6-sol:high` for `plan`, `openai-codex/gpt-5.6-terra:xhigh` for `slow` and `vision`, `openai-codex/gpt-5.6-luna:xhigh` for `smol` and `commit`, and `openai-codex/gpt-5.6-sol:low` for `advisor` in the normal `config.yml`. The deep-review config retains `openai-codex/gpt-5.6-terra:xhigh` for every substantive role: `default`, `task`, `slow`, `plan`, `designer`, and `vision`; both configs use `openai-codex/gpt-5.6-luna:xhigh` for `smol` and `commit`, plus `openai-codex/gpt-5.6-sol:low` for the lightweight advisor. The effective default-profile advisor is always on and main-session-only: the file overrides `advisor.enabled: true`, `advisor.syncBacklog: "3"`, and `advisor.immuneTurns: 5`, while inheriting upstream `advisor.subagents: false` and `tier.advisor: none`; `tier.openai: default` remains explicit.
- `mcp.json` stays a regular file, not a symlink. The role rejects symlinks and special files, merges managed servers into existing `mcpServers`, preserves unowned entries, and writes mode `0600` because OAuth and per-user credentials may land there.
- `AGENTS.md` contains only deliberate user interaction and review preferences that extend or override OMP's baseline guidance.
- `RULES.md` contains only unique user-specific hard invariants, including repository-memory verification, secret handling, autonomous local-checkpoint policy, and approval before remote or shared-state mutations.
- `WATCHDOG.md` is repo-managed global advisor-only guidance, symlinked into `~/.omp/agent/`. It gives the advisor a secondary review lens only; `AGENTS.md` remains the primary global guidance and `RULES.md` remains hard policy.
- `agents/*.md` defines additional global OMP agents with OMP frontmatter only: `name`, `description`, optional `tools`, optional `thinkingLevel`, optional `read-summarize`, then the system prompt body.
- `extensions/*` is deployed as per-file symlinks into `~/.omp/agent/extensions/`; never symlink the whole directory. Unrelated user-installed extension files are preserved, and cleanup removes only stale repo-owned symlinks whose managed source no longer exists. Regular files at repo-managed extension names are migrated safely: identical copies are removed, while differing files are backed up outside the extensions directory before being replaced by the repo symlink.
- `profiles/deep-review/agent/config.yml` is a heavier deep-review profile candidate. OMP profiles are full user-base relocations, not overlays: a profile does not inherit the default base's config, agents, rules, extensions, or skills unless that profile explicitly deploys them. Treat profile content as a complete alternate base, so the full deep-review advisor policy applies only when that profile is selected.
- Repo-managed OMP configs use compact-first long-task handling. Their non-default `compaction.thresholdPercent: 65` is explicit; they currently inherit upstream `contextPromotion.enabled: false` and `compaction.strategy: snapcompact`. If upstream changes those defaults, effective behavior changes until a new deliberate override is added.

Maintainers should treat the installed bundled system prompt plus generated tool and personality guidance as the baseline: `AGENTS.md` and `RULES.md` contain only deliberate user extensions or overrides, advisor and specialist guidance may repeat baseline risks only to define their respective roles, and this ownership split must be re-audited after OMP upgrades.

## Herdr

`/skill:herdr` is the official upstream skill, shallow-cloned from `ogulcancelik/herdr` into `~/.local/share/dotfiles/herdr` and symlinked into the OMP user base. On each real OMP role run, the role updates the checkout from configurable `omp_herdr_skill_version` (`master` by default); set `omp_herdr_skill_enabled` to `false` to disable this management. The role refuses an unmanaged regular destination, and an update failure preserves an existing valid checkout.

`/skill:herdr-workflow` is the dotfiles-owned durable task overlay: it loads the official skill while keeping workflow policy reviewable in this repository. The official skill checkout is intentionally mutable upstream content. New tasks use a Herdr-owned isolated worktree workspace by default; when the user explicitly requests a current-workspace tab, the workflow composes Herdr with Worktrunk and Worktrunk owns checkout cleanup. It does not automatically commit, push, open a pull request, or force cleanup.

The global `/herd` extension creates a Worktrunk-owned isolated checkout and opens a visible OMP agent in a new no-focus tab in the invoking Herdr workspace. OMP passes the text after an extension slash command to its registered handler as one raw tail; it does not automatically define or parse CLI flags for extensions. `/herd` therefore defines and parses the argument grammar below itself. Provisioning requires `HERDR_ENV=1`, an invoking OMP session file, and exactly one match for that file in a fresh native Herdr pane listing; it fails closed without a match or with multiple matches and never falls back to the focused pane. These preconditions apply to dry runs, but local help is available outside Herdr without them. Its grammar is:

```text
/herd
/herd <exact task>
/herd context [--branch=<name>] [--base=<ref>] [--dry-run] [-- <additional exact instructions>]
/herd task [--branch=<name>] [--base=<ref>] [--dry-run] -- <exact task>
/herd issue <123|#123|owner/repo#123|GitHub URL> [--branch=<name>] [--base=<ref>] [--dry-run] [-- <additional exact instructions>]
/herd done
```

Blank `/herd` aliases `context`. The preferred shorthand is `/herd <exact task>`: when the first non-space token is neither `context`, `task`, `issue`, nor `done` and does not begin with `-`, the entire trimmed raw tail is passed as one exact task instruction, without tokenizing or rejoining it. Use the explicit `task`, `context`, or `issue` forms for options and mode-specific inputs; `done` is the exact cleanup command described below. A first token beginning with an unrecognized option remains an error.

Use `/herd --help` to display the grammar and defaults locally; `/herd -h` and `/herd help` are exact aliases. Help aliases must be the command's entire raw tail apart from surrounding whitespace.

For example:

```text
/herd Fix the refresh-token race without changing the public API
/herd context --branch=review-auth
/herd task --base=release/2.x -- Fix the refresh-token race without changing the public API
/herd issue owner/repo#123 --branch=issue-123 -- Preserve the issue's compatibility constraints
/herd context --dry-run -- Focus on the database migration risk
/herd done
```

After installing or updating this native OMP extension, restart the OMP process. `/new` only resets the conversation inside the existing process, and `/reload-plugins` refreshes plugin and command registries without rediscovering native extension modules or rebuilding their runner. If `/herd --help` reaches the model as an ordinary user message instead of showing local help, `/herd` is not registered in that process.

Options are parsed only before `--`; text after it remains one exact, opaque instruction string. The source checkout must be on a named local branch even when `--base` is explicit; the default base is that exact currently checked-out branch. Worktrunk hooks remain enabled and an approval requirement stops the handoff for user review—`/herd` never auto-approves or bypasses hooks. Context mode separately bounds and truncates the latest compaction summary and bounded recent primary user/assistant message blocks before composing them, excludes tool, thinking, and custom entries, and labels the excerpt as reference data. Issue mode reads repository and issue metadata without mutation, rejects cross-repository references, and labels issue content as untrusted reference data.

Automatic branch names use semantic Conventional-Commit-style prefixes aligned with this repository family: `feat/`, `fix/`, `docs/`, `refactor/`, `test/`, `chore/`, `ci/`, `build/`, or `perf/`; they describe the work, not the launcher. In issue mode, labels and a leading bracketed title category choose the prefix: bug/security/correction means `fix/`, documentation means `docs/`, dependencies/maintenance/chore/task means `chore/`, explicit test/refactor/ci/build/performance categories map directly, and enhancement/feature/story means `feat/`. In task or context mode, a clear leading conventional type or action after harmless scaffolding such as `please`, `I want/need to`, `we need to`, or `can you` chooses the prefix: fix/bug/repair/resolve means `fix/`, docs/document/readme means `docs/`, refactor/test/chore/ci/build/performance map directly, and create/add/implement/design means `feat/`. Ambiguous input defaults to `feat/`. Issue slugs use `issue-<number>-<title-with-leading-[TYPE]-removed>`; concise non-issue slugs remove harmless request scaffolding and the recognized leading type or action (for example, `Please fix broken widget` becomes `fix/broken-widget`, and `Create widget` becomes `feat/widget`), while deterministic collision suffixing is unchanged. An explicit `--branch=<name>` is exact: it may use any valid Git ref and is never rewritten or prefixed.
`--dry-run` performs read-only resolution and creates nothing. Normal handoffs create one no-focus tab, pass the cleanup-ownership ledger environment during tab creation, and use the returned root pane as the sole OMP/agent pane. `/herd` starts that existing pane with the modern Agent primitive, then submits the exact prompt plus Enter atomically with `agent prompt`; bounded exact lifecycle states accept working, blocked, idle, or done without waiting indefinitely for task completion. Agent start does not create a split or any other layout resource. Dirty or untracked changes in the source checkout are reported but are not stashed, copied, or inherited by the isolated checkout. Worktrunk owns checkout creation and cleanup; Herdr owns the created tab, root/agent pane, and agent. On failure, `/herd` retains a detailed ledger of every confirmed resource: the Worktrunk checkout and verified branch; the Herdr tab, root/agent pane, and agent; each resource's owner and last observed state; and an unknown state when a timeout prevents confirmation. A killed Worktrunk or tab-create mutation may have created a resource without returning an identifier, while a killed agent-start or agent-prompt mutation may have started work without returning confirmation; `/herd` reports that ambiguity as unknown and directs the user to inspect current Worktrunk and Herdr state. Nothing is automatically closed, deleted, rolled back, or cleaned up.

Run `/herd done` from the OMP agent that `/herd` started after its exact local `HEAD` has been merged through a GitHub pull request. The command accepts no options. It is intentionally unavailable to pre-existing OMP processes and agents created by older extension versions because `/herd` supplies one cleanup-ownership ledger to the new tab's root/agent pane environment at tab creation.

Cleanup fails closed unless all of the following remain true: the current native OMP session resolves to exactly one pane in its original Herdr tab; the pane and process still belong to the recorded checkout, branch, source repository, workspace, and tab; Worktrunk reports that exact checkout as a non-main worktree; the source and isolated checkout share one Git common directory; the checkout is clean; and exactly one same-repository GitHub pull request matches both its branch and exact local `HEAD`, with merged state and timestamp. `/herd done` does not fetch or infer merge state from local remote-tracking refs.

After repeating the identity, ownership, cleanliness, branch, and `HEAD` checks, `/herd done` refreshes the exact same-repository merged-pull-request proof, then asks Worktrunk to remove the checkout in the foreground with normal hooks and merge-safety checks enabled. It accepts both supported Worktrunk list JSON schemas. It never forces dirty-worktree removal, force-deletes a branch, disables hooks, auto-approves a hook, or bypasses Worktrunk. It validates Worktrunk's structured result, reports when Worktrunk safely retains the local branch, resolves the invoking session again, and closes only the freshly verified Herdr tab as the final action. A refusal before Worktrunk removal leaves the checkout and tab untouched. If removal succeeds but later result, pane, or tab verification fails, the tab stays open and the notification gives the manual recovery state; the checkout may already be gone. A successful tab close can terminate the invoking OMP process before it emits another response.

This skill management is separate from `omp_herdr_integration_enabled`, which controls Herdr's generated lifecycle and session reporter.

## Checkpoint commits and `/commit`

The commit skill and active `omp_commit` tool let the agent create local commits autonomously at coherent, verified checkpoints, including while broader work continues. `/commit` remains an optional manual fast path.

`/commit [optional free-form context]` is a post-work fast path. The live conversation must already establish the related path selection, secret review, and verification evidence that the normal commit skill requires. If that evidence is missing or leaves a possible real secret unresolved, the command makes no tool call and directs the agent to run the normal commit skill/review first instead of guessing.

After the current turn becomes idle, the command sends one hidden, user-attributed request to the current session. It keeps the same model, conversation context, and enabled tools. `omp_commit` is registered active for the session, so `/commit` neither changes the active-tool set nor emits a separate visible authorization marker. The hidden prompt permits at most one `omp_commit` call and no other tool calls during the commit turn; the default `omp_commit` result card is the only workflow UI.

`omp_commit` requires a non-empty commit message and an explicit non-empty list of repo-relative paths. Git treats every supplied path literally. The tool stages the complete current state of only those selected tracked, untracked, or deleted paths and creates one local commit with normal Git hooks. `git commit --only` keeps unrelated pre-existing staged entries outside the commit and staged. Renames require both old and new paths; the exact path `.` is accepted only when every current change is intended.

The workflow is local-only: no push, dry-run, split-commit, or model-selection modes remain. It returns a concise default result containing the immutable commit's short hash, hook-finalized subject, and committed paths. The fast path intentionally performs no automatic credential scan; it relies on secret-review evidence already present in the conversation and blocks when that precondition is not met.

## Agents

Global agents must extend bundled OMP agents, not replace them. Do not create global agents named `explore`, `plan`, `designer`, `reviewer`, `task`, `sonic`, `librarian`, or `oracle`; those names belong to OMP and should keep receiving upstream prompt/tool updates.

Preferred repo-managed additions are generic specialists such as `gap-advisor`, `plan-critic`, `risk-assessor`, `validator`, and `security-auditor`. Their prompts should add focused review/risk/validation behavior while delegating ordinary exploration, planning, implementation, and review to OMP's bundled agents.

## LSP and providers

LSP strategy: rely on OMP built-ins first, then Bun-installed JavaScript LSP server packages for common web/config languages, with `lsp.json` reserved for explicit gaps or repo-specific overrides such as Ansible. Do not duplicate built-ins in `lsp.json` unless overriding a concrete issue.

External provider discovery is intentionally disabled in `config.yml`, including ambient Claude, Codex, OpenCode, Cursor, Gemini, Windsurf, VS Code, GitHub, and Bedrock discovery/import paths plus external user/project skills and commands. Repo-managed OMP files are the source of truth for global behavior.

## Out of scope for this README

Do not claim these are implemented by the OMP role unless a future change actually adds and verifies them in the owning code: Worktrunk launcher changes, Neovim git-worktree configuration, MCP version pinning, or marketplace installs.
