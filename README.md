![dotfiles-logo](https://github.com/TechDufus/dotfiles/assets/46715299/6c1d626d-28d2-41e3-bde5-981d9bf93462)

# dotfiles

My personal dotfiles, applied with [mise](https://mise.jdx.dev/bootstrap.html) on three machines:

| Machine | Profile | Desktop |
| --- | --- | --- |
| Laptop | `omarchy` | Omarchy (Hyprland) |
| Desktop | `cachyos` | CachyOS (KDE Plasma, Steam) |
| MacBook | `macos` | macOS |

The repo is public for reference, not as a framework. Read before you borrow.

## Bootstrap

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechDufus/dotfiles/main/bin/dotfiles)"
```

This installs git and mise, clones the repo to `~/.dotfiles`, links `~/.config/mise/conf.d` to `~/.dotfiles/modules`, records the machine profile, and runs `mise bootstrap`. Run `dotfiles` a second time on a fresh machine: some permissions and identity files apply only after the first run creates them.

## Daily use

| Command | Does |
| --- | --- |
| `dotfiles` | Pull the repo, then converge this machine |
| `dotfiles --dry-run` | Preview every change |
| `mise dot status` | Show the state of every managed file |
| `mise run check` | Dry run plus module tests (run it from `~`) |
| `update` | Full system upgrade (`omarchy update`, `paru -Syu`, or Homebrew) |

## Layout

```text
bin/dotfiles          bootstrap + wrapper (curl entrypoint)
modules/<name>/       one mise conf.d folder per module
  mise.toml           every machine
  mise.linux.toml     Omarchy + CachyOS
  mise.macos.toml     MacBook
  mise.omarchy.toml   laptop only
  mise.cachyos.toml   desktop only
  <config files>, bootstrap.sh, tests/
```

[AGENTS.md](AGENTS.md) has the rules for changing modules.
