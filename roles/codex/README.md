# Codex Role

Install and configure the OpenAI Codex CLI with version-controlled user memory.

## What This Role Does

- Installs or upgrades `codex`:
  - macOS: Homebrew cask (`codex`)
  - Linux (Ubuntu/Fedora/Arch): compares installed version to latest GitHub release and installs `~/.local/bin/codex` when missing or outdated
- Ensures `~/.codex/AGENTS.md` is a symlink to `roles/codex/files/AGENTS.md`
- Ensures `~/.codex/config.toml` is a symlink to `roles/codex/files/config.toml`
- Copies custom agents from `roles/codex/files/agents/` into `~/.codex/agents/`
- Symlinks custom skills from `roles/codex/files/skills/` into `~/.codex/skills/`
- Validates repo-managed custom skills before symlinking them into `~/.codex/skills/`
- Optionally cleans up legacy official-skill symlinks/cache from older role versions
- Removes stale managed custom-agent files that no longer exist in dotfiles
- Removes stale managed custom-skill symlinks that no longer exist in dotfiles
- Backs up a pre-existing non-symlink `~/.codex/AGENTS.md` to `~/.codex/AGENTS.md.backup`
- Backs up a pre-existing non-symlink `~/.codex/config.toml` to `~/.codex/config.toml.backup`

## Usage

```bash
dotfiles -t codex
```

## Git Hygiene

`codex` writes local trust metadata into [`files/config.toml`](./files/config.toml). The repo-managed hook at `.githooks/pre-commit` strips staged `trust_level = ...` lines and `[projects."..."]` tables from the committed version of that file without rewriting your working copy.

Enable the hook once per clone:

```bash
git config core.hooksPath .githooks
```

## Agent and Skill Overrides

Default custom-agent and custom-skill paths are configured in `roles/codex/defaults/main.yml`.
Override these vars in inventory/group vars if needed:

- `codex_custom_agents_source`
- `codex_custom_agents_dest`
- `codex_skills_source`
- `codex_skills_dest`
- `codex_cleanup_legacy_official_skills`

## Custom Agents in Dotfiles

Add custom agents under `roles/codex/files/agents/*.toml`.
The role copies each file into `~/.codex/agents/` and tracks the managed set with a manifest.
This is intentional: Codex `0.118.x` discovers custom agents only from real files and skips symlinked agent entries.

Current repo-managed agents:

| Agent | Purpose |
|------|---------|
| `advisor` | Pre-plan gap analysis for hidden requirements, missing context, and scope risk |
| `critic` | Stress-tests implementation plans for sequencing, completeness, and validation gaps |
| `librarian` | Read-heavy summarizer for files, diffs, logs, and git history |
| `reviewer` | Code review focused on correctness, regressions, security, and missing tests |
| `risk_assessor` | Cross-stack change-risk analysis for plans, diffs, and implemented changes |
| `security_auditor` | Security-focused review for exploitable risks and dependency signals |
| `validator` | Runs relevant checks and returns a binary readiness verdict |

Codex already ships with built-in `default`, `worker`, and `explorer` agents.
This role adds the narrower specialist agents and leaves the general implementation agents to Codex itself.

Example:

```text
roles/codex/files/agents/
├── advisor.toml
├── critic.toml
├── librarian.toml
└── validator.toml
```

## Custom Skills in Dotfiles

Add custom skills under `roles/codex/files/skills/<skill-name>/` (each needs `SKILL.md`).
The role symlinks each directory into `~/.codex/skills/<skill-name>`.

Built-in `.system` skills are provided by Codex and do not need to be managed by this role.

Current repo-managed skills:

| Skill | Purpose |
|------|---------|
| `commit` | Safe conventional commit workflow |
| `intent` | Extract intent and non-goals from requests, issues, PRs, or diffs |
| `rafty` | RAFT and Rafty CLI workflows |
| `work` | Task routing and execution strategy for non-trivial engineering work |

Example:

```text
roles/codex/files/skills/
└── my-custom-skill/
    ├── SKILL.md
    ├── scripts/
    └── references/
```

Validate custom skills manually:

```bash
python3 roles/codex/files/scripts/validate_skills.py roles/codex/files/skills
```

## Listing Available Skills

List curated skills from `openai/skills`:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py
```

List curated skills as JSON:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py --format json
```

List experimental skills:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py --path skills/.experimental
```

Install a curated skill:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --repo openai/skills --path skills/.curated/gh-fix-ci
```

Restart Codex after installing new skills so they are discovered.

## Files

```text
roles/codex/
├── defaults/main.yml
├── files/AGENTS.md
├── files/agents/
├── files/config.toml
├── files/scripts/
├── files/skills/
└── tasks/
    ├── main.yml
    ├── MacOSX.yml
    ├── Ubuntu.yml
    ├── Fedora.yml
    ├── Archlinux.yml
    └── Linux.yml
```
