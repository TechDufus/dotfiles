# CLAUDE.md - Starship Role

This file provides guidance to Claude Code when working with the Starship shell prompt role in this dotfiles repository.

## Role Overview

The **Starship** role installs and configures the Starship cross-shell prompt, providing a fast, customizable, and minimal shell prompt that works across bash, zsh, fish, and PowerShell. Starship is written in Rust and designed for speed, customization, and modern development workflows.

**Key Features:**
- Cross-platform support (macOS, Ubuntu, Fedora)
- Comprehensive git status integration
- Language-specific prompts for 40+ programming languages
- Kubernetes context display
- Custom prompt segments
- Performance-optimized with lazy loading
- Catppuccin theme integration

## Architecture and Installation

### Installation Strategy by Platform

**macOS**: Uses Homebrew for clean package management
```yaml
- name: "Starship | MacOSX | Install Starship"
  community.general.homebrew:
    name: starship
    state: present
```

**Ubuntu**: Uses official installer script with fallback detection
```yaml
- name: "Starship | Ubuntu | Install Starship"
  ansible.builtin.shell:
    cmd: curl -fsSL https://starship.rs/install.sh | sudo sh -s -- --force
  args:
    creates: /usr/local/bin/starship
```

**Fedora**: Multi-tier installation approach
1. Try system package via DNF first
2. Fall back to official installer script
3. User directory installation when sudo unavailable

### Configuration Deployment

The role copies a comprehensive `starship.toml` configuration to `~/.config/starship.toml`:
```yaml
- name: "starship | Copy custom starship config"
  ansible.builtin.copy:
    dest: "{{ ansible_user_dir }}/.config/starship.toml"
    src: "starship.toml"
    mode: "0644"
```

## Starship Configuration Structure

### Global Format Configuration

The configuration uses a comprehensive format string that defines the order and appearance of all prompt segments:

```toml
format = """
$username\
$hostname\
$localip\
$shlvl\
$singularity\
$kubernetes\
$vcsh\
$fossil_branch\
$fossil_metrics\
${custom.giturl}\
$git_branch\
$git_commit\
$git_state\
$git_metrics\
$git_status\
$hg_branch\
$pijul_channel\
$docker_context\
${custom.docker}\
$package\
[... language-specific modules ...]\
$memory_usage\
$aws\
$gcloud\
$openstack\
$azure\
$nats\
$direnv\
$env_var\
$crystal\
$sudo\
$cmd_duration\
$line_break\
$jobs\
$battery\
$time\
$status\
$os\
$container\
$shell\
$directory\
$character"""
```

### Key Configuration Sections

#### 1. Color Palette (Catppuccin Integration)
The configuration includes all four Catppuccin variants:
- `catppuccin_latte` (light theme) - Default
- `catppuccin_frappe` (dark theme)
- `catppuccin_macchiato` (dark theme)
- `catppuccin_mocha` (dark theme)

#### 2. Character Prompt
```toml
[character]
success_symbol = "[[󰄛](green) ❯](peach)"
error_symbol = "[[󰄛](red) ❯](peach)"
vimcmd_symbol = "[󰄛 ❮](subtext1)" # For zsh-vi-mode integration
```

#### 3. Directory Display
```toml
[directory]
read_only = " 󰌾"
truncation_length = 8
truncation_symbol = "…/"
style = "bold lavender"
```

## Git Integration and Status Display

### Git Branch Configuration
```toml
[git_branch]
symbol = " "
style = "bold mauve"
format = '[$symbol$branch]($style) '
```

### Advanced Git Status
The configuration provides comprehensive git status information:
```toml
[git_status]
disabled = false
format = '[\($all_status$ahead_behind\)]($style) '
style = "bold green"
conflicted = "🏳"
up_to_date = " "
untracked = " "
ahead = "⇡${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
behind = "⇣${count}"
stashed = " "
modified = " "
staged = '[++\($count\)](green)'
renamed = "襁 "
deleted = " "
```

### Git Metrics
```toml
[git_metrics]
disabled = false  # Shows +X/-Y for added/deleted lines
```

## Custom Segments and Formatters

### 1. Git Remote URL Detection
Custom segment that detects and displays appropriate icons for different git hosting services:

