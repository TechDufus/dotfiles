# Bun Role

Ansible role for installing [Bun](https://bun.sh/) - a fast all-in-one JavaScript runtime.

## Supported Platforms

| Platform | Installation Method | Status |
|----------|-------------------|--------|
| macOS | Official Homebrew tap | Supported |
| Ubuntu | Official install script | Supported |
| Fedora | - | Not supported |
| Arch | Pacman (`bun`) | Supported |

## What Gets Installed

- **Bun runtime** - Fast JavaScript/TypeScript runtime, bundler, and package manager
- **Shared Bun global packages** - JavaScript-distributed LSP servers and related npm CLIs used by OMP/editor roles for binary auto-detection
- **Ubuntu**: Installed to `~/.bun/bin/bun` via official script
- **macOS**: Installed via the official `oven-sh/bun` Homebrew tap
- **Archlinux/CachyOS**: Installed via pacman

## Configuration

Default global packages are managed in `roles/bun/defaults/main.yml`.
Additional packages can be configured in `group_vars/all.yml`:

```yaml
bun_extra_packages:
  - prettier
```

## LSP Package Boundary

The default `bun_global_packages` list is shared infrastructure for OMP and editors:

- It installs JavaScript-distributed LSP servers and related npm CLIs whose package-to-binary mapping is reliable for Bun global installs. Coverage includes TypeScript, YAML, Bash, Pyright, Ansible, Dockerfile, Tailwind, Astro, GraphQL, Svelte, HTML/CSS/JSON/ESLint (`vscode-langservers-extracted`), Biome, Vue, Prisma, Vimscript, Emmet, and PHP/Intelephense.
- It keeps these JavaScript-distributed servers in one Bun-managed place instead of duplicating installs in OMP, agent, or editor roles.
- It intentionally excludes servers that are not distributed through npm/Bun or are better owned by language/package-manager roles, such as Marksman, nixd/nil, rust-analyzer, jdtls, and Metals.

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
