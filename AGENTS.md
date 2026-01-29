# AGENTS.md

> **Generated:** 2026-01-02 | **Commit:** 9adcaf33 | **Branch:** main

Ansible-based dotfiles for cross-platform dev environment (macOS, Ubuntu, Fedora, Arch). 75+ roles, 1Password secrets, idempotent.

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new tool | `roles/<tool>/` | Copy OS detection from existing role |
| Configure role | `group_vars/all.yml` | Add to `default_roles` list |
| Add secret | 1Password vault | Reference via `op://Vault/Item/field` |
| OS-specific logic | `roles/<role>/tasks/<OS>.yml` | MacOSX, Ubuntu, Fedora, Archlinux |
| Shell integration | `roles/zsh/files/zsh/` | 30+ function modules |
| Pre-flight checks | `pre_tasks/` | WSL, sudo, 1Password detection |

## COMMANDS

```bash
dotfiles                      # Install/update all
dotfiles -t neovim,git        # Specific roles only
dotfiles --check              # Dry run
dotfiles -vvv                 # Debug
dotfiles --list-tags          # List roles
dotfiles --uninstall <role>   # Remove (keep config)
dotfiles --delete <role>      # Remove completely
```

## STRUCTURE

```
.dotfiles/
├── main.yml              # Entry point - role orchestration
├── group_vars/all.yml    # Variables: default_roles, op secrets, packages
├── pre_tasks/            # Detection: WSL, sudo, 1Password
├── roles/                # 75+ self-contained tool configs
│   └── <role>/
│       ├── tasks/main.yml    # OS detection entry point
│       ├── tasks/<OS>.yml    # Platform-specific tasks
│       ├── files/            # Static configs (symlinked)
│       ├── templates/        # Jinja2 templates (.j2)
│       ├── defaults/         # Role variables
│       └── uninstall.sh      # Clean removal
└── bin/dotfiles          # Bootstrap script with spinners
```

## CONVENTIONS

### OS Detection Pattern (MANDATORY for every role)
```yaml
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_facts['distribution'] }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_facts['distribution'] }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_facts['distribution'] }}"
  ansible.builtin.include_tasks: "{{ ansible_facts['distribution'] }}.yml"
  when: distribution_config.stat.exists
```

### Task Naming
```yaml
- name: "{{ role_name }} | Install | Package dependencies"
- name: "{{ role_name }} | Configure | User settings"
- name: "{{ role_name }} | Symlink | Configuration files"
```

### YAML Standards
- 2-space indent
- FQCNs: `ansible.builtin.copy` not `copy`
- Booleans: `true`/`false` not `yes`/`no`
- `|` for literal, `>` for folded multi-line

### Config Deployment
- **Static files**: `ansible.builtin.copy` from `files/`
- **Dynamic files**: `ansible.builtin.template` with `.j2`
- **Prefer symlinks**: Maintains version control link

## 1PASSWORD INTEGRATION

```yaml
# Reading secrets - always check auth first
- name: "git | Get user email from 1Password"
  ansible.builtin.shell: |
    op --account my.1password.com read 'op://Dotfiles/Github/email'
  register: git_user_email_op
  when: op_installed and op_authenticated
  failed_when: false
```

**Vault references** in `group_vars/all.yml`:
```yaml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
  ssh:
    github:
      techdufus:
        - name: id_ed25519
          vault_path: "op://Personal/TechDufus SSH"
```

## ANTI-PATTERNS

| Forbidden | Why | Instead |
|-----------|-----|---------|
| Secrets in repo | Security | Use `op://` references |
| `yes`/`no` booleans | Deprecated | Use `true`/`false` |
| Short module names | Deprecated | Use FQCNs |
| Uninstall git/python | System deps | Never remove critical packages |
| Skip `failed_when: false` for optional ops | Breaks non-critical paths | Always handle gracefully |

## GOTCHAS

### ZSH Completions in tmux
Completions fail due to timing. Solution: Load AFTER zinit's cdreplay or use precmd hook.

### 1Password Vault Migration
Old: `~/.ansible-vault/vault.secret` (deprecated). New: All secrets via `op://`. Never store secrets in repo.

### Ubuntu 22+ pip
System-managed Python blocks direct pip. Use role-specific installation approach.

### Homebrew on Linux
Not auto-added to PATH. Manual shell config required.

### WSL Detection
Checks `/proc/version` for Microsoft. PowerShell ExecutionPolicy must be RemoteSigned.

### Dual GPU Cursor
Kitty custom cursor invisible on dual GPU. Disable in config.

## ERROR HANDLING

```yaml
# Non-critical operations
- name: "role | Optional feature"
  command: some-command
  failed_when: false
  changed_when: false

# Complex with fallback
- block:
    - name: "role | Try operation"
      command: risky-command
  rescue:
    - name: "role | Fallback operation"
      command: safe-command
```

## ADDING A NEW ROLE

1. `mkdir -p roles/<tool>/{tasks,files,defaults}`
2. Copy OS detection pattern to `tasks/main.yml`
3. Create `tasks/MacOSX.yml`, `tasks/Ubuntu.yml` etc.
4. Add configs to `files/`, templates to `templates/`
5. Create `uninstall.sh` following existing patterns
6. Add to `default_roles` in `group_vars/all.yml`
7. Test: `dotfiles -t <tool>` on each OS

## CI QUALITY GATES

| Check | Trigger |
|-------|---------|
| ansible-lint | roles/**/*.yml |
| shellcheck | **/*.sh |
| yamllint | **/*.yml, **/*.yaml |
| markdownlint | **/*.md |
| link-checker | docs/**/*.md |

Run locally:
```bash
ansible-playbook main.yml --syntax-check
dotfiles --check
```

## ROLE DEPENDENCIES

| Role | Depends On | Notes |
|------|------------|-------|
| npm | nvm | nvm must run first |
| git | ssh, 1password | For signing keys |
| Any with secrets | 1password | Must be authenticated |

## PACKAGE MANAGERS

| OS | Manager | Notes |
|----|---------|-------|
| macOS | brew, brew cask | Primary |
| Ubuntu | apt, nala (preferred) | Falls back to apt |
| Fedora | dnf | |
| Arch | pacman | |
| Cross-platform | pip, npm, go, cargo | Language-specific |
