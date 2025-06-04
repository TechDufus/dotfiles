# Sudo Detection Usage Guide

This guide explains how to use the sudo detection system in your Ansible roles.

## Available Facts

After the sudo detection pre-task runs, the following facts are available:

- `has_sudo`: Boolean indicating if any sudo/privilege escalation method works
- `sudo_method`: The working method (`'sudo'`, `'doas'`, `'pkexec'`, or `'none'`)
- `sudo_requires_password`: Boolean indicating if password is required
- `can_install_packages`: Boolean indicating if package installation is possible
- `detected_package_manager`: String with the package manager (`'brew'`, `'apt'`, `'pacman'`, or `'none'`)
- `privilege_escalation_available`: Boolean for overall privilege status

## Usage Examples

### 1. Skip Tasks Without Sudo

```yaml
- name: Install system packages
  ansible.builtin.apt:
    name: package-name
    state: present
  become: true
  when: can_install_packages | default(false)
```

### 2. Provide Alternative for Non-Sudo Users

```yaml
- name: Install to system location (with sudo)
  ansible.builtin.copy:
    src: myfile
    dest: /usr/local/bin/myfile
    mode: '0755'
  become: true
  when: has_sudo | default(false)

- name: Install to user location (without sudo)
  ansible.builtin.copy:
    src: myfile
    dest: "{{ ansible_env.HOME }}/.local/bin/myfile"
    mode: '0755'
  when: not (has_sudo | default(false))
```

### 3. Warn When Skipping

```yaml
- name: Install required packages
  ansible.builtin.apt:
    name: 
      - package1
      - package2
    state: present
  become: true
  when: can_install_packages | default(false)
  register: install_result
  failed_when: false

- name: Warn if packages not installed
  ansible.builtin.debug:
    msg: "⚠️  Skipping package installation - sudo access not available"
  when: not (can_install_packages | default(false))
```

### 4. Cross-Platform Package Installation

```yaml
- name: Install package (macOS)
  community.general.homebrew:
    name: package-name
    state: present
  when: 
    - ansible_distribution == "MacOSX"
    - detected_package_manager == "brew"

- name: Install package (Ubuntu/Debian)
  ansible.builtin.apt:
    name: package-name
    state: present
  become: true
  when: 
    - ansible_distribution in ["Ubuntu", "Debian"]
    - can_install_packages | default(false)

- name: Install package (Arch)
  community.general.pacman:
    name: package-name
    state: present
  become: true
  when:
    - ansible_distribution == "Archlinux"
    - can_install_packages | default(false)
```

### 5. Role-Level Conditions

Each role should handle its own sudo requirements internally. Roles that absolutely require sudo (like Docker) should check for `has_sudo` at the beginning and skip gracefully with clear messages if it's not available.

For roles that can partially function without sudo, add conditions to individual tasks that require elevated privileges.

## Best Practices

1. **Always use `| default(false)`** with boolean facts to handle undefined variables
2. **Provide user-friendly warnings** when skipping important tasks
3. **Consider alternative locations** for file installations (e.g., `~/.local/bin` instead of `/usr/local/bin`)
4. **Test your roles** with `--check` mode to ensure they handle missing sudo gracefully
5. **Use `failed_when: false`** or `ignore_errors: true` for tasks that might fail without sudo

## Testing

Test your role with different sudo scenarios:

```bash
# Normal run
dotfiles -t your-role

# Check mode
dotfiles -t your-role --check

# Verbose to see skip messages
dotfiles -t your-role -vvv
```