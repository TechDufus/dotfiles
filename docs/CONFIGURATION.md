# Configuration Reference

## Quick Start

```bash
cp group_vars/all.yml.example group_vars/all.yml
nvim group_vars/all.yml
```

## What's Configurable via Ansible

These are the only things you configure in `group_vars/all.yml`:

### Identity

| Variable | Required | Description |
|----------|----------|-------------|
| `git_user_name` | Yes | Your name for git commits |
| `op.git.user.email` | Yes | 1Password path to your email |

```yaml
git_user_name: "Your Name"

op:
  git:
    user:
      email: "op://Personal/GitHub/email"
```

### Role Selection

| Variable | Description |
|----------|-------------|
| `default_roles` | Roles to run by default |

```yaml
default_roles:
  - system
  - git
  - neovim
  - zsh
  - tmux
```

### Package Lists

| Variable | Description |
|----------|-------------|
| `go.packages` | Go packages to install |
| `helm.repos` | Helm repositories to add |
| `npm_global_packages` | NPM packages (in `roles/npm/defaults/main.yml`) |
| `bun_global_packages` | Bun packages (in `roles/bun/defaults/main.yml`) |

```yaml
go:
  packages:
    - package: github.com/go-task/task/v3/cmd/task@latest
      cmd: task

helm:
  repos:
    - name: traefik
      url: https://helm.traefik.io/traefik
```

### Versions

| Variable | Default | Description |
|----------|---------|-------------|
| `nvm_node_version` | `"lts/*"` | Node.js version via NVM |
| `k8s.repo.version` | `"v1.34"` | Kubernetes repo version |

## What's NOT Configurable via Ansible

Everything else is configured by editing the actual config files directly:

| Tool | Config Location |
|------|-----------------|
| tmux | `roles/tmux/files/tmux/tmux.conf` |
| neovim | `roles/neovim/files/` |
| zsh | `roles/zsh/files/.zshrc` |
| starship | `roles/starship/files/starship.toml` |
| kitty | `roles/kitty/files/kitty.conf` |
| ghostty | `roles/ghostty/files/config` |
| git | `roles/git/files/gitconfig` |

This is intentional. Config files are readable, portable, and self-contained. You look at the file and know exactly what it does.

## Commands

```bash
dotfiles                    # Run all default roles
dotfiles -t neovim,git      # Run specific roles
dotfiles --check            # Dry run
dotfiles -e "var=value"     # Override variable
```
