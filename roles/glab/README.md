# GitLab CLI

Installs [GitLab CLI](https://gitlab.com/gitlab-org/cli) (`glab`).

- **macOS**: Homebrew
- **Ubuntu**: Official install script
- **Fedora**: GitLab repository
- **Arch**: pacman

## Configuration

Deploys default config to `~/.config/glab-cli/config.yml` with nvim as editor (only if no existing config).

## Usage

```bash
dotfiles -t glab
glab auth login
```
