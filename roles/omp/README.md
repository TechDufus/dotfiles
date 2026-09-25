# OMP role

Keep this page OMP-specific: do not import external Claude/Codex guidance wholesale or claim unrelated Worktrunk launcher, Neovim worktree, or marketplace behavior is implemented here.

## Managed files

- `config.yml`, `lsp.json`, and the Cursor, Claude, Codex, and Herd overlays are repo-managed symlinks under OMP's default base `~/.omp/agent`; `omp-cursor`, `omp-claude`, and `omp-codex` are repo-managed symlinks under `~/.local/bin`. The Herd overlay is selected by the `/herd` extension. The wrappers use fixed overlay paths; see the session-mode notes below. If a destination regular file differs, the role fails: copy intended live changes back into `roles/omp/files/` or remove the unmanaged file before rerunning.
- The repo YAML is the authoritative record of current role assignments and deliberate behavior choices. Preserve only deliberate overrides: omit a setting that matches the upstream default unless retaining it is an intentional reproducibility or behavior decision. Re-audit after OMP upgrades because inherited behavior can change with upstream defaults. Because the managed config is a symlink to this repo, edits take effect when OMP next loads or reloads configuration; deployment is not a version-upgrade mechanism.
- `mcp.json` remains a regular file: the role merges managed servers into existing `mcpServers`, preserves unowned entries, rejects symlinks/special files, and writes mode `0600` under `no_log`. Its Playwright entry keeps explicit `type: stdio` as the role's local transport contract for `bunx @playwright/mcp@latest`; the package is intentionally unpinned.
- `agents/*.md` defines additional global OMP agents with OMP frontmatter and focused prompts. Specialist routing and effort policy belong in those sources rather than this overview.
- `extensions/*` is deployed as per-file symlinks into `~/.omp/agent/extensions/`; never symlink the whole directory. Unrelated user-installed extension files are preserved, and cleanup removes only stale repo-owned symlinks whose managed source no longer exists. Regular files at repo-managed extension names are migrated safely: identical copies are removed, while differing files are backed up outside the extensions directory before replacement.
- Automatic compaction stays at threshold `85`, async enabled, with explicit remote-first order (`remote`, `handoff`, `shake`, `soft`); async speculation applies only when a speculation-capable method resolves first. Experimental inline imaging is separately disabled with `snapcompact.systemPrompt: none` and `snapcompact.toolResults: false`; this is independent of the automatic compaction method order.

`task.maxEffort: xhigh` only caps a spawned task's requested effort when task effort input is enabled and used; `task.enableEffort` remains at OMP's default (`false`). It does not cap the parent session's model selection or thinking level.

The five deliberately retained default-equal pins are `compaction.asyncEnabled: true`, `skills.enableCodexUser: false`, `skills.enableClaudeUser: false`, `commands.enableClaudeUser: false`, and `commands.enableOpencodeUser: false`. The async pin records the compaction preference above; the other four keep foreign-provider user-level skills and commands out of the managed capability surface. These are intentional policy/reproducibility boundaries, not schema requirements.

## Installation, validation, and preservation

With `omp_manage_install` enabled, the role bootstraps the global package only when `omp_real_bin` is absent. An existing executable is not checked against the package/version and is never upgraded or reconciled; installation is not an update channel.

On a normal role run with the executable present, config validation runs that same binary's `omp config list` against a disposable copy of the repo-managed YAML, using `/usr/bin/env -i` with an allowlisted `PATH` and scratch `HOME`, `PI_CODING_AGENT_DIR`, `TMPDIR`/`TMP`/`TEMP`, and working directory. It does not follow the live config symlink, read the live base, or inherit `PI_CONFIG_FILES`, XDG, profile, or other user environment overrides. Config-bearing output is suppressed and scratch state is removed on success or failure. Check mode and a missing binary skip this command. It loads only the isolated YAML/config path: no external providers, extensions, or project configuration are loaded. This is basic isolated load/syntax validation, not strict whole-document schema validation or blanket runtime signoff.

Common managed-file links accept the intended managed symlink or an identical regular-file copy; a foreign symlink, differing regular file, or non-regular collision is refused rather than followed or replaced. `AGENTS.md` is intentionally copy-managed: a differing regular destination is backed up under `.dotfiles-backups/guidance` before replacement, while a symlink or non-regular destination is refused. Same-name user-owned agent or skill entries are also refused, never deleted; extension backup and MCP merge behavior remain as described above.

## Context ownership

Keep always-visible context small and assign each concern one owner:

