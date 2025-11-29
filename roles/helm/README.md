# Helm

Installs [Helm](https://helm.sh/), the Kubernetes package manager.

- **macOS**: Homebrew
- **Ubuntu**: Official APT repository (GPG verified)
- **Fedora**: DNF with GitHub release fallback

## Configuration

Configures Helm repositories from `group_vars/all.yml`:

```yaml
helm:
  repos:
    - name: traefik
      url: https://helm.traefik.io/traefik
```

## Usage

```bash
dotfiles -t helm
helm repo list
```
