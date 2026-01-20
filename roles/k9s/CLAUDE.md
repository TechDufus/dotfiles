# K9s Role

Installs k9s Kubernetes TUI with Catppuccin Mocha theme, custom aliases, and Helm values plugin.

## Key Files
- `~/.config/k9s/config.yaml` - Main config (Linux)
- `~/Library/Application Support/k9s/config.yaml` - Main config (macOS)
- `~/.config/k9s/skins/catppuccin_mocha.yaml` - Theme file
- `~/.config/k9s/aliases.yaml` - Custom resource aliases (`:dep` for deployments)
- `~/.config/k9s/plugins.yaml` - Helm values plugin (press `v` on Helm releases)
- `files/` - Source configs in repo

## Patterns

### Catppuccin Theme
Transparent background with Catppuccin Mocha colors:
- Configured via `skin: catppuccin_mocha` in config.yaml
- Theme file in `skins/` subdirectory

### Custom Aliases
Quick resource access: `:dep` navigates to deployments view.

### Helm Plugin
Press `v` on Helm release to view values via `helm get values`.

## Integration
- **Uses**: kubectl context (respects `KUBECONFIG` env var)
- **Uses**: Helm CLI for values plugin

## Gotchas
- Config path differs: `~/.config/k9s/` (Linux) vs `~/Library/Application Support/k9s/` (macOS)
- Ubuntu/Fedora install from GitHub releases; macOS/Arch use package managers
- Mouse disabled by default (`enableMouse: false`) to allow terminal text selection
- Shell pod uses `killerAdmin` image with 100m CPU / 100Mi memory limits
