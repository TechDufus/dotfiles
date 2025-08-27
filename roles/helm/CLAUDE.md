# Helm Role - CLAUDE.md

This file provides guidance to Claude Code when working with the Helm role in this Ansible-based dotfiles repository.

## Role Overview

The **Helm role** installs and configures Helm, the Kubernetes package manager, across multiple platforms. Helm is essential for deploying, managing, and templating Kubernetes applications using charts. This role provides automated installation, repository management, and integration with the broader Kubernetes ecosystem in the dotfiles.

### Purpose
- Install Helm CLI tool across macOS, Ubuntu, and Fedora
- Configure Helm repositories for popular chart sources
- Provide consistent Helm setup for Kubernetes development workflows
- Integrate with k9s and kubectl for comprehensive Kubernetes management

## Architecture and Cross-Platform Support

### Supported Platforms
- **macOS**: Homebrew installation (`brew install helm`)
- **Ubuntu**: Official APT repository with GPG key verification
- **Fedora**: System package manager (dnf) with fallback to official installer
- **Arch**: Not implemented (would use pacman)

### Installation Methods by Platform

#### macOS (`MacOSX.yml`)
```yaml
- name: "Helm | MacOSX | Install Helm"
  community.general.homebrew:
    name: helm
    state: present
```
- Simple Homebrew installation
- Leverages macOS package management ecosystem
- Automatically handles dependencies and PATH configuration

#### Ubuntu (`Ubuntu.yml`)
```yaml
# Security-first approach with GPG verification
- name: Helm | Add Helm GPG key
  ansible.builtin.apt_key:
    url: https://baltocdn.com/helm/signing.asc
    keyring: /usr/share/keyrings/helm.gpg
```
- Uses official Helm APT repository
- GPG key verification for security
- Architecture detection for multi-arch support
- APT cache updates for latest versions

#### Fedora (`Fedora.yml`)
```yaml
# Multi-fallback installation strategy
- name: "Helm | Fedora | Install from system package"
  ansible.builtin.dnf:
    name: helm
    state: present
```
- Primary: System DNF package
- Fallback: Official GitHub release installer
- User-local installation when no sudo access
- Comprehensive error handling and reporting

## Helm Repository Management

### Repository Configuration
The role configures Helm repositories from the `helm.repos` variable in `group_vars/all.yml`:

```yaml
helm:
  repos:
    - name: traefik
      url: https://helm.traefik.io/traefik
    - name: prometheus-community
      url: https://prometheus-community.github.io/helm-charts
    - name: grafana
      url: https://grafana.github.io/helm-charts
```

### Repository Management Tasks
```yaml
- name: Helm | Add Helm Repos
  kubernetes.core.helm_repository:
    name: "{{ item.name }}"
    url: "{{ item.url }}"
    repo_state: present
  loop: "{{ helm.repos }}"
```

### Popular Repository Examples
- **Traefik**: Reverse proxy and load balancer
- **Prometheus Community**: Monitoring and alerting
- **Grafana**: Observability and dashboards
- **Bitnami**: Production-ready applications
- **Jetstack**: cert-manager and security tools
- **Ingress-NGINX**: Kubernetes ingress controller

## Integration with Kubernetes Ecosystem

### k9s Integration
The role integrates with k9s for enhanced Kubernetes management:

```yaml
# k9s plugin for viewing Helm values
helm-values:
  shortCut: Shift-V
  description: "View Helm values"
  scopes:
    - deployments
    - statefulsets
  command: helm
  args:
    - get
    - values
    - $COL-NAME
    - -n
    - $NAMESPACE
```

### Shell Integration
- **Bash**: Helm completion in `.bashrc`
- **ZSH**: PowerLevel10k shows Kubernetes context when using `helm` commands
- **Starship**: Helm context display in prompt configuration

### Related Tools
- **kubectl**: Primary Kubernetes CLI integration
- **k9s**: Visual Kubernetes management with Helm plugins
- **Docker/Podman**: Container runtime for Kubernetes workloads

## Chart Development Workflows

### Common Helm Commands and Aliases
```bash
# Repository management
helm repo add <name> <url>
helm repo update
helm repo list

# Chart operations
helm search repo <keyword>
helm install <release> <chart>
helm upgrade <release> <chart>
helm uninstall <release>

# Chart development
helm create <chart-name>
helm template <chart> --values values.yaml
helm lint <chart-path>
helm package <chart-path>

# Release management
helm list
helm status <release>
helm history <release>
helm rollback <release> <revision>
```

### Development Best Practices
```bash
# Dry run installations
helm install --dry-run --debug <release> <chart>

# Template testing
helm template <chart> --values values.yaml > rendered.yaml

# Validation
helm lint <chart-path>
helm test <release>

# Values management
helm get values <release>
helm get manifest <release>
```

## Security Considerations