```toml
[custom.giturl]
description = "Display symbol for remote Git server"
command = """
GIT_REMOTE=$(command git ls-remote --get-url 2> /dev/null)
if [[ "$GIT_REMOTE" =~ "github" ]]; then
    GIT_REMOTE_SYMBOL=" "
elif [[ "$GIT_REMOTE" =~ "gitlab" ]]; then
    GIT_REMOTE_SYMBOL=" "
elif [[ "$GIT_REMOTE" =~ "bitbucket" ]]; then
    GIT_REMOTE_SYMBOL=" "
elif [[ "$GIT_REMOTE" =~ "git" ]]; then
    GIT_REMOTE_SYMBOL="󰊢 "
else
    GIT_REMOTE_SYMBOL=" "
fi
echo "$GIT_REMOTE_SYMBOL"
"""
when = 'git rev-parse --is-inside-work-tree 2> /dev/null'
format = "$output "
```

### 2. Docker Context Detection
Custom segment that shows Docker icon when Docker files are present:

```toml
[custom.docker]
description = "Shows the docker symbol if the current directory has Dockerfile or docker-compose.yml files"
command = "echo '  '"
files = ["Dockerfile", "docker-compose.yml", "docker-compose.yaml"]
when = """ command -v docker &> /dev/null; exit (echo $?); """
style = "bold blue"
```

## Performance Tuning and Command Timeout Settings

### Performance Optimizations

1. **Lazy Loading**: Starship only executes modules when their conditions are met
2. **Conditional Execution**: Uses `when` conditions to prevent unnecessary command execution
3. **Caching**: Git status and other expensive operations are cached between prompt renders
4. **Selective Disabling**: Non-essential modules are disabled to improve performance

### Disabled Modules for Performance
```toml
[gcloud]
disabled = true  # Cloud provider modules can be slow

[nodejs]
disabled = true  # Language modules disabled when not commonly used

[memory_usage]
disabled = true  # Resource-intensive module disabled by default
threshold = 1    # Only show when memory usage > 1%

[time]
disabled = true  # Clock display disabled for cleaner prompt
```

### Command Timeout Configuration
Starship automatically handles command timeouts, but for custom segments:
- Git operations timeout after 5 seconds by default
- Custom command segments should include error handling
- Use `failed_when: false` pattern for non-critical information

## Shell Integration

### ZSH Integration
Starship integrates seamlessly with ZSH and zsh-vi-mode:
```toml
[character]
vimcmd_symbol = "[󰄛 ❮](subtext1)" # Special symbol for vi command mode
```

### Shell Detection Display
```toml
[shell]
disabled = false
bash_indicator = " "
zsh_indicator = " "
powershell_indicator = "󰨊 "
fish_indicator = '󰈺 '
style = 'sky'
```

### Hostname and SSH Context
```toml
[hostname]
ssh_only = false
ssh_symbol = " "
format = '[$ssh_symbol(bold blue)[$hostname](bold blue)]($style) '
disabled = false
```

## Kubernetes Integration

The configuration includes Kubernetes context display:
```toml
[kubernetes]
format = '[$symbol$context([\(](peach)$namespace[\)](peach))]($style) '
disabled = false
```

This shows:
- Kubernetes cluster context
- Current namespace in parentheses
- Distinctive peach-colored brackets

## Language-Specific Prompts

The configuration includes 40+ programming language modules with custom symbols:

### Popular Languages
```toml
[python]
symbol = " "

[nodejs]
disabled = true  # Disabled for performance
symbol = " "

[rust]
symbol = "󱘗 "

[golang]
format = "[$version]($style) "

[java]
symbol = " "
```

### Language Detection
- Automatic detection based on file presence
- Version display for active environments
- Package manager integration (package.json, Cargo.toml, etc.)

## OS and Platform Display

### OS Symbol Configuration
Comprehensive OS detection with appropriate icons:
```toml
[os]
style = "peach"
disabled = false

[os.symbols]
Arch = " "
Ubuntu = " "
Fedora = " "
Macos = " "
Windows = "󰍲 "
# ... many more OS variants
```

## Theme and Color Customization

### Catppuccin Color Scheme
The configuration uses Catppuccin Latte as the default palette:
```toml
palette = "catppuccin_latte"
```

### Custom Color Applications
- **Directory**: `bold lavender`
- **Git Branch**: `bold mauve`
- **Git Status**: `bold green`
- **OS**: `peach`
- **Shell**: `sky`
- **Character**: Uses `green`/`red` for success/error, `peach` for arrow

### Switching Themes
To change themes, modify the palette line:
```toml
# Light theme (default)
palette = "catppuccin_latte"

# Dark themes
palette = "catppuccin_mocha"    # Most popular dark variant
palette = "catppuccin_macchiato"
palette = "catppuccin_frappe"
```

## Common Customization Points

