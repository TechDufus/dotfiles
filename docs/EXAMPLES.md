# 📋 Configuration Examples

This guide shows different configuration setups for various developer types and use cases.

## 🎯 Quick Configuration Templates

### 🧑‍💻 Minimal Developer Setup (10 roles)

Perfect for basic development work or getting started:

```yaml
default_roles:
  - system        # Core system tools
  - git          # Version control
  - zsh          # Modern shell
  - neovim       # Text editor
  - tmux         # Terminal multiplexer
  - fzf          # Fuzzy finder
  - bat          # Better cat
  - lsd          # Better ls
  - starship     # Shell prompt
  - fonts        # Developer fonts

git_user_name: "Your Name"
```

### 🌐 Web Developer Setup (20 roles)

For frontend/backend web development:

```yaml
default_roles:
  - system
  - git
  - zsh
  - neovim
  - tmux
  - fzf
  - bat
  - lsd
  - starship
  - fonts
  - nvm          # Node version manager
  - npm          # Node package manager
  - python       # Python development
  - go           # Go language
  - docker       # Containerization
  - gh           # GitHub CLI
  - lazygit      # Git UI
  - tldr         # Command help
  - neofetch     # System info
  - obsidian     # Note taking

git_user_name: "Your Name"

# Node.js configuration
nvm:
  default_node_version: "18"  # LTS version

# Python packages
python:
  packages:
    - pip
    - virtualenv
    - requests
```

### ☁️ DevOps/Cloud Engineer Setup (30 roles)

For infrastructure and cloud work:

```yaml
default_roles:
  - system
  - git
  - zsh
  - neovim
  - tmux
  - fzf
  - bat
  - lsd
  - starship
  - fonts
  - docker
  - podman       # Alternative to Docker
  - terraform    # Infrastructure as Code
  - terragrunt   # Terraform wrapper
  - helm         # Kubernetes package manager
  - k8s          # Kubernetes tools
  - k9s          # Kubernetes UI
  - gh
  - lazygit
  - python
  - go
  - pwsh         # PowerShell
  - ssh
  - tldr
  - btop         # System monitor
  - ncdu         # Disk usage
  - taskfile     # Task runner
  - whalebrew    # Package manager
  - tmate        # Terminal sharing
  - slides       # Terminal presentations

git_user_name: "Your Name"

# Kubernetes configuration
k8s:
  repo:
    version: "v1.28"  # Latest stable

# Helm repositories
helm:
  repos:
    - name: traefik
      url: https://helm.traefik.io/traefik
    - name: prometheus
      url: https://prometheus-community.github.io/helm-charts
    - name: grafana
      url: https://grafana.github.io/helm-charts

# Go packages for DevOps tools
go:
  packages:
    - package: github.com/go-task/task/v3/cmd/task@latest
      cmd: task
    - package: github.com/stern/stern@latest
      cmd: stern
    - package: github.com/derailed/k9s@latest
      cmd: k9s
```

### 🎮 Streamer/Content Creator Setup (Full setup)

Everything enabled for live streaming and content creation:

```yaml
default_roles:
  # Core system
  - system
  - fonts
  
  # Development tools
  - git
  - gh
  - lazygit
  - neovim
  
  # Terminal environment
  - zsh
  - tmux
  - starship
  - kitty        # Terminal emulator
  - warp         # Modern terminal
  
  # File management
  - fzf
  - bat
  - lsd
  - ncdu
  - zoxide       # Smart cd
  
  # System monitoring
  - btop
  - neofetch
  - nerdfetch
  - asciiquarium # Fun terminal
  
  # Development languages
  - python
  - go
  - nvm
  - npm
  - lua
  - rust
  - ruby
  
  # DevOps tools
  - docker
  - podman
  - terraform
  - terragrunt
  - helm
  - k8s
  - k9s
  
  # Productivity
  - obsidian     # Note taking
  - raycast      # macOS launcher
  - hammerspoon  # macOS automation
  - taskfile
  - tldr
  - slides
  
  # Communication
  - discord
  - spotify
  
  # File systems
  - ssh
  - sshfs
  - tmate
  
  # macOS specific
  - aldente      # Battery management
  
  # Utilities
  - pwsh
  - whalebrew
  - flatpak      # Linux packages
  
  # Cloud CLIs
  - aws          # Amazon Web Services
  - azure        # Microsoft Azure
  
  # Container alternatives
  - orbstack     # Docker Desktop alternative
  
  # Additional terminal emulators
  - alacritty    # GPU-accelerated terminal
  - ghostty      # Fast terminal emulator
  
  # Development tools
  - just         # Command runner
  - goreleaser   # Go release automation
  
  # Kubernetes ecosystem
  - kind         # Kubernetes in Docker
  - kwctl        # Policy engine
  
  # Network tools
  - wireguard    # VPN solution
  
  # Browser tools
  - brave        # Privacy browser

git_user_name: "TechDufus"

# Full Helm setup
helm:
  repos:
    - name: traefik
      url: https://helm.traefik.io/traefik
    - name: prometheus
      url: https://prometheus-community.github.io/helm-charts
    - name: grafana
      url: https://grafana.github.io/helm-charts
    - name: bitnami
      url: https://charts.bitnami.com/bitnami

# Go tools for development
go:
  packages:
    - package: github.com/go-task/task/v3/cmd/task@latest
      cmd: task
    - package: github.com/gcla/termshark/v2/cmd/termshark@v2.4.0
      cmd: termshark
    - package: github.com/stern/stern@latest
      cmd: stern
```

