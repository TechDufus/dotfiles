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

This skill management is separate from `omp_herdr_integration_enabled`, which controls Herdr's generated lifecycle and session reporter.

## `/commit` extension

The `/commit` extension presents a visible workflow with `Plan`, `Tree`, `Stage`, `Scan`, and `Commit` steps (plus `Push` when requested). `Stage` builds a private index from current `HEAD` (or an unborn state), treating selected paths literally. `Scan` materializes the exact selected stage-0 blobs and first runs the path-aware `gitleaks dir` against OMP's trusted policy, then runs `gitleaks stdin` over their raw bytes prefixed by 512 printable ASCII bytes so filename and MIME heuristics cannot skip them. Each pass must replace its own strict, fresh report; the workflow scrubs `GITLEAKS*` environment variables, and repository ignores, inline allows, and Git diff attributes cannot suppress findings. Deleted entries and gitlinks are intentionally not blob-scanned, and compressed archive members are not decompressed.

`Commit` succeeds only when this commit process receives matching `prepared` and `committed` reference-transaction receipts for the expected symbolic branch or detached `HEAD` target, base/parent, and scanned tree. Configured hooks remain delegated in normal Git order; mutations or reference mismatches block the commit. The real index remains untouched until success and selected paths are reconciled only while its lock/fingerprint guard holds, preserving newer staging otherwise. Findings, missing capabilities, scan errors, stale or malformed reports, and timeouts fail closed.

The Git role provisions a modern compatible gitleaks through the platform package manager when installation is allowed: Homebrew on macOS, DNF on Fedora/RHEL, and Pacman on Arch Linux. After Debian dispatch, Ubuntu/Debian accepts a candidate only when both `gitleaks dir --help` and `gitleaks stdin --help` advertise every flag the runtime uses. A compatible APT package is preferred; otherwise—including no package-install permission or an unsuccessful or incompatible APT path—the role installs and verifies the pinned official v8.30.1 release in `~/.local/bin` under the same two-subcommand capability contract. A missing or incompatible scanner remains fail-closed for `/commit`.

## Agents

Global agents must extend bundled OMP agents, not replace them. Do not create global agents named `explore`, `plan`, `designer`, `reviewer`, `task`, `sonic`, `librarian`, or `oracle`; those names belong to OMP and should keep receiving upstream prompt/tool updates.

Preferred repo-managed additions are generic specialists such as `gap-advisor`, `plan-critic`, `risk-assessor`, `validator`, and `security-auditor`. Their prompts should add focused review/risk/validation behavior while delegating ordinary exploration, planning, implementation, and review to OMP's bundled agents.

## LSP and providers

LSP strategy: rely on OMP built-ins first, then Bun-installed JavaScript LSP server packages for common web/config languages, with `lsp.json` reserved for explicit gaps or repo-specific overrides such as Ansible. Do not duplicate built-ins in `lsp.json` unless overriding a concrete issue.

External provider discovery is intentionally disabled in `config.yml`, including ambient Claude, Codex, OpenCode, Cursor, Gemini, Windsurf, VS Code, GitHub, and Bedrock discovery/import paths plus external user/project skills and commands. Repo-managed OMP files are the source of truth for global behavior.

## Out of scope for this README

Do not claim these are implemented by the OMP role unless a future change actually adds and verifies them in the owning code: Worktrunk launcher changes, Neovim git-worktree configuration, MCP version pinning, or marketplace installs.