- OMP's installed bundled system prompt and generated tool guidance own generic agent behavior.
- `AGENTS.md` contains only true user interaction and review preferences; `RULES.md` contains only hard user invariants such as repository-memory verification, secret handling, autonomous local checkpoints, and approval before remote or shared-state mutations.
- `WATCHDOG.md` is repo-managed global advisor-only guidance: a secondary review lens, not primary guidance or hard policy.
- OMP injects skill descriptions as discovery metadata, not skill bodies. A long `SKILL.md` should remain a short router with explicit `skill://` links; supporting references stay out of context until the model reads them.
- Implementation code and tests, not explanatory prose, own exact runtime contracts.

Re-audit this ownership split and every deliberate constraint after OMP or model upgrades. Delete obsolete guidance instead of layering a second instruction over changed upstream behavior or retaining conflicting duplication.


## Cursor session mode

Launch a Cursor-routed session with:

```sh
omp-cursor
omp-cursor --cwd /path/to/repo "Review this change"
```

`omp-cursor` runs `omp --config "$HOME/.omp/agent/overlays/cursor.yml"` and forwards session arguments unchanged. It is a session mode, not a wrapper for OMP management subcommands; use `omp` directly for those.

A named profile relocates and isolates the complete OMP user base; an overlay is a separate settings file and does not relocate that base. Both wrappers pass explicit YAML paths under `${HOME}/.omp/agent/overlays/` regardless of base/profile relocation. Do not assume credentials or other user-base state are inherited across bases. The Cursor overlay's `cursor/*` model scope limits the picker and automatic fallback candidates to Cursor catalog models.

The overlay favors Grok 4.7 in the Cursor catalog rather than mirroring the `openai-codex` base map. Cursor publishes 4.7 as per-effort SKUs (`grok-4.7-low|-high|-xhigh`), not a collapsible `:<effort>` family like Grok 4.6, so the overlay pins those ids:

- Grok 4.7 Extra High serves default, slow, and plan work.
- Composer 2.5 Fast serves smol, tiny, and commit work.
- Grok 4.7 High serves task and designer work, Gemini 3.1 Pro at `high` serves vision work, and Grok 4.7 Low serves advisor work.

## Claude subscription mode

Launch an Anthropic-routed session with:

```sh
omp-claude
omp-claude --cwd /path/to/repo "Review this change"
```

`omp-claude` runs `omp --config "$HOME/.omp/agent/overlays/claude.yml"` and forwards session arguments unchanged. It is a session mode, not a wrapper for OMP management subcommands; use `omp` directly for those.

The Claude overlay changes model-role selection without selecting or relocating the user base. Its `anthropic/*` model scope limits the picker and automatic fallback candidates to Anthropic catalog models.

Before launching, authenticate with the Anthropic provider using `omp login anthropic`. This selects the `anthropic` model provider; it does not opt in to Claude capability discovery. Target 18.3's pre-filter `.claude/settings.json` import limitation is documented below.

The role assignments are:

- `anthropic/claude-opus-5-5:high`: default and task; `anthropic/claude-opus-5-5:max`: slow, plan, and designer.
- `anthropic/claude-haiku-4-5:low`: smol; `anthropic/claude-haiku-4-5:minimal`: tiny and commit.
- `anthropic/claude-sonnet-5:high`: vision; `anthropic/claude-sonnet-5:medium`: advisor.

## Codex subscription mode

Launch an OpenAI Codex-routed session with:

```sh
omp-codex
omp-codex --cwd /path/to/repo "Review this change"
```

`omp-codex` selects its managed CLI `--config` overlay and forwards session arguments unchanged, like `omp-cursor` and `omp-claude`. The overlay pins the full `openai-codex` role map from the base `config.yml`, including `default: openai-codex/gpt-6-sol:xhigh`, and its `openai-codex/*` model scope limits the picker and automatic fallback candidates to Codex catalog models. Keep its roles in sync with the base map when that changes.


## Herdr

`/skill:herdr` is the official upstream skill, shallow-cloned from `herdrdev/herdr` into `~/.local/share/dotfiles/herdr`; the clone root's `skills/herdr` subdirectory is symlinked into the OMP user base. On each real OMP role run, the role updates the checkout from configurable `omp_herdr_skill_version` (`master` by default); set `omp_herdr_skill_enabled` to `false` to disable this management. The role refuses an unmanaged destination, including a foreign symlink, and an update failure preserves an existing valid checkout.

