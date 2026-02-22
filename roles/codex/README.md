# Codex Role

Install and configure the OpenAI Codex CLI with version-controlled user memory.

## What This Role Does

- Installs `codex`:
  - macOS: Homebrew cask (`codex`)
  - Linux (Ubuntu/Fedora/Arch): latest GitHub release binary to `~/.local/bin/codex`
- Ensures `~/.codex/AGENTS.md` is a symlink to `roles/codex/files/AGENTS.md`
- Ensures `~/.codex/config.toml` is a symlink to `roles/codex/files/config.toml`
- Symlinks custom skills from `roles/codex/files/skills/` into `~/.codex/skills/`
- Optionally cleans up legacy official-skill symlinks/cache from older role versions
- Backs up a pre-existing non-symlink `~/.codex/AGENTS.md` to `~/.codex/AGENTS.md.backup`
- Backs up a pre-existing non-symlink `~/.codex/config.toml` to `~/.codex/config.toml.backup`

## Usage

```bash
dotfiles -t codex
```

## Skill Source and Overrides

Default custom-skill paths and cleanup behavior are configured in `roles/codex/defaults/main.yml`.
Override these vars in inventory/group vars if needed:

- `codex_skills_source`
- `codex_skills_dest`
- `codex_cleanup_legacy_official_skills`

## Custom Skills in Dotfiles

Add custom skills under `roles/codex/files/skills/<skill-name>/` (each needs `SKILL.md`).
The role symlinks each directory into `~/.codex/skills/<skill-name>`.

Built-in `.system` skills are provided by Codex and do not need to be managed by this role.

Example:

```text
roles/codex/files/skills/
└── my-custom-skill/
    ├── SKILL.md
    ├── scripts/
    └── references/
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

## Files

```text
roles/codex/
├── defaults/main.yml
├── files/AGENTS.md
├── files/config.toml
└── tasks/
    ├── main.yml
    ├── MacOSX.yml
    ├── Ubuntu.yml
    ├── Fedora.yml
    ├── Archlinux.yml
    └── Linux.yml
```
