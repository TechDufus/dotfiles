# Starship

Installs [Starship](https://starship.rs), a cross-shell prompt written in Rust.

- **macOS**: Homebrew
- **Ubuntu**: Official installer script
- **Fedora**: DNF with installer fallback

## Configuration

Deploys `~/.config/starship.toml` with:
- Catppuccin theme (Latte default, all 4 palettes included)
- Git integration with status indicators and remote detection
- Language version display for 40+ languages
- Kubernetes context display
- Custom icons for GitHub/GitLab/Bitbucket

## Usage

```bash
dotfiles -t starship
eval "$(starship init zsh)"  # Add to shell config
```
