# OMP role

`roles/omp` manages this dotfiles repo's global Oh My Pi user base at `~/.omp/agent`. Keep it OMP-specific: do not import external Claude/Codex guidance wholesale, and do not document unrelated Worktrunk launcher, Neovim worktree, MCP pinning, or marketplace-install behavior here.

## Managed files

- `config.yml`, `models.yml`, `lsp.json`, and the local-mode overlays are repo-managed symlinks under `~/.omp/agent/`; `omp-local-max` and `omp-local-assist` are repo-managed symlinks under `~/.local/bin/`. `models.yml` statically declares the derived Ollama model while retaining runtime Ollama discovery, so a stale discovery cache cannot make the launcher fail before its first refresh. If a destination regular file exists and differs, the role fails; copy live changes back into `roles/omp/files/` or remove the unmanaged file before rerunning. Normal `omp` should use OMP's default home; do not relocate it with `PI_CONFIG_DIR` or `PI_CODING_AGENT_DIR`.
- Both managed `config.yml` files contain only intentional overrides of the installed OMP defaults. Omit a setting when the desired value equals the current default; add it only when this role deliberately diverges. Re-audit after OMP upgrades because inherited behavior follows upstream default changes.
- Repo-managed `modelRoles` use `openai-codex/gpt-5.6-sol:xhigh` for `default`, `slow`, and `plan`, `openai-codex/gpt-5.6-sol:medium` for `task` and `designer`, `openai-codex/gpt-5.6-terra:high` for `vision`, `openai-codex/gpt-5.6-luna:xhigh` for `smol` and `commit`, and `openai-codex/gpt-5.6-sol:low` for `advisor` in the normal `config.yml`. The deep-review config retains `openai-codex/gpt-5.6-terra:xhigh` for every substantive role: `default`, `task`, `slow`, `plan`, `designer`, and `vision`; both configs use `openai-codex/gpt-5.6-luna:xhigh` for `smol` and `commit`, plus `openai-codex/gpt-5.6-sol:low` for the lightweight advisor. The effective default-profile advisor is always on and main-session-only: the file overrides `advisor.enabled: true`, `advisor.syncBacklog: "3"`, and `advisor.immuneTurns: 5`, while inheriting upstream `advisor.subagents: false` and `tier.advisor: none`; `tier.openai: default` remains explicit.
- `mcp.json` stays a regular file, not a symlink. The role rejects symlinks and special files, merges managed servers into existing `mcpServers`, preserves unowned entries, and writes mode `0600` because OAuth and per-user credentials may land there.
- `agents/*.md` defines additional global OMP agents with OMP frontmatter only: `name`, `description`, optional `tools`, optional `thinkingLevel`, optional `read-summarize`, then the system prompt body.
- `extensions/*` is deployed as per-file symlinks into `~/.omp/agent/extensions/`; never symlink the whole directory. Unrelated user-installed extension files are preserved, and cleanup removes only stale repo-owned symlinks whose managed source no longer exists. Regular files at repo-managed extension names are migrated safely: identical copies are removed, while differing files are backed up outside the extensions directory before being replaced by the repo symlink.
- `profiles/deep-review/agent/config.yml` is a heavier deep-review profile candidate. OMP profiles are full user-base relocations, not overlays: a profile does not inherit the default base's config, agents, rules, extensions, or skills unless that profile explicitly deploys them. Treat profile content as a complete alternate base, so the full deep-review advisor policy applies only when that profile is selected.
- Repo-managed OMP configs use compact-first long-task handling. Their non-default `compaction.thresholdPercent: 65` is explicit; they currently inherit upstream `contextPromotion.enabled: false` and `compaction.strategy: snapcompact`. If upstream changes those defaults, effective behavior changes until a new deliberate override is added.

### Context ownership

Keep always-visible context small and assign each concern one owner:

- OMP's installed bundled system prompt and generated tool guidance own generic agent behavior.
- `AGENTS.md` contains only true user interaction and review preferences; `RULES.md` contains only hard user invariants such as repository-memory verification, secret handling, autonomous local checkpoints, and approval before remote or shared-state mutations.
- `WATCHDOG.md` is repo-managed global advisor-only guidance: a secondary review lens, not primary guidance or hard policy.
- OMP injects skill descriptions as discovery metadata, not skill bodies. A long `SKILL.md` should remain a short router with explicit `skill://` links; supporting references stay out of context until the model reads them.
- Implementation code and tests, not explanatory prose, own exact runtime contracts.

Re-audit this ownership split and every deliberate constraint after OMP or model upgrades. Delete obsolete guidance instead of layering a second instruction over changed upstream behavior or retaining conflicting duplication.

## Local Ollama modes