## 🔐 1Password Configuration Examples

### Basic 1Password Setup

```yaml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
    allowed_signers: "op://Personal/GitHub SSH/allowed_signers"
  ssh:
    github:
      personal:
        - name: id_ed25519
          vault_path: "op://Personal/GitHub SSH"
```

### Multi-Account 1Password Setup

```yaml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
  ssh:
    github:
      personal:
        - name: personal_key
          vault_path: "op://Personal/Personal SSH"
      work:
        - name: work_key
          vault_path: "op://Work/Work SSH"
        - name: aws_key
          vault_path: "op://Work/AWS SSH"
```

## 🎛️ Role-Specific Configurations

### Python Development

```yaml
python:
  packages:
    - pip
    - virtualenv
    - pipenv
    - poetry
    - black       # Code formatter
    - flake8      # Linter
    - pytest      # Testing
    - requests    # HTTP library
    - pandas      # Data analysis
    - fastapi     # Web framework
```

### Go Development

```yaml
go:
  packages:
    - package: github.com/go-task/task/v3/cmd/task@latest
      cmd: task
    - package: golang.org/x/tools/cmd/goimports@latest
      cmd: goimports
    - package: github.com/golangci/golangci-lint/cmd/golangci-lint@latest
      cmd: golangci-lint
    - package: github.com/cosmtrek/air@latest
      cmd: air
```

### Kubernetes Setup

```yaml
k8s:
  repo:
    version: "v1.28"

helm:
  repos:
    - name: ingress-nginx
      url: https://kubernetes.github.io/ingress-nginx
    - name: cert-manager
      url: https://charts.jetstack.io
    - name: prometheus
      url: https://prometheus-community.github.io/helm-charts
```

## 🚫 Common Mistakes to Avoid

### ❌ Don't do this:

```yaml
# Missing git_user_name (required)
default_roles:
  - git

# Invalid role name
default_roles:
  - non-existent-role

# Malformed 1Password path
op:
  git:
    user:
      email: "not-a-valid-path"
```

### ✅ Do this instead:

```yaml
# Always include git_user_name
git_user_name: "Your Name"

default_roles:
  - git  # Valid role name

# Proper 1Password vault reference
op:
  git:
    user:
      email: "op://VaultName/ItemName/field"
```

## 🧪 Testing Your Configuration

Before running the full setup, test your configuration:

```bash
# Validate syntax
ansible-playbook ~/.dotfiles/main.yml --syntax-check

# Dry run (see what would change)
dotfiles --check

# Run specific roles only
dotfiles -t git,zsh

# Run with verbosity to debug issues
dotfiles -vvv
```

## 📁 Directory Structure After Installation

```
~/.dotfiles/
├── group_vars/
│   └── all.yml          # Your configuration
├── roles/               # Individual tool configurations
├── bin/
│   └── dotfiles        # Main command
└── main.yml            # Ansible playbook
```

## 🔄 Updating Your Configuration

```bash
# Edit your configuration
nvim ~/.dotfiles/group_vars/all.yml

# Apply changes
dotfiles

# Add a new role
echo "  - new-role" >> ~/.dotfiles/group_vars/all.yml
dotfiles -t new-role
```

## 🆘 Need Help?

- 📖 **Full documentation**: [README.md](../README.md)
- 🚀 **Quick start**: [QUICKSTART.md](QUICKSTART.md)
- 🔧 **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- 💬 **Community**: [Discord](https://discord.gg/5M4hjfyRBj)

---

**Want to contribute an example?** [Open a pull request](https://github.com/TechDufus/dotfiles/pulls) with your configuration!