### Chart Signing and Verification
```bash
# Verify chart signatures
helm verify <chart>

# Install with verification
helm install --verify <release> <chart>

# Generate and manage signing keys
helm plugin install https://github.com/technosophos/helm-gpg
```

### Repository Security
- GPG signature verification for Ubuntu installations
- HTTPS-only repository URLs
- Regular repository updates for security patches
- Keyring isolation (`/usr/share/keyrings/helm.gpg`)

### Best Practices
- Use specific chart versions in production
- Verify chart sources and maintainers
- Implement RBAC for Helm operations
- Scan charts for security vulnerabilities
- Use `--atomic` flag for safer deployments

## Troubleshooting

### Common Issues and Solutions

#### Installation Problems
```bash
# Check Helm installation
helm version

# Verify repositories
helm repo list
helm repo update

# Test connectivity
curl -I https://helm.traefik.io/traefik/index.yaml
```

#### Repository Issues
```bash
# Clear repository cache
helm repo remove <name>
helm repo add <name> <url>

# Manual cache refresh
rm -rf ~/.cache/helm/repository/*
helm repo update
```

#### Permission Problems
```bash
# Check Helm configuration
ls -la ~/.config/helm/
ls -la ~/.cache/helm/

# Fix permissions
chmod -R 755 ~/.config/helm/
chmod -R 755 ~/.cache/helm/
```

#### Kubernetes Context Issues
```bash
# Check current context
kubectl config current-context

# List available contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>
```

### Debugging Commands
```bash
# Verbose Helm operations
helm install --debug --dry-run <release> <chart>

# Helm configuration
helm env

# Repository debugging
helm repo index <directory>

# Template debugging
helm template <chart> --debug
```

## Development Guidelines

### Adding New Repositories
1. Add repository to `group_vars/all.yml`:
```yaml
helm:
  repos:
    - name: new-repo
      url: https://example.com/helm-charts
```

2. Test repository access:
```bash
curl -I https://example.com/helm-charts/index.yaml
```

3. Run role to add repository:
```bash
dotfiles -t helm
```

### Extending OS Support
To add support for Arch Linux:

1. Create `roles/helm/tasks/Archlinux.yml`:
```yaml
---
- name: "Helm | Archlinux | Install Helm"
  community.general.pacman:
    name: helm
    state: present
  become: true
```

2. Update `uninstall.sh` with Arch support:
```bash
arch)
  if pacman -Q helm >/dev/null 2>&1; then
    __task "Removing helm via pacman"
    _cmd "sudo pacman -R --noconfirm helm"
    _task_done
  fi
  ;;
```

### Testing New Charts
```bash
# Add test repository
helm repo add test-repo https://example.com/charts

# Search for charts
helm search repo test-repo

# Dry run installation
helm install --dry-run test-release test-repo/chart-name

# Template validation
helm template test-repo/chart-name --values test-values.yaml
```

## Configuration Files and Locations

### Helm Configuration
- **Config Directory**: `~/.config/helm/`
- **Cache Directory**: `~/.cache/helm/`
- **Repository Cache**: `~/.cache/helm/repository/`
- **Plugin Directory**: `~/.local/share/helm/plugins/`

### System Locations
- **macOS**: `/opt/homebrew/bin/helm`
- **Ubuntu**: `/usr/bin/helm`
- **Fedora**: `/usr/bin/helm` or `/usr/local/bin/helm`
- **User Install**: `~/.local/bin/helm`

### Integration Points
- **k9s config**: `~/.config/k9s/plugins.yaml` (Helm values plugin)
- **Shell completion**: Loaded via shell configuration files
- **Context awareness**: PowerLevel10k and Starship prompt integration

## Performance and Optimization

### Chart Management
- Use `helm repo update` regularly but not excessively
- Cache frequently used charts locally
- Use `helm template` for testing instead of `--dry-run` when possible
- Implement chart version pinning for stability

### Repository Management
- Limit number of repositories to essential ones
- Use repository aliases for shorter commands
- Regular cleanup of unused repositories
- Monitor repository health and availability

## Advanced Usage Patterns

### Multi-Environment Management
```bash
# Environment-specific values
helm install app chart/ -f values-prod.yaml
helm install app chart/ -f values-staging.yaml

# Namespace management
helm install app chart/ --namespace production --create-namespace
```

### Chart Dependencies
```bash
# Update chart dependencies
helm dependency update <chart-path>

# Build dependency archive
helm dependency build <chart-path>
```

### Plugin Ecosystem
```bash
# Popular plugins
helm plugin install https://github.com/databus23/helm-diff
helm plugin install https://github.com/jkroepke/helm-secrets
helm plugin install https://github.com/chartmuseum/helm-push
```

This comprehensive guide covers all aspects of the Helm role within the dotfiles ecosystem, providing both operational knowledge and development guidance for working with Kubernetes package management.