The Ollama role installs and starts Ollama, pulls `qwen3.6:35b` when absent, then creates the derived `qwen3.6:35b-omp` model with `num_ctx 65536`; verify both models with `ollama list`. The derived model is required because the unmodified base otherwise loads with a 32K runtime context on this Mac.

The repo-managed `models.yml` pins that derived model's zero cost, tools, vision, thinking levels, and 64K context metadata while retaining Ollama discovery for other local models. This makes the selector immediately resolvable even when OMP's runtime discovery cache predates the derived model.

The role starts only the lightweight Ollama server; it does not load the 23 GB model into GPU memory. OMP or `ollama-qwen` loads the model on first use. Preload and pin it explicitly, then release it immediately, with the shell-independent commands:

```sh
ollama-qwen-start
ollama-qwen-stop
```

`ollama-qwen-start` keeps the derived model loaded until `ollama-qwen-stop` runs. Without the explicit start command, normal Ollama keep-alive behavior unloads an idle OMP model automatically.

Run either managed launcher for an interactive or print-mode OMP session:

```sh
omp-local-max
omp-local-assist
omp-local-max --cwd /path/to/repo "Review this change"
```

Both launchers export `OLLAMA_CONTEXT_LENGTH=65536`, load their managed file with `omp --config ~/.omp/agent/overlays/<mode>.yml`, and forward session arguments unchanged. The environment setting makes OMP advertise the same practical 64K ceiling enforced by the derived Ollama model; it avoids advertising the model's much larger discovered metadata context when this 48 GiB Mac cannot run that context usefully. These are session launchers, not wrappers for every OMP management subcommand: commands such as `omp config` do not accept `--config`, so run those through `omp` directly.

`omp-local-max` is fully local during normal role resolution: every supported model role resolves to exact selector `ollama/qwen3.6:35b-omp`, `enabledModels` permits only that selector, and the quick-cycle contains only local roles. Substantive, default, task, and advisor work uses maximum thinking; only `smol`, `tiny`, and `commit` deliberately use lower effort. The advisor is enabled for main and subagent sessions, synchronizes after one-turn backlog, and has no interrupt immunity. These settings prevent automatic resolution or fallback from spending hosted-model tokens; an explicit CLI override such as `--model openai-codex/...` remains an intentional escape hatch.

`omp-local-assist` is hybrid. It inherits the normal cloud `default`, `plan`, `vision`, `slow`, `designer`, and `commit` roles, while overriding exactly `advisor`, `task`, `smol`, and `tiny` to local Qwen. Advisor and task use maximum thinking, smol uses high, and tiny uses low. It intentionally has no `enabledModels`, so inherited cloud roles remain available.

These modes use CLI `--config` overlays rather than named profiles. A named profile relocates the complete OMP user base and would lose the normal base's global rules, agents, extensions, skills, authentication, and session state unless all of them were duplicated. An overlay changes only the listed settings while preserving the normal `~/.omp/agent` base.

## Herdr

`/skill:herdr` is the official upstream skill, shallow-cloned from `ogulcancelik/herdr` into `~/.local/share/dotfiles/herdr` and symlinked into the OMP user base. On each real OMP role run, the role updates the checkout from configurable `omp_herdr_skill_version` (`master` by default); set `omp_herdr_skill_enabled` to `false` to disable this management. The role refuses an unmanaged regular destination, and an update failure preserves an existing valid checkout.

`/skill:herdr-workflow` is the dotfiles-owned durable-task overlay. It loads the intentionally mutable upstream skill while keeping workflow policy reviewable here. New tasks use a Herdr-owned isolated worktree workspace by default; an explicitly requested current-workspace tab composes Herdr with Worktrunk, which owns checkout cleanup. The workflow does not automatically commit, push, open a pull request, or force cleanup.

The global `/herd` extension creates a Worktrunk-owned isolated checkout and opens a visible OMP agent in a new no-focus tab in the invoking Herdr workspace. Provisioning, including dry runs, requires `HERDR_ENV=1`, an invoking OMP session file, and exactly one matching native Herdr pane; it fails closed rather than falling back to the focused pane. Local help is available without those preconditions.

```text
/herd
/herd <exact task>
/herd context [--branch=<name>] [--base=<ref>] [--dry-run] [-- <additional exact instructions>]
/herd task [--branch=<name>] [--base=<ref>] [--dry-run] -- <exact task>
/herd issue <123|#123|owner/repo#123|GitHub URL> [--branch=<name>] [--base=<ref>] [--dry-run] [-- <additional exact instructions>]
/herd done
```

Blank `/herd` aliases `context`; `/herd <exact task>` is the preferred shorthand. Use the explicit modes for options and mode-specific inputs. Options are parsed only before `--`; text after it remains one exact, opaque instruction string. `/herd --help`, `/herd -h`, and `/herd help` show the local grammar and defaults.

