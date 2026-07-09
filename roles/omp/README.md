# OMP role

`roles/omp` manages this dotfiles repo's global Oh My Pi user base at `~/.omp/agent`. Keep it OMP-specific: do not import external Claude/Codex guidance wholesale, and do not document unrelated Worktrunk launcher, Neovim worktree, MCP pinning, or marketplace-install behavior here.

## Managed files

- `config.yml` and `lsp.json` are repo-managed symlinks into `~/.omp/agent/`. If a destination regular file exists and differs, the role fails; copy live changes back into `roles/omp/files/` or remove the unmanaged file before rerunning. Normal `omp` should use OMP's default home; do not relocate it with `PI_CONFIG_DIR` or `PI_CODING_AGENT_DIR` for the default profile.
- Repo-managed `modelRoles` in the default and deep-review configs use `openai-codex/gpt-5.6-terra:xhigh` for `default`, `task`, `slow`, `plan`, `designer`, and `vision`; `openai-codex/gpt-5.6-luna:xhigh` for `smol` and `commit`; and `openai-codex/gpt-5.6-terra:low` for the lightweight advisor. The default `config.yml` keeps that advisor always on and main-session-only: `advisor.enabled: true`, `advisor.subagents: false`, `advisor.syncBacklog: "3"`, `advisor.immuneTurns: 5`, and `tier.advisor: none` while `tier.openai` stays `default`. `openai-codex/gpt-5.6-sol` is unsupported for this account and intentionally unconfigured.
- `mcp.json` stays a regular file, not a symlink. The role rejects symlinks and special files, merges managed servers into existing `mcpServers`, preserves unowned entries, and writes mode `0600` because OAuth and per-user credentials may land there.
- `AGENTS.md` is global OMP guidance: stance, style, evidence expectations, review posture.
- `RULES.md` is global hard policy: durable MUST/NEVER requirements agents should obey without explanation-heavy prose. When extracting rules from `AGENTS.md`, avoid duplicate or divergent wording; guidance explains, rules bind.
- `WATCHDOG.md` is repo-managed global advisor-only guidance, symlinked into `~/.omp/agent/`. It gives the advisor a secondary review lens only; `AGENTS.md` remains the primary global guidance and `RULES.md` remains hard policy.
- `agents/*.md` defines additional global OMP agents with OMP frontmatter only: `name`, `description`, optional `tools`, optional `thinkingLevel`, optional `read-summarize`, then the system prompt body.
- `extensions/*` is deployed as per-file symlinks into `~/.omp/agent/extensions/`; never symlink the whole directory. Unrelated user-installed extension files are preserved, and cleanup removes only stale repo-owned symlinks whose managed source no longer exists. Regular files at repo-managed extension names are migrated safely: identical copies are removed, while differing files are backed up outside the extensions directory before being replaced by the repo symlink.
- `profiles/deep-review/agent/config.yml` is a heavier deep-review profile candidate. OMP profiles are full user-base relocations, not overlays: a profile does not inherit the default base's config, agents, rules, extensions, or skills unless that profile explicitly deploys them. Treat profile content as a complete alternate base, so the full deep-review advisor policy applies only when that profile is selected.
- Repo-managed OMP configs use compact-first long-task handling: `contextPromotion.enabled: false` keeps threshold maintenance from switching Terra work to Luna before compaction, and compaction stays on `snapcompact` while threshold maintenance uses a percentage-based 65% threshold.

## Agents

Global agents must extend bundled OMP agents, not replace them. Do not create global agents named `explore`, `plan`, `designer`, `reviewer`, `task`, `sonic`, `librarian`, or `oracle`; those names belong to OMP and should keep receiving upstream prompt/tool updates.

Preferred repo-managed additions are generic specialists such as `gap-advisor`, `plan-critic`, `risk-assessor`, `validator`, and `security-auditor`. Their prompts should add focused review/risk/validation behavior while delegating ordinary exploration, planning, implementation, and review to OMP's bundled agents.

## LSP and providers

LSP strategy: rely on OMP built-ins first, then Bun-installed JavaScript LSP server packages for common web/config languages, with `lsp.json` reserved for explicit gaps or repo-specific overrides such as Ansible. Do not duplicate built-ins in `lsp.json` unless overriding a concrete issue.

External provider discovery is intentionally disabled in `config.yml`, including ambient Claude, Codex, OpenCode, Cursor, Gemini, Windsurf, VS Code, GitHub, and Bedrock discovery/import paths plus external user/project skills and commands. Repo-managed OMP files are the source of truth for global behavior.

## Out of scope for this README

Do not claim these are implemented by the OMP role unless a future change actually adds and verifies them in the owning code: Worktrunk launcher changes, Neovim git-worktree configuration, MCP version pinning, or marketplace installs.
