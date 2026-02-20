# Codex Role

Install and configure the OpenAI Codex CLI with version-controlled user memory.

## What This Role Does

- Installs `codex`:
  - macOS: Homebrew cask (`codex`)
  - Linux (Ubuntu/Fedora/Arch): latest GitHub release binary to `~/.local/bin/codex`
- Ensures `~/.codex/AGENTS.md` is a symlink to `roles/codex/files/AGENTS.md`
- Ensures `~/.codex/config.toml` is a symlink to `roles/codex/files/config.toml`
- Backs up a pre-existing non-symlink `~/.codex/AGENTS.md` to `~/.codex/AGENTS.md.backup`
- Backs up a pre-existing non-symlink `~/.codex/config.toml` to `~/.codex/config.toml.backup`

## Usage

```bash
dotfiles -t codex
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
