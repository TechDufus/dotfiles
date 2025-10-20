# Neovim Role - CLAUDE.md

This file provides comprehensive guidance for working with the Neovim role in this Ansible-based dotfiles system. This role creates a modern, feature-rich Neovim configuration optimized for development across multiple languages and platforms.

## Role Overview

The Neovim role is a sophisticated, modular configuration system that transforms Neovim into a powerful IDE-like editor. It features:

- **Plugin Management**: Uses lazy.nvim for efficient plugin loading and management
- **LSP Integration**: Complete Language Server Protocol setup with Mason for server management
- **Modern UI**: Telescope, Neo-tree, statusline, and other UI enhancements
- **AI Integration**: GitHub Copilot and Claude Code integration
- **Development Tools**: Git integration, debugging support, and terminal management
- **Cross-platform**: Works consistently across macOS, Linux distributions

## Architecture and Directory Structure

### Configuration Structure
```
~/.config/nvim/ (symlinked to roles/neovim/files/)
├── init.lua                    # Entry point - loads techdufus config and lazy.nvim
├── lazy-lock.json             # Plugin version lockfile
└── lua/
    ├── plugins/               # Individual plugin configurations
    │   ├── init.lua          # Core plugins list
    │   ├── lsp.lua           # LSP, completion, and Mason setup
    │   ├── telescope.lua     # Fuzzy finder configuration
    │   ├── treesitter.lua    # Syntax highlighting and parsing
    │   ├── color_scheme.lua  # Theme configuration (Catppuccin)
    │   ├── statusline.lua    # Status line setup
    │   ├── neo-tree.lua      # File explorer
    │   ├── copilot.lua       # AI completion
    │   ├── avante.lua        # Claude Code integration
    │   └── ... (30+ other plugins)
    └── techdufus/            # Custom modules and core configuration
        ├── init.lua          # ConfigMode setting and core loading
        ├── core/             # Core Neovim configuration
        │   ├── init.lua      # Loads all core modules
        │   ├── options.lua   # Vim options and settings
        │   ├── keymaps.lua   # Key mappings and shortcuts
        │   ├── globals.lua   # Global utilities and functions
        │   ├── autocommands.lua # Autocommands and event handlers
        │   ├── disable.lua   # Disabled built-in plugins
        │   ├── icons.lua     # Icon definitions for UI
        │   └── utils.lua     # Helper functions
        └── telescope/        # Custom telescope configurations
            └── pickers.lua   # Custom telescope pickers
```

## Plugin Management with lazy.nvim

### Key Features
- **Lazy Loading**: Plugins load only when needed (events, commands, filetypes)
- **Version Locking**: `lazy-lock.json` ensures consistent plugin versions
- **Automatic Installation**: Plugins install automatically on first run
- **Update Management**: Built-in update checking and management

### Plugin Organization
Each plugin has its own file in `lua/plugins/` with specific configuration:

```lua
-- Example plugin structure
return {
  "plugin/name",
  dependencies = { "other/plugin" },
  event = "BufRead",  -- Lazy loading trigger
  config = function()
    -- Plugin setup and configuration
  end,
  keys = {
    -- Key mappings specific to this plugin
  }
}
```

### Adding New Plugins
1. Create new file in `lua/plugins/` (e.g., `new-plugin.lua`)
2. Use the standard plugin structure with lazy loading
3. Test with `:Lazy` command to verify loading
4. Run dotfiles to update the symlinked configuration

## Language Server Protocol (LSP) Setup

### Mason Integration
The configuration uses Mason for automatic LSP server management:

```lua
-- Automatically installed LSP servers
ensure_installed = {
  'gopls',        -- Go
  'ansiblels',    -- Ansible
  'bashls',       -- Bash
  'dockerls',     -- Docker
  'jsonls',       -- JSON
  'terraformls',  -- Terraform
  'lua_ls',       -- Lua
  'yamlls',       -- YAML
  'pylsp',        -- Python
  -- ... and more
}
```

