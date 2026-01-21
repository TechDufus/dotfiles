# Dotfiles

Ansible-based cross-platform development environment setup (macOS, Ubuntu, Fedora, Arch). 72 roles, 1Password integration, visual feedback.

## Commands

| Command | Purpose |
|---------|---------|
| `dotfiles` | Install/update all roles |
| `dotfiles -t role1,role2` | Install specific roles |
| `dotfiles --check` | Dry run (no changes) |
| `dotfiles -vvv` | Debug verbose output |
| `dotfiles --list-tags` | List available roles |
| `dotfiles --uninstall <role>` | Remove role (keeps config) |
| `dotfiles --delete <role>` | Remove role and config |

## Where to Look

| Task | Location |
|------|----------|
| Add new tool | `roles/<tool>/tasks/main.yml` |
| OS-specific logic | `roles/<tool>/tasks/<Distribution>.yml` |
| Tool configuration | `roles/<tool>/files/` |
| Dynamic config | `roles/<tool>/templates/*.j2` |
| Secret references | `group_vars/all.yml` (use `op://` URLs) |
| Default role list | `group_vars/all.yml` → `default_roles` |
| Bootstrap script | `bin/dotfiles` |
| Pre-run detection | `pre_tasks/` |

## Architecture

### OS Detection Pattern (every role uses this)

```yaml
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_distribution }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_distribution }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_distribution }}"
  ansible.builtin.include_tasks: "{{ ansible_distribution }}.yml"
  when: distribution_config.stat.exists
```

### 1Password Integration

```yaml
# Check availability before use
- name: "role | Get secret from 1Password"
  ansible.builtin.shell: |
    op read 'op://Vault/Item/field'
  register: secret_result
  when: op_installed and op_authenticated
  failed_when: false
  no_log: true
```

### Role Structure

```
roles/<name>/
├── tasks/
│   ├── main.yml           # Entry point with OS detection
│   └── <Distribution>.yml # OS-specific tasks
├── files/                 # Static configs (symlinked to ~/)
├── templates/             # Jinja2 templates (.j2)
├── defaults/              # Default variables
└── uninstall.sh          # Cleanup script
```

## Code Style

- **Task names:** `"{{ role_name }} | Action | Detail"`
- **Modules:** Fully qualified (`ansible.builtin.copy`)
- **Booleans:** `true`/`false` (not `yes`/`no`)
- **Variables:** `snake_case` with role prefix (`git_user_name`)
- **Idempotent:** All tasks safe to re-run

## Critical Gotchas

- **1Password:** Must be authenticated (`op signin`) for roles using secrets
- **ZSH completions:** Load after `zinit cdreplay` - timing matters for tmux
- **Never uninstall:** git, python, or system packages (protected)
- **WSL:** Detected via `/proc/version` - special PowerShell handling
- **Symlinks preferred:** Link to role files for version control

## CI Checks

All PRs run: ansible-lint, shellcheck, yaml-lint, markdown-lint. Run locally:

```bash
ansible-playbook main.yml --syntax-check
```

---

Context-specific guidance lives in nested CLAUDE.md files in `roles/` directories.
These load automatically when working in those directories.
