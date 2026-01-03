# Bun Role

Ansible role for installing [Bun](https://bun.sh/) - a fast all-in-one JavaScript runtime.

## Supported Platforms

| Platform | Installation Method | Status |
|----------|-------------------|--------|
| macOS | Homebrew | Supported |
| Ubuntu | Official install script | Supported |
| Fedora | - | Not supported |
| Arch | - | Not supported |

## What Gets Installed

- **Bun runtime** - Fast JavaScript/TypeScript runtime, bundler, and package manager
- **Ubuntu**: Installed to `~/.bun/bin/bun` via official script
- **macOS**: Installed via Homebrew

## Configuration

Optional global packages can be configured in `group_vars/all.yml`:

```yaml
bun_global_packages:
  - typescript
  - prettier
```

## Usage

```bash
# Install bun role
dotfiles -t bun

# Verify installation
bun --version
```

## Notes

- Ubuntu installation requires `unzip` (installed automatically if sudo available)
- Bun auto-upgrades on subsequent runs if already installed
- PATH setup handled by shell role (zsh/bash)