### LSP Key Mappings
The configuration provides consistent LSP keybindings:
- `gd` - Go to definition
- `gD` - Go to declaration
- `gi` - Go to implementations (via Telescope)
- `gt` - Go to type definitions (via Telescope)
- `gr` - Show references (via Telescope)
- `K` - Show hover documentation
- `<Leader>rn` - Rename symbol
- `<Leader>ca` - Code actions
- `<Leader>f` - Format document
- `[d` / `]d` - Navigate diagnostics

### Completion System
Uses nvim-cmp with multiple sources:
- LSP completions (primary)
- Luasnip snippets
- Buffer text
- File paths
- Treesitter symbols
- Tmux panes
- Emoji completions

## Key Plugin Configurations

### Telescope (Fuzzy Finder)
**File**: `lua/plugins/telescope.lua`
**Purpose**: File finding, grep searching, and navigation

Key bindings:
- `<Leader>fs` - Project files
- `<Leader>gs` - Live grep search
- `<Leader>fr` - Recent files
- `<Leader>b` - Open buffers
- `/` - Search in current buffer

### Treesitter (Syntax Highlighting)
**File**: `lua/plugins/treesitter.lua`
**Purpose**: Advanced syntax highlighting and text objects

Features:
- All parsers auto-installed
- Incremental selection with `<C-n>`
- Rainbow parentheses
- Auto-indentation

### Git Integration
Multiple plugins provide Git functionality:
- **Gitsigns**: Line-level git integration and blame
- **Lazygit**: Terminal Git UI integration (`<Leader>gg`)
- **Git Worktree**: Multiple repository branch management

### AI Integration
- **Copilot**: GitHub Copilot integration (`lua/plugins/copilot.lua`)
- **Avante**: Claude Code integration (`lua/plugins/avante.lua`)

## Configuration Modes

The configuration supports two modes via the `ConfigMode` variable:

### Rich Mode (Default)
```lua
ConfigMode = "rich" -- Full features with Nerd Fonts and true color
```
- Transparent background
- Full icon support
- True color terminal support
- System clipboard integration

### Simple Mode
```lua
ConfigMode = "simple" -- Minimal for basic terminals
```
- Basic 8-color support
- Minimal visual elements
- Better compatibility with basic terminals

## Core Configuration Modules

### Options (`lua/techdufus/core/options.lua`)
Key settings:
- Line numbers (relative and absolute)
- 2-space indentation
- Smart search (case-insensitive with smart case)
- Split behavior (right/below)
- Persistent undo
- 90-character color column
- Berkeley Mono Nerd Font

### Keymaps (`lua/techdufus/core/keymaps.lua`)
**Philosophy**: Vim-centric with modern enhancements

Core mappings:
- `<Space>` as leader key
- Arrow key warnings (encourages hjkl)
- Window navigation with `<C-hjkl>`
- Tmux-aware navigation
- Harpoon quick file access (`<Leader>a`, `<Leader>e`)
- Buffer management (`<S-h>`, `<S-l>`)
- Visual mode improvements (stay in indent mode)

### Custom Utilities
**File**: `lua/techdufus/core/utils.lua` and `lua/techdufus/core/globals.lua`

- `require_on_exported_call`: Lazy require pattern for performance
- Helper functions for plugin integration
- Custom telescope pickers for project files and dotfiles

## Performance Optimizations

### Lazy Loading Strategy
- Plugins load on specific events (InsertEnter, BufRead, etc.)
- Command-based loading for infrequently used plugins
- Filetype-specific loading (Go plugins only for .go files)

### Disabled Built-ins
**File**: `lua/techdufus/core/disable.lua`
Disables unused Neovim built-in plugins:
- Netrw (replaced by Neo-tree/Oil)
- Various built-in plugins that aren't needed

### Startup Performance
- Lazy.nvim manages plugin loading efficiently
- Core configuration loads first, plugins load as needed
- Performance profiling available with `:Lazy profile`

## Integration with Other Tools

### Tmux Integration
- **vim-tmux-navigator**: Seamless pane navigation between Vim and tmux
- Navigation keys work consistently across both applications

### Terminal Integration
- **ToggleTerm**: Floating and persistent terminal windows
- LazyGit integration for visual Git workflows

### File Management
- **Neo-tree**: Full-featured file explorer with Git integration
- **Oil**: Edit directories like files (alternative file manager)

