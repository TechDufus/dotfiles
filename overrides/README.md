# Overrides Directory

Fork-friendly customization system. Override any role without modifying upstream files.

## Quick Start

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create** your override: `mkdir -p overrides/roles/{role}/files`
4. **Customize** by copying and editing files
5. **Run** `dotfiles` - your overrides apply automatically

Your overrides stay local (gitignored), so you can pull upstream updates without conflicts.

## Override Levels

| Level | Path | Behavior |
|-------|------|----------|
| **Vars** | `overrides/roles/{role}/vars/main.yml` | Merged before role runs |
| **Files** | `overrides/roles/{role}/files/` | Role uses these files instead |
| **Tasks** | `overrides/roles/{role}/tasks/main.yml` | **Replaces role entirely** |

## How It Works

The wrapper checks for overrides before running each role:

1. **Vars override** - Loaded first, variables merge/override role defaults
2. **Files override** - Sets `_files_path` so role symlinks your files
3. **Task override** - Original role is **skipped**, your tasks run instead

## Examples

### Override Variables Only

```bash
mkdir -p overrides/roles/git/vars
cat > overrides/roles/git/vars/main.yml << 'EOF'
git_user_name: "My Fork Name"
git_user_email: "fork@example.com"
EOF
```

### Override Config Files Only

```bash
mkdir -p overrides/roles/neovim/files
cp -r roles/neovim/files/* overrides/roles/neovim/files/
# Edit files in overrides/roles/neovim/files/ as needed
```

### Replace Role Entirely

```bash
mkdir -p overrides/roles/custom-tool/tasks
cat > overrides/roles/custom-tool/tasks/main.yml << 'EOF'
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

### Add New Custom Roles

Create roles that don't exist upstream - perfect for personal tools or workflows:

```bash
mkdir -p overrides/roles/my-tool/tasks
cat > overrides/roles/my-tool/tasks/main.yml << 'EOF'
---
- name: "my-tool | Install my custom tool"
  ansible.builtin.package:
    name: my-tool
    state: present

- name: "my-tool | Deploy config"
  ansible.builtin.copy:
    src: "{{ _files_path }}/config"
    dest: "{{ ansible_user_dir }}/.config/my-tool/config"
EOF

# Add config files
mkdir -p overrides/roles/my-tool/files
echo "my config" > overrides/roles/my-tool/files/config
```

Run with the `-t` flag:
```bash
dotfiles -t my-tool
```

Custom roles are only run when explicitly tagged - they won't run during a full `dotfiles` execution unless added to `default_roles`.

## Commonly Overridden Files

| What to Customize | Override Path | Key Settings |
|-------------------|---------------|--------------|
| Git identity | `overrides/roles/git/vars/main.yml` | `git_user_name`, `git_user_email` |
| Git config | `overrides/roles/git/files/.gitconfig` | Aliases, merge strategy |
| Shell aliases | `overrides/roles/zsh/files/.zshrc` | Personal shortcuts |
| Terminal colors | `overrides/roles/ghostty/files/config` | Theme, font, opacity |
| Editor config | `overrides/roles/neovim/files/` | Plugins, keybindings |
| Tmux config | `overrides/roles/tmux/files/tmux/` | Prefix key, status bar |

## Partial File Overrides

**Important:** When overriding files, you must provide ALL files the role expects.

The `_files_path` variable points to ONE directory - either your override OR the role's files, not both.

**Example:** If `roles/git/files/` contains:
- `.gitconfig`
- `global.commit.template`

And you only put `.gitconfig` in `overrides/roles/git/files/`, the role will fail looking for `global.commit.template`.

**Solution:** Copy everything, then modify what you need:
```bash
cp -r roles/git/files/* overrides/roles/git/files/
# Now edit only the files you want to change
```

## Important Notes

- **Task overrides skip the original role** - your tasks have full control
- **Use `_files_path`** in override tasks, not `role_path` (magic variable unavailable)
- **This directory is gitignored** - your customizations stay local
- **Pull upstream cleanly** - no merge conflicts with your overrides

## Variable Scope Behavior

**Important:** Variables loaded from `overrides/roles/{role}/vars/main.yml` persist for the entire playbook run.

This is standard Ansible behavior - `include_vars` loads into play scope. After a role runs, its override variables remain set for all subsequent roles.

### Best Practices

1. **Use role-prefixed variable names** - `git_user_email` not `user_email`
2. **Check role defaults first** - `roles/{role}/defaults/main.yml` shows expected names
3. **Avoid generic names** - `config`, `version`, `name` could collide with other roles
4. **Override only what you need** - fewer variables = fewer collision chances

This behavior matches how `group_vars/` works in Ansible - it's not a bug, just something to be aware of.

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
ok: [localhost] => {"ansible_facts": {"_files_path": "/path/to/overrides/roles/git/files"}}
```

If it shows `roles/git/files` instead, your override wasn't detected.

### Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Override not applied | Wrong directory structure | Check path: `overrides/roles/{role}/files/` not `override/` |
| File not found | Missing file in override | Copy ALL files from `roles/{role}/files/` |
| Variables not merged | Wrong vars path | Use `overrides/roles/{role}/vars/main.yml` |

## Migrating from Modified Roles

If you've already forked and modified role files directly:

1. **Identify changes** - `git diff upstream/main -- roles/`
2. **Create override structure** - `mkdir -p overrides/roles/{role}/files`
3. **Copy your modified files** - Move from `roles/{role}/files/` to `overrides/roles/{role}/files/`
4. **Reset role to upstream** - `git checkout upstream/main -- roles/{role}/files/`
5. **Test** - Run `dotfiles -t {role}` to verify

Your modifications now live in `overrides/`, cleanly separated from upstream.

## Bootstrap Customization

When you fork this repo, the bootstrap script needs to know to clone YOUR fork, not the original.

### Quick Setup

1. Edit `bin/dotfiles` in your fork and change:
   ```bash
   DOTFILES_GITHUB_USER="YourGitHubUsername"
   ```

2. Commit and push to your fork

3. Run your fork's bootstrap:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/YourGitHubUsername/dotfiles/main/bin/dotfiles)"
   ```

### Config File Override

After initial clone, you can also use a config file for subsequent runs:

```bash
cp overrides/config/dotfiles.conf.example overrides/config/dotfiles.conf
# Edit dotfiles.conf with your settings
```

This is useful if you want to keep `bin/dotfiles` unmodified for easier upstream merges.

### Available Settings

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_GITHUB_USER` | `TechDufus` | GitHub username for repo URL |
| `DOTFILES_REPO_NAME` | `dotfiles` | Repository name (if renamed) |
