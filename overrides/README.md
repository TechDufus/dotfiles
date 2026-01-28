# Overrides Directory

Fork-friendly customization system. Override any role without modifying upstream files.

## Quick Start

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create** your override: `mkdir -p overrides/{role}/files`
4. **Customize** by copying and editing files
5. **Run** `dotfiles` - your overrides apply automatically

Your overrides stay local (gitignored), so you can pull upstream updates without conflicts.

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

## Commonly Overridden Files

| What to Customize | Override Path | Key Settings |
|-------------------|---------------|--------------|
| Git identity | `overrides/git/vars/main.yml` | `git_user_name`, `git_user_email` |
| Git config | `overrides/git/files/.gitconfig` | Aliases, merge strategy |
| Shell aliases | `overrides/zsh/files/.zshrc` | Personal shortcuts |
| Terminal colors | `overrides/ghostty/files/config` | Theme, font, opacity |
| Editor config | `overrides/neovim/files/` | Plugins, keybindings |
| Tmux config | `overrides/tmux/files/tmux/` | Prefix key, status bar |

## Partial File Overrides

**Important:** When overriding files, you must provide ALL files the role expects.

The `_files_path` variable points to ONE directory - either your override OR the role's files, not both.

**Example:** If `roles/git/files/` contains:
- `.gitconfig`
- `global.commit.template`

And you only put `.gitconfig` in `overrides/git/files/`, the role will fail looking for `global.commit.template`.

**Solution:** Copy everything, then modify what you need:
```bash
cp -r roles/git/files/* overrides/git/files/
# Now edit only the files you want to change
```

## Important Notes

- **Task overrides skip the original role** - your tasks have full control
- **Use `_files_path`** in override tasks, not `role_path` (magic variable unavailable)
- **This directory is gitignored** - your customizations stay local
- **Pull upstream cleanly** - no merge conflicts with your overrides

## Debugging Overrides

### Verify Override Detection

Run with verbose output to see which overrides are detected:
```bash
dotfiles -t git -vvv 2>&1 | grep -E "(override|_files_path)"
```

### Check _files_path Value

In your playbook output, look for:
```
TASK [run_role_with_overrides : Set _files_path]
ok: [localhost] => {"ansible_facts": {"_files_path": "/path/to/overrides/git/files"}}
```

If it shows `roles/git/files` instead, your override wasn't detected.

### Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Override not applied | Wrong directory structure | Check path: `overrides/{role}/files/` not `override/` |
| File not found | Missing file in override | Copy ALL files from `roles/{role}/files/` |
| Variables not merged | Wrong vars path | Use `overrides/{role}/vars/main.yml` |

## Migrating from Modified Roles

If you've already forked and modified role files directly:

1. **Identify changes** - `git diff upstream/main -- roles/`
2. **Create override structure** - `mkdir -p overrides/{role}/files`
3. **Copy your modified files** - Move from `roles/{role}/files/` to `overrides/{role}/files/`
4. **Reset role to upstream** - `git checkout upstream/main -- roles/{role}/files/`
5. **Test** - Run `dotfiles -t {role}` to verify

Your modifications now live in `overrides/`, cleanly separated from upstream.
