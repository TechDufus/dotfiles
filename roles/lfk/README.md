# LFK Ansible Role

Installs and configures [lfk](https://github.com/janosmiko/lfk), a fast terminal UI for Kubernetes that uses a yazi-style three-column layout.

## What It Does

- Installs `lfk`
  - macOS: Homebrew tap `janosmiko/tap`
  - Linux: GitHub release binary via the shared `github_release` role
- Deploys `~/.config/lfk/config.yaml`
- Matches the existing K9s feel where the tools overlap:
  - Catppuccin Mocha
  - Transparent terminal background
  - Mouse capture disabled for normal terminal selection
  - Direct resource browsing instead of the startup dashboard
  - 1s watch interval and 200-line log tail
  - Familiar K9s-style abbreviations such as `dep`, `svc`, `cm`, and `netpol`

## Usage

```bash
dotfiles -t lfk
lfk
lfk --context my-cluster -n kube-system
lfk --read-only
```

## Optional Dependencies

- `kubectl` is required and should already be handled by the `k8s` role.
- `helm` enables lfk's Helm release actions.
- `trivy` enables image vulnerability scanning.

LFK has built-in Helm actions for values, all values, diff, history, rollback, upgrade, and uninstall, so the K9s Helm-values plugin does not need a separate custom action here.
