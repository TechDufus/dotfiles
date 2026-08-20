# OMP role

`roles/omp` manages this dotfiles repo's global Oh My Pi user base at `~/.omp/agent`. Keep it OMP-specific: do not import external Claude/Codex guidance wholesale, and do not document unrelated Worktrunk launcher, Neovim worktree, MCP pinning, or marketplace-install behavior here.

## Managed files

- `config.yml`, `models.yml`, `lsp.json`, and local-mode overlays are repo-managed symlinks under `~/.omp/agent/`; local launchers are repo-managed symlinks under `~/.local/bin/`. `models.yml` supplies static metadata for the derived local model while retaining runtime discovery, so a stale discovery cache cannot prevent a launcher from starting. If a destination regular file differs, the role fails: copy intended live changes back into `roles/omp/files/` or remove the unmanaged file before rerunning. Normal `omp` uses OMP's default home; do not relocate it with environment overrides.
- Managed YAML is the authoritative record of current role assignments, context handling, and behavior pins. Preserve only deliberate overrides: omit a setting that matches the upstream default unless retaining it is an intentional reproducibility or behavior decision. Re-audit after OMP upgrades because inherited behavior can change with upstream defaults.
- `mcp.json` stays a regular file, not a symlink. The role rejects symlinks and special files, merges managed servers into existing `mcpServers`, preserves unowned entries, and writes restrictive permissions because OAuth and per-user credentials may land there.
- `agents/*.md` defines additional global OMP agents with OMP frontmatter and focused prompts. Specialist routing and effort policy belong in their managed sources rather than this overview.
- `extensions/*` is deployed as per-file symlinks into `~/.omp/agent/extensions/`; never symlink the whole directory. Unrelated user-installed extension files are preserved, and cleanup removes only stale repo-owned symlinks whose managed source no longer exists. Regular files at repo-managed extension names are migrated safely: identical copies are removed, while differing files are backed up outside the extensions directory before being replaced by the repo symlink.
- The managed configuration expresses long-task, notification, security, and delegation policy. Normal cloud sessions intentionally follow upstream capability-aware compaction ordering and allow speculative provider-native work to hide latency; local modes naturally fall back to local methods. Preserve the intent to keep long-running work controlled and reviewable, and reconsider deliberate constraints when upstream behavior changes.

### Context ownership

Keep always-visible context small and assign each concern one owner:

- OMP's installed bundled system prompt and generated tool guidance own generic agent behavior.
- `AGENTS.md` contains only true user interaction and review preferences; `RULES.md` contains only hard user invariants such as repository-memory verification, secret handling, autonomous local checkpoints, and approval before remote or shared-state mutations.
- `WATCHDOG.md` is repo-managed global advisor-only guidance: a secondary review lens, not primary guidance or hard policy.
- OMP injects skill descriptions as discovery metadata, not skill bodies. A long `SKILL.md` should remain a short router with explicit `skill://` links; supporting references stay out of context until the model reads them.
- Implementation code and tests, not explanatory prose, own exact runtime contracts.

Re-audit this ownership split and every deliberate constraint after OMP or model upgrades. Delete obsolete guidance instead of layering a second instruction over changed upstream behavior or retaining conflicting duplication.

## Local Ollama modes

The Ollama role installs and starts Ollama, provisions the supported base and derived local models when needed, and records their current metadata in `models.yml`. Verify provisioning with `ollama list`. The derived model exists to enforce a practical local context limit rather than relying on the base model's runtime default.

`models.yml` makes the derived local model resolvable before runtime discovery refreshes and retains discovery for other local models. Current selectors, capabilities, and context metadata are maintained there.

The role starts only the lightweight Ollama server; it does not preload the large model into GPU memory. OMP or `ollama-qwen` loads it on first use. Preload and pin it explicitly, then release it immediately, with the shell-independent commands:

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

Both launchers select their managed overlay, publish the derived model's practical context limit, and forward session arguments unchanged. They are session launchers, not wrappers for every OMP management subcommand; use `omp` directly for management commands.

`omp-local-max` is the fully local mode: normal role resolution stays local, and its managed configuration prevents automatic hosted-model fallback. An explicit CLI model override remains an intentional escape hatch.

`omp-local-assist` is the hybrid mode: it keeps the selected fast and supporting work local while retaining the normal cloud roles needed for higher-capability work. Its configuration deliberately leaves those inherited cloud roles available.

These modes use CLI `--config` overlays rather than named profiles. A named profile relocates the complete OMP user base and would lose the normal base's global rules, agents, extensions, skills, authentication, and session state unless all of them were duplicated. An overlay changes only the listed settings while preserving the normal `~/.omp/agent` base.

## Herdr

`/skill:herdr` is the official upstream skill, shallow-cloned from `herdrdev/herdr` into `~/.local/share/dotfiles/herdr`; the clone root's `skills/herdr` subdirectory is symlinked into the OMP user base. On each real OMP role run, the role updates the checkout from configurable `omp_herdr_skill_version` (`master` by default); set `omp_herdr_skill_enabled` to `false` to disable this management. The role refuses an unmanaged regular destination, and an update failure preserves an existing valid checkout.

