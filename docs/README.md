# Dotfiles Documentation

## Forking & Customization

See [`../overrides/README.md`](../overrides/README.md) for the fork-friendly override system.

## Role Development Guide

See [example-role/](example-role/) for a complete template demonstrating the standard patterns used across all dotfiles roles.

### Quick Start

When creating a new role:

1. Copy the structure from `docs/example-role/`
2. Replace "example" and "role_name" with your actual role name
3. Implement OS-specific installation in the tasks files
4. Remove any patterns you don't need
5. Test across all supported platforms

### Key Patterns

#### OS Detection (Used by ~90% of roles)
```yaml
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_facts['distribution'] }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_facts['distribution'] }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_facts['distribution'] }}"
  ansible.builtin.include_tasks: "{{ ansible_facts['distribution'] }}.yml"
  when: distribution_config.stat.exists
```

#### Installation with Sudo Fallback
- Always check if already installed first
- Try system package manager if `can_install_packages` is true
- Provide alternative installation method for non-sudo environments
- Report clear status messages

#### Configuration Deployment
- Use `ansible.builtin.copy` for static files
- Use `ansible.builtin.template` for files with variables
- Always set appropriate permissions (0644 for configs, 0755 for executables)
- Consider using `backup: true` for existing configs

### Testing

```bash
# Syntax check
ansible-playbook main.yml --syntax-check

# Dry run specific role
dotfiles -t your-role --check

# Run with verbose output
dotfiles -t your-role -vvv
```

## Troubleshooting

### Completions Not Working in tmux

If tab completions work in your terminal but not in tmux, the issue is likely `zinit cdreplay` overwriting custom completions. The solution is to load custom completions AFTER zinit's replay:

```zsh
# In .zshrc:
autoload -Uz compinit && compinit
zinit cdreplay -q  # Let zinit replay its completions first

# Then load custom completions
for completion_file in $HOME/.config/zsh/*_completions.zsh; do
  source "$completion_file"
done
```

### Alternative: Using zinit for Custom Completions

Instead of manually sourcing completion files, you can let zinit manage them:

```zsh
# Load local completion files as snippets
zinit wait lucid for \
  id-as"dotfiles-completion" \
  multisrc"$HOME/.config/zsh/*_completions.zsh"
```

This approach leverages zinit's built-in completion management and turbo mode for better performance.

## Uninstalling Roles

Roles can include an `uninstall.sh` script to cleanly remove everything they installed:

### Creating an Uninstall Script

1. Add `uninstall.sh` to your role directory
2. Make it executable: `chmod +x uninstall.sh`
3. Use the dotfiles task functions for consistent output:

```bash
#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Remove packages
    if command -v brew >/dev/null 2>&1; then
      __task "Removing package via Homebrew"
      _cmd "brew uninstall package-name"
      _task_done
    fi
    
    # Clean up config files
    if [ -d "$HOME/.config/package" ]; then
      __task "Removing configuration files"
      _cmd "rm -rf $HOME/.config/package"
      _task_done
    fi
    ;;
    
  Linux)
    # Linux-specific uninstall
    ;;
esac
```

### Using the Uninstall Feature

```bash
# List roles that can be uninstalled (tab completion works)
dotfiles --uninstall <TAB>

# Uninstall a specific role
dotfiles --uninstall whalebrew
```

The uninstall process will:
1. Confirm before proceeding
2. Run the role's uninstall script
3. Remove the role from `group_vars/all.yml`
4. Delete the role directory
5. Show progress with the same beautiful output as installation

### Best Practices

1. **Keep roles self-contained** - Everything about a tool in one place
2. **Be idempotent** - Running twice should not change anything
3. **Handle errors gracefully** - Provide clear messages and alternatives
4. **Document non-obvious choices** - Add comments for complex logic
5. **Test on all platforms** - Ensure consistency across OS
