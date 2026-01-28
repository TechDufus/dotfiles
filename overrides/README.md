# Overrides Directory

Fork-friendly customization system. Override any role without modifying upstream files.

## Override Levels

| Level | Path | Behavior |
|-------|------|----------|
| **Vars** | `overrides/{role}/vars/main.yml` | Merged before role runs |
| **Files** | `overrides/{role}/files/` | Role uses these files instead |
| **Tasks** | `overrides/{role}/tasks/main.yml` | **Replaces role entirely** |

## How It Works

The wrapper checks for overrides before running each role:

1. **Vars override** - Loaded first, variables merge/override role defaults
2. **Files override** - Sets `_files_path` so role symlinks your files
3. **Task override** - Original role is **skipped**, your tasks run instead

## Examples

### Override Variables Only

```bash
mkdir -p overrides/git/vars
cat > overrides/git/vars/main.yml << 'EOF'
git_user_name: "My Fork Name"
git_user_email: "fork@example.com"
EOF
```

### Override Config Files Only

```bash
mkdir -p overrides/neovim/files
cp -r roles/neovim/files/* overrides/neovim/files/
# Edit files in overrides/neovim/files/ as needed
```

### Replace Role Entirely

```bash
mkdir -p overrides/custom-tool/tasks
cat > overrides/custom-tool/tasks/main.yml << 'EOF'
---
- name: "custom-tool | My custom implementation"
  ansible.builtin.debug:
    msg: "Running custom tasks instead of original role"

# Use _files_path for file operations (role_path unavailable in overrides)
- name: "custom-tool | Symlink config"
  ansible.builtin.file:
    src: "{{ _files_path }}/config"
    dest: "{{ ansible_user_dir }}/.config/custom-tool"
    state: link
EOF
```

## Important Notes

- **Task overrides skip the original role** - your tasks have full control
- **Use `_files_path`** in override tasks, not `role_path` (magic variable unavailable)
- **This directory is gitignored** - your customizations stay local
- **Pull upstream cleanly** - no merge conflicts with your overrides
