# Jujutsu (jj)

Installs [Jujutsu](https://github.com/jj-vcs/jj), a Git-compatible version control system.

- **macOS**: Homebrew
- **Ubuntu/Linux**: GitHub releases

## Configuration

Deploys `~/.config/jj/config.toml` with:
- SSH commit signing (using `~/.ssh/id_ed25519.pub`)
- Custom log template with color coding
- Git remote defaults (origin)
- 1Password integration for email (with fallback)

## Usage

```bash
dotfiles -t jj
jj init --git myproject
jj  # Shows log (default command)
```