`/skill:herdr-workflow` is the dotfiles-owned durable-task overlay. It loads the intentionally mutable upstream skill while keeping workflow policy reviewable here. New tasks use a Herdr-owned isolated worktree workspace by default; an explicitly requested current-workspace tab composes Herdr with Worktrunk, which owns checkout cleanup. The workflow does not automatically commit, push, open a pull request, or force cleanup.

The global `/herd` extension creates a Worktrunk-owned isolated checkout and opens a visible OMP agent in a new no-focus tab in the invoking Herdr workspace. Provisioning, including dry runs, requires `HERDR_ENV=1`, an invoking OMP session file, and exactly one matching native Herdr pane; it fails closed rather than falling back to the focused pane. Local help is available without those preconditions.

```text
/herd
/herd <exact task>
/herd context [--branch=<name>] [--base=<ref>] [--no-secret] [--dry-run] [-- <additional exact instructions>]
/herd task [--branch=<name>] [--base=<ref>] [--no-secret] [--dry-run] -- <exact task>
/herd issue <123|#123|owner/repo#123|GitHub URL> [--branch=<name>] [--base=<ref>] [--no-secret] [--dry-run] [-- <additional exact instructions>]
/herd done [--force|-f] [--delete|-d]
```

Blank `/herd` aliases `context`; `/herd <exact task>` is the preferred shorthand. Use the explicit modes for options and mode-specific inputs. Options are parsed only before `--`; text after it remains one exact, opaque instruction string. `/herd --help`, `/herd -h`, and `/herd help` show the local grammar and defaults.

By default, the new tab's marked zsh shell runs `secret` before its first `omp` command. Secret output is suppressed, the canonical OMP process inherits the exported environment without putting secret values in Herdr arguments or metadata, and OMP does not start if loading fails. Use `--no-secret` to skip loading for a handoff.
Issue references are resolved before the Worktrunk handoff. An unqualified `123` or `#123` means issue `123` in the current repository. A qualified `owner/repo#123` or GitHub issue URL may name the current repository or, when it is a fork, its explicit direct parent; an unrelated repository is rejected. The issue repository supplies metadata only: the local source checkout and Worktrunk checkout remain in the current repository (the fork, when applicable), and `--base` still selects the source checkout's base ref.

The upstream lookup is exactly `gh issue view <number> --repo <issue-owner>/<issue-repo> --json number,title,labels`; the selected issue repository is not used as a checkout or implicit base.


```text
/herd Fix the refresh-token race without changing the public API
/herd context --branch=review-auth
/herd task --base=release/2.x -- Fix the refresh-token race without changing the public API
/herd issue owner/repo#123 --branch=issue-123 -- Preserve the issue's compatibility constraints
/herd context --dry-run -- Focus on the database migration risk
/herd context --no-secret -- Review public documentation only
/herd done
/herd done --force
/herd done --delete
/herd done -f -d
```

The source checkout must be on a named local branch. Worktrunk hooks remain enabled, approval requirements stop for user review, and `--dry-run` resolves inputs without creating anything. Dirty or untracked source changes are reported but are not stashed, copied, or inherited by the isolated checkout.

After installing or updating this native OMP extension, restart the OMP process. `/new` resets only the conversation, and `/reload-plugins` does not rediscover native extension modules. If `/herd --help` reaches the model as an ordinary user message, `/herd` is not registered in that process.

Run `/herd done` only from its managed OMP agent and only with a clean checkout: no form discards dirty work or passes Worktrunk `--force`. Plain `/herd done` additionally requires the exact local `HEAD` to have merged through one matching GitHub pull request; Worktrunk removes the checkout but preserves its local branch. `/herd done --force` (`-f`) skips only that PR proof, likewise retaining the local branch and never modifying a remote branch. `/herd done --delete` (`-d`) also skips that proof and instead asks Worktrunk to delete the unmerged local branch; `-f -d` is accepted but equivalent to `-d`. After confirmed local deletion, it makes one best-effort deletion of only the branch's exact configured upstream. The raw local fetch URL and optional raw local push URL are read without includes or Git URL rewrites; an absent push URL falls back to the fetch URL. Both endpoints must be credential-free GitHub endpoints and match by canonical immutable repository identity. Deletion uses canonical HTTPS from an isolated bare repository with system, global, ambient, template, and source-local Git configuration excluded, guarded by an explicit full-`HEAD` force-with-lease. Missing or ambiguous tracking, identity mismatch, branch retention, a lease rejection, or an uncertain network outcome never broadens or retries the deletion.

Agent workflow policy starts at [`SKILL.md`](./files/skills/herdr-workflow/SKILL.md) and routes specialized detail to the [general handoff](./files/skills/herdr-workflow/references/general-handoff.md), [herd extension](./files/skills/herdr-workflow/references/herd-extension.md), [prompt construction](./files/skills/herdr-workflow/references/prompt-construction.md), and [ownership and cleanup](./files/skills/herdr-workflow/references/ownership-and-cleanup.md) references. The exact `/herd` runtime contract lives in [`files/extensions/herd.ts`](files/extensions/herd.ts) and [`tests/test_herd_extension.sh`](tests/test_herd_extension.sh); [`tests/test_herdr_workflow.py`](tests/test_herdr_workflow.py) checks the repo-owned workflow policy.

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