### 1. Directory Truncation
```toml
[directory]
truncation_length = 8    # Show last 8 directories
truncation_symbol = "…/" # Symbol when path is truncated
```

### 2. Git Status Symbols
Customize git status indicators:
```toml
[git_status]
untracked = " "    # Files not tracked by git
modified = " "     # Modified files
staged = '[++\($count\)](green)'  # Staged changes
stashed = " "      # Stashed changes
ahead = "⇡${count}"     # Commits ahead of remote
behind = "⇣${count}"    # Commits behind remote
```

### 3. Performance Tuning
Enable/disable modules based on usage:
```toml
[memory_usage]
disabled = true    # Disable for better performance
threshold = 70     # Only show when usage > 70%

[cmd_duration]
min_time = 2000    # Only show for commands taking > 2s
```

### 4. Custom Segments
Add new custom segments following the pattern:
```toml
[custom.my_segment]
description = "Custom functionality"
command = "echo 'custom_output'"
when = "test -f some_condition_file"
format = "$output "
style = "bold blue"
```

## Troubleshooting Tips

### 1. Installation Issues

**Starship not found after installation:**
- Check PATH includes `/usr/local/bin` (system install) or `~/.local/bin` (user install)
- Verify installation with `which starship`
- Restart shell session after installation

**Permission errors during installation:**
- Ubuntu/Fedora: Script requires sudo for system-wide installation
- Alternative: Use user directory installation (Fedora role supports this)
- Check if curl is available for downloading installer

### 2. Configuration Problems

**Prompt not updating:**
- Ensure `~/.config/starship.toml` exists and is readable
- Validate TOML syntax: `starship config`
- Check starship initialization in shell config (.zshrc, .bashrc)

**Missing icons:**
- Install a Nerd Font for proper icon display
- Verify terminal emulator supports Unicode
- Check font configuration in terminal settings

**Slow prompt performance:**
- Disable expensive modules (gcloud, nodejs, memory_usage)
- Increase git status cache timeout
- Use `starship timings` to identify slow modules

### 3. Git Integration Issues

**Git status not showing:**
- Verify git is installed and in PATH
- Check git repository is properly initialized
- Test with simple git status command

**Custom git remote detection failing:**
- Ensure git remote is configured: `git remote -v`
- Check shell supports the regex patterns used
- Test custom command directly: `git ls-remote --get-url`

### 4. Shell Integration Problems

**ZSH vi-mode integration:**
- Ensure zsh-vi-mode plugin is loaded before starship initialization
- Verify vimcmd_symbol configuration
- Check plugin load order in .zshrc

**Bash compatibility:**
- Some features may not work identically in bash
- Test prompt initialization with `eval "$(starship init bash)"`

### 5. Theme and Color Issues

**Colors not displaying correctly:**
- Verify terminal supports 256 colors or true color
- Test with `starship test colors`
- Check terminal color scheme compatibility

**Catppuccin theme not loading:**
- Verify palette name matches exactly: `catppuccin_latte`
- Check TOML syntax around palette definition
- Test with default starship config first

## Development Guidelines

### Adding New Modules
1. Research starship module documentation
2. Test module configuration in isolation
3. Consider performance impact
4. Add appropriate styling using Catppuccin colors
5. Test across supported platforms

### Modifying Custom Segments
1. Test command execution separately
2. Handle error conditions gracefully
3. Use appropriate `when` conditions
4. Consider command execution time
5. Validate shell compatibility

### Performance Considerations
1. Profile prompt with `starship timings`
2. Disable unnecessary modules
3. Use conditional execution where possible
4. Cache expensive operations
5. Test in various repository sizes

### Color Scheme Updates
1. Maintain consistency with Catppuccin theme
2. Test in both light and dark terminal backgrounds
3. Ensure accessibility for color-blind users
4. Validate color combinations for readability

## Role-Specific Notes

### Uninstallation Process
The `uninstall.sh` script:
- Detects OS and uses appropriate package manager
- Removes system-installed starship binary
- Cleans up configuration file at `~/.config/starship.toml`
- Provides feedback during removal process

### Cross-Platform Compatibility
- **macOS**: Clean Homebrew integration
- **Ubuntu**: Official installer with creates parameter for idempotency
- **Fedora**: Multi-tier approach with fallback to user directory

### Configuration Management
- Single source of truth: `files/starship.toml`
- No templating required - static configuration works across platforms
- Symlink-based approach maintains version control of config

This comprehensive guide should enable effective development and customization of the Starship prompt role within the dotfiles ecosystem.