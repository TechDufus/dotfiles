# Bun Role

Ansible role for installing [Bun](https://bun.sh/) - a fast all-in-one JavaScript runtime.

## Supported Platforms

| Platform | Installation Method | Status |
|----------|-------------------|--------|
| macOS | Official Homebrew tap | Supported |
| Ubuntu | Official install script | Supported |
| Fedora | - | Not supported |
| Arch | - | Not supported |

## What Gets Installed

- **Bun runtime** - Fast JavaScript/TypeScript runtime, bundler, and package manager
- **Shared Bun global packages** - JavaScript-distributed LSP servers used by agent/editor roles
- **Ubuntu**: Installed to `~/.bun/bin/bun` via official script
- **macOS**: Installed via the official `oven-sh/bun` Homebrew tap

## Configuration

Default global packages are managed in `roles/bun/defaults/main.yml`.
Additional packages can be configured in `group_vars/all.yml`:

```yaml
bun_extra_packages:
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
- macOS installation uses `brew tap oven-sh/bun` before installing Bun
- Bun auto-upgrades on subsequent runs if already installed
- PATH setup handled by shell role (zsh/bash)
