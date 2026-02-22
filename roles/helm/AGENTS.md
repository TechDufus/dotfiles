# Helm Role

Installs Helm (Kubernetes package manager) and configures chart repositories from `group_vars/all.yml`.

## Key Files
- `~/.config/helm/` - Helm config directory
- `~/.cache/helm/repository/` - Repository cache
- `group_vars/all.yml` - `helm.repos` list for chart repositories

## Patterns
- **Repository management**: Uses `kubernetes.core.helm_repository` module to add repos from `helm.repos` variable
- **Ubuntu GPG verification**: APT installation uses keyring at `/usr/share/keyrings/helm.gpg`
- **Fedora fallback**: Primary DNF, fallback to GitHub release installer for user-local install

## Integration
- **k9s**: Helm values plugin configured in k9s plugins.yaml (`Shift-V` to view values)
- **kubectl**: Required for Helm to communicate with clusters
- **Shell**: Completion loaded via shell configs; Starship shows Helm context

## Repository Configuration Example
```yaml
# group_vars/all.yml
helm:
  repos:
    - name: traefik
      url: https://helm.traefik.io/traefik
    - name: prometheus-community
      url: https://prometheus-community.github.io/helm-charts
```

## Gotchas
- **Repository config location**: Repos defined in `group_vars/all.yml` under `helm.repos`, not in role files
- **No Arch support**: `Archlinux.yml` not implemented
- **Requires kubectl context**: Helm operations fail without valid kubeconfig
- **APT key path matters**: Ubuntu uses `/usr/share/keyrings/helm.gpg` for secure key storage
