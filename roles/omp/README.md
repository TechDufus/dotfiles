# OMP role

`roles/omp` manages this dotfiles repo's global Oh My Pi user base at `~/.omp/agent`. Keep it OMP-specific: do not import external Claude/Codex guidance wholesale, and do not document unrelated Worktrunk launcher, Neovim worktree, MCP pinning, or marketplace-install behavior here.

## Managed files

- `config.yml` and `lsp.json` are repo-managed symlinks into `~/.omp/agent/`. If a destination regular file exists and differs, the role fails; copy live changes back into `roles/omp/files/` or remove the unmanaged file before rerunning. Normal `omp` should use OMP's default home; do not relocate it with `PI_CONFIG_DIR` or `PI_CODING_AGENT_DIR` for the default profile.
- Repo-managed `modelRoles` use `openai-codex/gpt-5.6-sol:xhigh` for `default`, `openai-codex/gpt-5.6-sol:medium` for `task` and `designer`, `openai-codex/gpt-5.6-sol:high` for `plan`, `openai-codex/gpt-5.6-terra:xhigh` for `slow` and `vision`, `openai-codex/gpt-5.6-luna:xhigh` for `smol` and `commit`, and `openai-codex/gpt-5.6-terra:low` for `advisor` in the normal `config.yml`. The deep-review config retains `openai-codex/gpt-5.6-terra:xhigh` for every substantive role: `default`, `task`, `slow`, `plan`, `designer`, and `vision`; both configs use `openai-codex/gpt-5.6-luna:xhigh` for `smol` and `commit`, plus `openai-codex/gpt-5.6-terra:low` for the lightweight advisor. The default `config.yml` keeps that advisor always on and main-session-only: `advisor.enabled: true`, `advisor.subagents: false`, `advisor.syncBacklog: "3"`, `advisor.immuneTurns: 5`, and `tier.advisor: none` while `tier.openai` stays `default`.
- `mcp.json` stays a regular file, not a symlink. The role rejects symlinks and special files, merges managed servers into existing `mcpServers`, preserves unowned entries, and writes mode `0600` because OAuth and per-user credentials may land there.
- `AGENTS.md` is global OMP guidance: stance, style, evidence expectations, review posture.
- `RULES.md` is global hard policy: durable MUST/NEVER requirements agents should obey without explanation-heavy prose. When extracting rules from `AGENTS.md`, avoid duplicate or divergent wording; guidance explains, rules bind.
- `WATCHDOG.md` is repo-managed global advisor-only guidance, symlinked into `~/.omp/agent/`. It gives the advisor a secondary review lens only; `AGENTS.md` remains the primary global guidance and `RULES.md` remains hard policy.
- `agents/*.md` defines additional global OMP agents with OMP frontmatter only: `name`, `description`, optional `tools`, optional `thinkingLevel`, optional `read-summarize`, then the system prompt body.
- `extensions/*` is deployed as per-file symlinks into `~/.omp/agent/extensions/`; never symlink the whole directory. Unrelated user-installed extension files are preserved, and cleanup removes only stale repo-owned symlinks whose managed source no longer exists. Regular files at repo-managed extension names are migrated safely: identical copies are removed, while differing files are backed up outside the extensions directory before being replaced by the repo symlink.
- `profiles/deep-review/agent/config.yml` is a heavier deep-review profile candidate. OMP profiles are full user-base relocations, not overlays: a profile does not inherit the default base's config, agents, rules, extensions, or skills unless that profile explicitly deploys them. Treat profile content as a complete alternate base, so the full deep-review advisor policy applies only when that profile is selected.
- Repo-managed OMP configs use compact-first long-task handling: `contextPromotion.enabled: false` keeps threshold maintenance from switching Terra work to Luna before compaction, and compaction stays on `snapcompact` while threshold maintenance uses a percentage-based 65% threshold.

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
```

Blank `/herd` aliases `context`. The preferred shorthand is `/herd <exact task>`: when the first non-space token is neither `context`, `task`, nor `issue` and does not begin with `-`, the entire trimmed raw tail is passed as one exact task instruction, without tokenizing or rejoining it. Use the explicit `task`, `context`, or `issue` forms for options and mode-specific inputs. A first token beginning with an unrecognized option remains an error.

Use `/herd --help` to display the grammar and defaults locally; `/herd -h` and `/herd help` are exact aliases. Help aliases must be the command's entire raw tail apart from surrounding whitespace.

For example:

```text
/herd Fix the refresh-token race without changing the public API
/herd context --branch=review-auth
/herd task --base=release/2.x -- Fix the refresh-token race without changing the public API
/herd issue owner/repo#123 --branch=issue-123 -- Preserve the issue's compatibility constraints
/herd context --dry-run -- Focus on the database migration risk
```

After installing or updating this native OMP extension, restart the OMP process. `/new` only resets the conversation inside the existing process, and `/reload-plugins` refreshes plugin and command registries without rediscovering native extension modules or rebuilding their runner. If `/herd --help` reaches the model as an ordinary user message instead of showing local help, `/herd` is not registered in that process.

Options are parsed only before `--`; text after it remains one exact, opaque instruction string. The source checkout must be on a named local branch even when `--base` is explicit; the default base is that exact currently checked-out branch. Worktrunk hooks remain enabled and an approval requirement stops the handoff for user review—`/herd` never auto-approves or bypasses hooks. Context mode separately bounds and truncates the latest compaction summary and bounded recent primary user/assistant message blocks before composing them, excludes tool, thinking, and custom entries, and labels the excerpt as reference data. Issue mode reads repository and issue metadata without mutation, rejects cross-repository references, and labels issue content as untrusted reference data.

Automatic branch names use semantic Conventional-Commit-style prefixes aligned with this repository family: `feat/`, `fix/`, `docs/`, `refactor/`, `test/`, `chore/`, `ci/`, `build/`, or `perf/`; they describe the work, not the launcher. In issue mode, labels and a leading bracketed title category choose the prefix: bug/security/correction means `fix/`, documentation means `docs/`, dependencies/maintenance/chore/task means `chore/`, explicit test/refactor/ci/build/performance categories map directly, and enhancement/feature/story means `feat/`. In task or context mode, a clear leading conventional type or action after harmless scaffolding such as `please`, `I want/need to`, `we need to`, or `can you` chooses the prefix: fix/bug/repair/resolve means `fix/`, docs/document/readme means `docs/`, refactor/test/chore/ci/build/performance map directly, and create/add/implement/design means `feat/`. Ambiguous input defaults to `feat/`. Issue slugs use `issue-<number>-<title-with-leading-[TYPE]-removed>`; concise non-issue slugs remove harmless request scaffolding and the recognized leading type or action (for example, `Please fix broken widget` becomes `fix/broken-widget`, and `Create widget` becomes `feat/widget`), while deterministic collision suffixing is unchanged. An explicit `--branch=<name>` is exact: it may use any valid Git ref and is never rewritten or prefixed.
`--dry-run` performs read-only resolution and creates nothing. Normal handoffs do not focus the new tab and return after bounded acceptance observation rather than waiting for task completion. Herdr 0.7.3 creates a fresh split agent pane inside the created tab, so `/herd` tracks the tab's root pane separately from the returned agent pane. Dirty or untracked changes in the source checkout are reported but are not stashed, copied, or inherited by the isolated checkout. Worktrunk owns checkout creation and cleanup; Herdr owns the created tab, panes, and agent. On failure, `/herd` retains a detailed ledger of every confirmed resource: the Worktrunk checkout and verified branch; the Herdr tab, root pane, agent pane, and agent; each resource's owner and last observed state; and an unknown state when a timeout prevents confirmation. A killed Worktrunk, tab-create, or agent-start mutation may have created a resource without returning an identifier; `/herd` reports that ambiguity as unknown and directs the user to inspect current Worktrunk and Herdr state. Nothing is automatically closed, deleted, rolled back, or cleaned up.

This skill management is separate from `omp_herdr_integration_enabled`, which controls Herdr's generated lifecycle and session reporter.

## `/commit` extension

The `/commit` extension presents a visible workflow with `Plan`, `Tree`, `Stage`, `Scan`, and `Commit` steps (plus `Push` when requested). `Stage` builds a private index from current `HEAD` (or an unborn state), treating selected paths literally. `Scan` materializes the exact selected stage-0 blobs and first runs the path-aware `gitleaks dir` against OMP's trusted policy, then runs `gitleaks stdin` over their raw bytes prefixed by 512 printable ASCII bytes so filename and MIME heuristics cannot skip them. Each pass must replace its own strict, fresh report; the workflow scrubs `GITLEAKS*` environment variables, and repository ignores, inline allows, and Git diff attributes cannot suppress findings. Deleted entries and gitlinks are intentionally not blob-scanned, and compressed archive members are not decompressed.

`Commit` succeeds only when this commit process receives matching `prepared` and `committed` reference-transaction receipts for the expected symbolic branch or detached `HEAD` target, base/parent, and scanned tree. Configured hooks remain delegated in normal Git order; mutations or reference mismatches block the commit. The real index remains untouched until success and selected paths are reconciled only while its lock/fingerprint guard holds, preserving newer staging otherwise. Findings, missing capabilities, scan errors, stale or malformed reports, and timeouts fail closed.

An explicitly requested `Push` uses ordinary `git push` for a tracked branch. For a named branch without an upstream, it resolves `branch.<name>.pushRemote`, `remote.pushDefault`, `branch.<name>.remote`, `origin`, or the sole configured remote in that order, then pushes `HEAD` with `--set-upstream`. Detached `HEAD`, a missing remote, or ambiguous remotes leave the new commits local and report a push warning instead of guessing.

The Git role provisions a modern compatible gitleaks through the platform package manager when installation is allowed: Homebrew on macOS, DNF on Fedora/RHEL, and Pacman on Arch Linux. After Debian dispatch, Ubuntu/Debian accepts a candidate only when both `gitleaks dir --help` and `gitleaks stdin --help` advertise every flag the runtime uses. A compatible APT package is preferred; otherwise—including no package-install permission or an unsuccessful or incompatible APT path—the role installs and verifies the pinned official v8.30.1 release in `~/.local/bin` under the same two-subcommand capability contract. A missing or incompatible scanner remains fail-closed for `/commit`.

## Agents

Global agents must extend bundled OMP agents, not replace them. Do not create global agents named `explore`, `plan`, `designer`, `reviewer`, `task`, `sonic`, `librarian`, or `oracle`; those names belong to OMP and should keep receiving upstream prompt/tool updates.

Preferred repo-managed additions are generic specialists such as `gap-advisor`, `plan-critic`, `risk-assessor`, `validator`, and `security-auditor`. Their prompts should add focused review/risk/validation behavior while delegating ordinary exploration, planning, implementation, and review to OMP's bundled agents.

## LSP and providers

LSP strategy: rely on OMP built-ins first, then Bun-installed JavaScript LSP server packages for common web/config languages, with `lsp.json` reserved for explicit gaps or repo-specific overrides such as Ansible. Do not duplicate built-ins in `lsp.json` unless overriding a concrete issue.

External provider discovery is intentionally disabled in `config.yml`, including ambient Claude, Codex, OpenCode, Cursor, Gemini, Windsurf, VS Code, GitHub, and Bedrock discovery/import paths plus external user/project skills and commands. Repo-managed OMP files are the source of truth for global behavior.

## Out of scope for this README

Do not claim these are implemented by the OMP role unless a future change actually adds and verifies them in the owning code: Worktrunk launcher changes, Neovim git-worktree configuration, MCP version pinning, or marketplace installs.