```text
/herd Fix the refresh-token race without changing the public API
/herd context --branch=review-auth
/herd task --base=release/2.x -- Fix the refresh-token race without changing the public API
/herd issue owner/repo#123 --branch=issue-123 -- Preserve the issue's compatibility constraints
/herd context --dry-run -- Focus on the database migration risk
/herd done
```

The source checkout must be on a named local branch. Worktrunk hooks remain enabled, approval requirements stop for user review, and `--dry-run` resolves inputs without creating anything. Dirty or untracked source changes are reported but are not stashed, copied, or inherited by the isolated checkout.

After installing or updating this native OMP extension, restart the OMP process. `/new` resets only the conversation, and `/reload-plugins` does not rediscover native extension modules. If `/herd --help` reaches the model as an ordinary user message, `/herd` is not registered in that process.

Run `/herd done` only from the OMP agent started by `/herd`, after its exact local `HEAD` has been merged through a matching GitHub pull request. Cleanup fails closed on stale ownership, identity, checkout, branch, cleanliness, or merged-PR evidence. It uses normal Worktrunk hooks and merge-safety checks and never force-removes a dirty worktree, force-deletes a branch, auto-approves a hook, or bypasses Worktrunk.

Agent workflow policy starts at [`files/skills/herdr-workflow/SKILL.md`](files/skills/herdr-workflow/SKILL.md) and routes specialized detail to [`references/general-handoff.md`](files/skills/herdr-workflow/references/general-handoff.md), [`references/herd-extension.md`](files/skills/herdr-workflow/references/herd-extension.md), [`references/prompt-construction.md`](files/skills/herdr-workflow/references/prompt-construction.md), and [`references/ownership-and-cleanup.md`](files/skills/herdr-workflow/references/ownership-and-cleanup.md). The exact `/herd` runtime contract lives in [`files/extensions/herd.ts`](files/extensions/herd.ts) and [`tests/test_herd_extension.sh`](tests/test_herd_extension.sh); [`tests/test_herdr_workflow.py`](tests/test_herdr_workflow.py) checks the repo-owned workflow policy.

This skill management is separate from `omp_herdr_integration_enabled`, which controls Herdr's generated lifecycle and session reporter.

## Checkpoint commits and `/commit`

The [`commit` skill](files/skills/commit/SKILL.md) and active `omp_commit` tool let the agent create autonomous local commits at coherent, verified checkpoints while broader work continues. `/commit [optional free-form context]` is an optional post-work fast path.

Use `/commit` only after the live conversation establishes the related repo-relative paths, review of their complete changes, secret-review evidence, and completed verification. Missing or unresolved evidence causes the command to make no commit and direct the agent back to the normal skill review rather than guess. Renames require both old and new paths; use `.` only when every current change is intended.

The workflow stages and commits only explicitly selected paths with normal Git hooks, preserves unrelated staged entries outside the commit, and never pushes. The fast path performs no automatic credential scan; its safety depends on the established evidence above. [`files/extensions/commit-ui.ts`](files/extensions/commit-ui.ts) is the exact command and tool implementation, and [`tests/test_commit_ui_extension.sh`](tests/test_commit_ui_extension.sh) is its behavioral contract.

## Agents

Global agents must extend bundled OMP agents, not replace them. Do not create global agents named `explore`, `plan`, `designer`, `reviewer`, `task`, `sonic`, `librarian`, or `oracle`; those names belong to OMP and should keep receiving upstream prompt/tool updates.

Preferred repo-managed additions are generic specialists such as `gap-advisor`, `plan-critic`, `risk-assessor`, `validator`, and `security-auditor`. Their prompts should add focused review/risk/validation behavior while delegating ordinary exploration, planning, implementation, and review to OMP's bundled agents.

## LSP and providers

LSP strategy: rely on OMP built-ins first, then Bun-installed JavaScript LSP server packages for common web/config languages, with `lsp.json` reserved for explicit gaps or repo-specific overrides such as Ansible. Do not duplicate built-ins in `lsp.json` unless overriding a concrete issue.

External provider discovery is intentionally disabled in `config.yml`, including ambient Claude, Codex, OpenCode, Cursor, Gemini, Windsurf, VS Code, GitHub, and Bedrock discovery/import paths plus external user/project skills and commands. Repo-managed OMP files are the source of truth for global behavior.

## Out of scope for this README

Do not claim these are implemented by the OMP role unless a future change actually adds and verifies them in the owning code: Worktrunk launcher changes, Neovim git-worktree configuration, MCP version pinning, or marketplace installs.
