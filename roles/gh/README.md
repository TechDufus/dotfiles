# GitHub CLI

Installs [GitHub CLI](https://cli.github.com/) (`gh`) with the [gh-dash](https://github.com/dlvhdr/gh-dash) extension.

- **macOS**: Homebrew
- **Ubuntu**: APT
- **Fedora**: DNF or GitHub Release fallback

## Configuration

Deploys a Catppuccin Mocha theme for `gh-dash` to `~/.config/gh-dash/config.yaml`.

## Usage

```bash
dotfiles -t gh
gh auth login
gh dash  # Launch dashboard
```