## Common Customization Points

### Adding Language Support
1. Add LSP server to Mason's `ensure_installed` list
2. Add filetype-specific plugins if needed
3. Configure any language-specific settings
4. Test with sample files

### Color Scheme Customization
**File**: `lua/plugins/color_scheme.lua`
```lua
-- Current: Catppuccin Macchiato with transparency
-- To change: modify the flavor or add new color scheme plugin
```

### Statusline Customization
**File**: `lua/plugins/statusline.lua`
Modify statusline components, colors, or add new sections.

### Key Mapping Changes
**Files**:
- `lua/techdufus/core/keymaps.lua` (core mappings)
- Individual plugin files (plugin-specific mappings)

### Plugin Addition
1. Create new file in `lua/plugins/`
2. Use lazy.nvim plugin specification
3. Include appropriate lazy loading triggers
4. Test thoroughly before committing

## Troubleshooting

### Common Issues

**Plugin Not Loading**
- Check lazy loading configuration (event, cmd, ft)
- Verify plugin specification syntax
- Use `:Lazy` to check plugin status

**LSP Server Issues**
- Check Mason installation: `:Mason`
- Verify server in `ensure_installed` list
- Check LSP status: `:LspInfo`

**Performance Issues**
- Profile startup: `:Lazy profile`
- Check for synchronous plugin loading
- Review autocommands and event handlers

**Keybinding Conflicts**
- Use `:checkhealth` to identify issues
- Review plugin-specific keymaps
- Check for duplicate mappings

### Debugging Tools
- `:checkhealth` - Comprehensive system check
- `:Lazy` - Plugin manager interface
- `:LspInfo` - LSP server status
- `:Telescope diagnostics` - Code diagnostics
- `:InspectTree` - Treesitter debugging

## Development Guidelines

### Code Style
- Use descriptive function and variable names
- Include comments for complex configurations
- Follow Lua style conventions (snake_case for variables)
- Group related configurations together

### Plugin Configuration Pattern
```lua
return {
  "author/plugin-name",
  -- Always specify lazy loading
  event = "VeryLazy", -- or cmd, ft, keys, etc.

  -- Explicit dependencies
  dependencies = {
    "required/dependency"
  },

  -- Configuration function
  config = function()
    require("plugin-name").setup({
      -- Plugin configuration
    })
  end,

  -- Plugin-specific keymaps
  keys = {
    { "<leader>key", "<cmd>Command<cr>", desc = "Description" }
  }
}
```

### Testing New Configurations
1. Test in isolation with specific role: `dotfiles -t neovim`
2. Verify plugin loads correctly: `:Lazy`
3. Test key functionality manually
4. Check for performance impact: `:Lazy profile`
5. Ensure idempotency (run twice, same result)

### Version Management
- Lock plugin versions with `lazy-lock.json`
- Test updates in development before production
- Document breaking changes in commit messages
- Use semantic versioning for major configuration changes

## Maintenance Notes

### Regular Maintenance Tasks
1. Update plugins: `:Lazy sync`
2. Update LSP servers: `:Mason`
3. Review and clean unused plugins
4. Check for deprecated configurations
5. Update lazy-lock.json after testing updates

### Security Considerations
- Plugin sources from trusted repositories only
- Review plugin code for sensitive operations
- Keep plugins updated for security patches
- Avoid storing secrets in configuration files

### Backup Strategy
The Ansible role automatically backs up existing configurations:
- Creates timestamped backups of existing configs
- Preserves user customizations during updates
- Clean uninstall process with `uninstall.sh`

## Extended Features

### Advanced Git Workflows
- Git worktree support for multi-branch development
- Interactive staging and commit workflows
- Blame integration in editor
- Conflict resolution tools

### Debugging Support
- DAP (Debug Adapter Protocol) integration
- Language-specific debugger configurations
- Breakpoint management and variable inspection

### AI-Powered Development
- Context-aware code completion
- Documentation generation
- Code explanation and refactoring suggestions
- Multi-language support for AI features

This configuration represents a modern, extensible Neovim setup that grows with your development needs while maintaining performance and reliability.