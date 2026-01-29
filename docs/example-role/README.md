# Example Ansible Role Structure

This is a template/example role that demonstrates the standard pattern used across all dotfiles roles. Use this as a reference when creating new roles or updating existing ones.

## Directory Structure

```
example-role/
├── README.md           # This file
├── defaults/           
│   └── main.yml       # Default variables
├── files/             
│   └── config.yaml    # Static files to copy
├── handlers/          
│   └── main.yml       # Handlers for notifications
├── tasks/             
│   ├── main.yml       # Main entry point
│   ├── MacOSX.yml     # macOS-specific tasks
│   ├── Ubuntu.yml     # Ubuntu-specific tasks
│   ├── Fedora.yml     # Fedora-specific tasks
│   └── Archlinux.yml  # Arch Linux-specific tasks
└── templates/         
    └── config.j2      # Jinja2 templates

## Pattern Explanation

### OS Detection Pattern (tasks/main.yml)

Every role should start with OS detection to handle platform-specific installation:

```yaml
---
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_facts['distribution'] }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_facts['distribution'] }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_facts['distribution'] }}"
  ansible.builtin.include_tasks: "{{ ansible_facts['distribution'] }}.yml"
  when: distribution_config.stat.exists

# Common tasks that run on all platforms go here
```

### OS-Specific Installation Pattern

Each OS file should handle:
1. Checking if already installed
2. Installing via package manager (with sudo fallback)
3. Alternative installation methods
4. Clear error messages

See the individual OS task files for examples.

## Best Practices

1. **Always check if already installed** - Makes playbook idempotent
2. **Provide non-sudo fallbacks** - Support restricted environments
3. **Use clear task names** - Include role name for easy debugging
4. **Handle missing dependencies** - Provide actionable error messages
5. **Test across all platforms** - Ensure consistency

## Common Variables

- `role_name`: Set to the role's actual name (e.g., "git", "neovim")
- `ansible_facts['distribution']`: Automatically set by Ansible (MacOSX, Ubuntu, etc.)
- `ansible_facts['user_dir']`: User's home directory
- `can_install_packages`: Set by pre_tasks to indicate sudo availability

## Testing

Test your role with:
```bash
# Syntax check
ansible-playbook main.yml --syntax-check

# Dry run
dotfiles -t your-role --check

# Run with verbose output
dotfiles -t your-role -vvv
```