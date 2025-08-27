# bat Role - CLAUDE.md

## Role Overview

The **bat** role installs and configures [bat](https://github.com/sharkdp/bat), a modern replacement for `cat` with syntax highlighting, Git integration, and automatic paging. This role provides enhanced file viewing capabilities with beautiful syntax highlighting and seamless theme integration.

### Purpose
- Replace standard `cat` with syntax-highlighted file viewing
- Integrate with the Catppuccin Mocha theme for consistent aesthetics
- Provide Git diff indicators in file views
- Enable line numbers and file headers for better code navigation
- Support custom syntax mappings for specialized file types

## Installation Strategy

### Cross-Platform Installation
- **macOS**: Homebrew installation (`brew install bat`)
- **Ubuntu/Debian**: Direct GitHub release download as `.deb` package
- **Fedora**: DNF package manager with GitHub fallback for restricted environments
- **Architecture Support**: Primarily x86_64, with aarch64 exclusion on Ubuntu

### Version Management
- **Ubuntu**: Automatic latest version detection from GitHub API
- **Fedora**: Both package manager and GitHub release options
- **macOS**: Homebrew handles version management
- **Version Comparison**: Smart version checking to prevent unnecessary reinstalls

## Configuration Structure

### Main Configuration File
Location: `~/.config/bat/config`

```bash
# Theme configuration
--theme="Catppuccino Mocha"

# Display options
--style="numbers,changes,header"

# Optional features (commented by default)
#--italic-text=always
#--paging=never
#--pager="less --RAW-CONTROL-CHARS --quit-if-one-screen --mouse"

# Syntax mappings
#--map-syntax "*.ino:C++"
#--map-syntax ".ignore:Git Ignore"
```

### Theme Integration
- **Theme**: Catppuccin Mocha for consistent color scheme
- **Theme Source**: Downloaded directly from [catppuccin/bat](https://github.com/catppuccin/bat)
- **Theme Location**: `~/.config/bat/themes/Catppuccino Mocha.tmTheme`
- **Auto-Installation**: Theme downloaded automatically during setup

### Directory Structure
```
~/.config/bat/
├── config              # Main configuration file
└── themes/            # Custom themes directory
    └── Catppuccino Mocha.tmTheme
```

## Feature Configuration

### Display Styles
The role configures bat with three key display elements:
- `numbers`: Line numbers for easy reference
- `changes`: Git modification indicators (added/modified/deleted lines)
- `header`: File name and metadata display

### Theme Customization
- **Default Theme**: Catppuccin Mocha for dark terminal environments
- **Theme Discovery**: Use `bat --list-themes` to see all available themes
- **Custom Themes**: Add `.tmTheme` files to `~/.config/bat/themes/`

### Syntax Highlighting

#### Built-in Language Support
Bat includes extensive syntax highlighting for common languages:
- Programming languages (Python, JavaScript, Rust, Go, etc.)
- Markup languages (HTML, Markdown, XML)
- Configuration files (YAML, JSON, TOML)
- Shell scripts and Docker files

#### Custom Syntax Mappings
Example configurations for specialized file types:
```bash
# Arduino files
--map-syntax "*.ino:C++"

# Custom ignore files
--map-syntax ".ignore:Git Ignore"
--map-syntax "*.ignore:Git Ignore"

# Configuration files
--map-syntax "*.conf:INI"
--map-syntax "Dockerfile.*:Dockerfile"
```

## Integration Patterns

### As a Pager
Configure bat as a pager for other tools:
```bash
# Environment variables
export PAGER="bat --paging=always"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Git integration
git config --global core.pager "bat --paging=always"
```

### Shell Aliases
Common aliases to enhance bat usage:
```bash
# Replace cat with bat
alias cat='bat --paging=never'

# Bat with plain output (no decorations)
alias batp='bat --style=plain'

# Bat with only syntax highlighting
alias bats='bat --style=plain --color=always'

# Bat for specific languages
alias batjson='bat --language=json'
alias batyml='bat --language=yaml'
```

### Tool Integration
- **fzf**: Use bat for file previews in fuzzy finder
- **Git**: Enhanced diff and log viewing
- **Less**: Alternative pager with syntax highlighting
- **Man pages**: Syntax-highlighted manual pages

## Performance Considerations

### Caching
- **Syntax Cache**: Bat automatically caches syntax definitions
- **Theme Cache**: Themes are cached for faster loading
- **Cache Location**: `~/.cache/bat/` (varies by OS)
- **Cache Management**: Cleared automatically on version updates

### Large Files
- **Automatic Paging**: Enabled by default for files larger than screen
- **Streaming**: Efficient handling of large files without loading entirely
- **Line Limits**: Configure `--line-range` for viewing specific sections

### Memory Usage
- **Lazy Loading**: Syntax highlighting loaded on-demand
- **Theme Loading**: Only active theme loaded into memory
- **Git Integration**: Minimal overhead for Git status checking

## Customization Points

### Theme Development
Create custom themes:
1. Use existing `.tmTheme` format (TextMate/Sublime Text)
2. Place in `~/.config/bat/themes/`
3. Rebuild cache: `bat cache --build`
4. Select theme: `bat --theme="Custom Theme"`

### Language Extensions
Add support for new file types:
1. Create custom syntax definitions (`.sublime-syntax`)
2. Place in `~/.config/bat/syntaxes/`
3. Rebuild cache: `bat cache --build`
4. Map file extensions: `--map-syntax "*.ext:Language"`

### Pager Configuration
Advanced pager settings:
```bash
# Mouse support in tmux
--pager="less --RAW-CONTROL-CHARS --quit-if-one-screen --mouse"

# Custom less options
--pager="less -RF"

# Disable paging for small files
--paging=auto
```

## Troubleshooting

### Common Issues

#### Theme Not Loading
```bash
# Check theme availability
bat --list-themes | grep -i mocha

# Verify theme file exists
ls ~/.config/bat/themes/

# Rebuild theme cache
bat cache --build
```

#### Syntax Not Working
```bash
# Check language detection
bat --list-languages | grep <language>

# Force language
bat --language=<lang> file.ext

# Debug syntax mapping
bat --list-languages --tabs=2
```

#### Git Integration Issues
```bash
# Verify Git repository
git status

# Check bat Git integration
bat --style=changes file.txt

# Disable Git integration
bat --style=numbers,header file.txt
```

### Cache Management
```bash
# Clear all caches
bat cache --clear

# Rebuild caches
bat cache --build

# Show cache directory
bat cache --source-dir
bat cache --target-dir
```

### Configuration Debugging
```bash
# Show effective configuration
bat --config-file

# Validate configuration
bat --config-file /path/to/config --help

# Test with minimal config
bat --no-config file.txt
```

## Development Guidelines

### Role Structure Compliance
- **OS Detection**: Uses standard distribution detection pattern
- **Task Naming**: Follows "Bat | OS | Action" convention
- **Error Handling**: Graceful fallbacks for installation methods
- **Idempotency**: Version checking prevents unnecessary operations

### Configuration Management
- **Static Files**: Configuration stored in `files/` directory
- **No Templates**: Simple config file doesn't require Jinja2 templating
- **Permissions**: Appropriate file permissions (0644 for config, 0755 for directories)

### Installation Strategies
- **Package Managers**: Preferred method when available
- **GitHub Releases**: Fallback for restricted environments
- **Version Pinning**: Optional version targeting via variables
- **Architecture Awareness**: Platform-specific binary selection

### Testing Considerations
- **Dry Run**: Test with `dotfiles --check`
- **Version Verification**: Confirm bat version after installation
- **Theme Loading**: Verify Catppuccin theme downloads correctly
- **Configuration Applied**: Check config file deployment

### Extension Points
- **Custom Themes**: Easy addition of new theme files
- **Syntax Extensions**: Support for custom language definitions
- **Pager Integration**: Configure as system pager
- **Alias Creation**: Shell integration through other roles

## Integration with Dotfiles Ecosystem

### Role Dependencies
- **No Hard Dependencies**: Standalone installation
- **Optional Integration**: Enhanced with Git, fzf, and shell roles
- **Theme Consistency**: Matches Catppuccin ecosystem

### Variable Integration
- **GitHub Variables**: Reuses standard GitHub API patterns
- **Version Control**: Consistent with other GitHub-based tools
- **Permission Variables**: Respects `can_install_packages` flag

### Uninstall Support
- **Complete Removal**: Package and configuration cleanup
- **OS-Aware**: Platform-specific removal commands
- **Safe Execution**: Error handling for missing packages

This role provides a solid foundation for enhanced file viewing with beautiful syntax highlighting and seamless integration into the broader dotfiles ecosystem.