`/skill:herdr-workflow` is the dotfiles-owned durable-task overlay. It loads the intentionally mutable upstream skill while keeping workflow policy reviewable here. New tasks use a Herdr-owned isolated worktree workspace by default; an explicitly requested current-workspace tab composes Herdr with Worktrunk, which owns checkout cleanup. The workflow does not automatically commit, push, open a pull request, or force cleanup.

The global `/herd` extension creates a Worktrunk-owned isolated checkout and opens a visible OMP agent in a new no-focus tab in the invoking Herdr workspace. Provisioning, including dry runs, requires `HERDR_ENV=1`, an invoking OMP session file, and exactly one matching native Herdr pane; it fails closed rather than falling back to the focused pane. Local help is available without those preconditions.

```text
/herd
/herd <exact task>
/herd context [--branch=<name>] [--base=<ref>] [--model=<model-selector>:<effort>] [--dry-run] [-- <additional exact instructions>]
/herd task [--branch=<name>] [--base=<ref>] [--model=<model-selector>:<effort>] [--dry-run] -- <exact task>
/herd issue <123|#123|owner/repo#123|GitHub URL> [--branch=<name>] [--base=<ref>] [--model=<model-selector>:<effort>] [--dry-run] [-- <additional exact instructions>]
/herd done [--force|-f] [--delete|-d]
```

Blank `/herd` aliases `context`; `/herd <exact task>` is the preferred shorthand. Use the explicit modes for options and mode-specific inputs. Options are parsed only before `--`; text after it remains one exact, opaque instruction string. `/herd --help`, `/herd -h`, and `/herd help` show the local grammar and defaults.

The explicit `context`, `task`, and `issue` forms accept one optional paired child override: `--model=<model-selector>:<effort>`. The selector must be non-empty and may contain colons; parsing splits only at the final colon. Accepted efforts are `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`, and `auto`. Do not use separate model or effort flags; repeated `--model` is rejected. Without the option, the child uses the existing defaults; a dry run reports the requested pair without creating resources.

`/herd` neither loads nor clears secrets and does not pass secret-specific environment markers. The OMP process inherits the ordinary environment of its Herdr pane; a normal zsh parent may already have silently loaded its safe local cache. Bootstrap or refresh that cache explicitly with `secret` before launching a new parent shell when credentials are needed.
Issue references are resolved before the Worktrunk handoff. An unqualified `123` or `#123` means issue `123` in the current repository. A qualified `owner/repo#123` or GitHub issue URL may name the current repository or, when it is a fork, its explicit direct parent; an unrelated repository is rejected. The issue repository supplies metadata only: the local source checkout and Worktrunk checkout remain in the current repository (the fork, when applicable), and `--base` still selects the source checkout's base ref.

The upstream lookup is exactly `gh issue view <number> --repo <issue-owner>/<issue-repo> --json number,title,labels`; the selected issue repository is not used as a checkout or implicit base.


```text
/herd Fix the refresh-token race without changing the public API
/herd context --branch=review-auth
/herd task --base=release/2.x -- Fix the refresh-token race without changing the public API
/herd issue owner/repo#123 --branch=issue-123 -- Preserve the issue's compatibility constraints
/herd context --dry-run -- Focus on the database migration risk
/herd context --model=openai-codex/gpt-5.6-terra:xhigh
/herd done
/herd done --force
/herd done --delete
/herd done -f -d
```

The source checkout must be on a named local branch. Worktrunk hooks remain enabled, approval requirements stop for user review, and `--dry-run` resolves inputs without creating anything. Dirty or untracked source changes are reported but are not stashed, copied, or inherited by the isolated checkout.

Native OMP extensions are loaded with the process and require an OMP restart after installation or update. `/new` resets only the conversation, and `/reload-plugins` does not reload native extension modules; no dynamic-reload compatibility is claimed. If `/herd --help` reaches the model as an ordinary user message, `/herd` is not registered in that process.

Run `/herd done` only from its managed OMP agent and only with a clean checkout: no form discards dirty work or passes Worktrunk `--force`. Plain `/herd done` additionally requires the exact local `HEAD` to have merged through one matching GitHub pull request; Worktrunk removes the checkout but preserves its local branch. `/herd done --force` (`-f`) skips only that PR proof, likewise retaining the local branch and never modifying a remote branch. `/herd done --delete` (`-d`) also skips that proof and instead asks Worktrunk to delete the unmerged local branch; `-f -d` is accepted but equivalent to `-d`. After confirmed local deletion, it makes one best-effort deletion of only the branch's exact configured upstream. The raw local fetch URL and optional raw local push URL are read without includes or Git URL rewrites; an absent push URL falls back to the fetch URL. Both endpoints must be credential-free GitHub endpoints and match by canonical immutable repository identity. Deletion uses canonical HTTPS from an isolated bare repository with system, global, ambient, template, and source-local Git configuration excluded, guarded by an explicit full-`HEAD` force-with-lease. Missing or ambiguous tracking, identity mismatch, branch retention, a lease rejection, or an uncertain network outcome never broadens or retries the deletion.

Agent workflow policy starts at [`SKILL.md`](./files/skills/herdr-workflow/SKILL.md) and routes specialized detail to the [general handoff](./files/skills/herdr-workflow/references/general-handoff.md), [herd extension](./files/skills/herdr-workflow/references/herd-extension.md), [prompt construction](./files/skills/herdr-workflow/references/prompt-construction.md), and [ownership and cleanup](./files/skills/herdr-workflow/references/ownership-and-cleanup.md) references. The exact `/herd` runtime contract lives in [`files/extensions/herd.ts`](files/extensions/herd.ts) and [`tests/test_herd_extension.sh`](tests/test_herd_extension.sh); [`tests/test_herdr_workflow.py`](tests/test_herdr_workflow.py) checks the repo-owned workflow policy.

This skill management is separate from `omp_herdr_integration_enabled`, which controls Herdr's generated lifecycle and session reporter.

## Checkpoint commits and `/commit`

The [`commit` skill](files/skills/commit/SKILL.md) and active `omp_commit` tool let the agent create autonomous local commits at coherent, verified checkpoints while broader work continues. `/commit [optional free-form context]` is an optional post-work fast path.

Use `/commit` only after the live conversation establishes the related repo-relative paths, review of their complete changes, secret-review evidence, and completed verification. Missing or unresolved evidence causes the command to make no commit and direct the agent back to the normal skill review rather than guess. Renames require both old and new paths; use `.` only when every current change is intended.

The workflow stages and commits only explicitly selected paths with normal Git hooks, preserves unrelated staged entries outside the commit, and never pushes. The fast path performs no automatic credential scan; its safety depends on the established evidence above. [`files/extensions/commit-ui.ts`](files/extensions/commit-ui.ts) is the exact command and tool implementation, and [`tests/test_commit_ui_extension.sh`](tests/test_commit_ui_extension.sh) is its behavioral contract.

## Agents

At OMP 18.3.0, the bundled agents are `scout`, `reviewer`, `security-reviewer`, `task`, and `sonic` ([immutable upstream source](https://github.com/can1357/oh-my-pi/tree/62bc57be1b03ef0802a33cf7f5f530e534527531)). This repo adds five separate global agent definitions: `gap-advisor`, `plan-critic`, `risk-assessor`, `validator`, and `security-auditor`.

`modelRoles.designer` is a model-role slot, not an agent definition. OMP removed its bundled `designer` agent in 18.1.5 and `librarian` in 18.1.9; do not carry those old names forward as current bundled agents.

## LSP and providers

LSP strategy: rely on OMP built-ins first, then Bun-installed JavaScript LSP server packages for common web/config languages, with `lsp.json` reserved for explicit gaps or repo-specific overrides such as Ansible. Do not duplicate built-ins in `lsp.json` unless overriding a concrete issue.

Foreign-provider user/project skill and command imports remain intentionally disabled by the managed settings; repo-managed skills such as the separately provisioned Herdr/Worktrunk skills are handled independently. For capability discovery, keep OMP's valid IDs `claude`, `claude-plugins`, and `codex` in `disabledProviders`; these are discovery IDs, not provider/model names such as `anthropic` or `openai-codex`. However, target OMP 18.3 imports an initial `.claude/settings.json` before applying discovery filters, so those IDs do not prevent that import. There is no complete local mitigation or denylist guarantee for this path; upstream follow-up is required. Treat this as an unresolved upstream limitation, not blanket runtime signoff ([source pinned to v18.3.0](https://github.com/can1357/oh-my-pi/tree/62bc57be1b03ef0802a33cf7f5f530e534527531)).

Cursor remains enabled for explicit authenticated model selection, but no managed role depends on it. Repo-managed OMP files are the intended source of truth for global behavior, subject to the pre-filter import limitation above.

## Out of scope for this README

Do not claim Worktrunk launcher changes, Neovim git-worktree configuration, or marketplace-install behavior are implemented by the OMP role unless a future change adds and verifies them. The role intentionally does not pin the external Playwright MCP package version.
