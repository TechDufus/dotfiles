# Neovim Role

Configures Neovim as a modern IDE with lazy.nvim plugin management, LSP via Mason, and Catppuccin theme.

## Key Files
- `~/.config/nvim/` - Symlinked to `roles/neovim/files/`
- `files/init.lua` - Entry point loading techdufus config and lazy.nvim
- `files/lazy-lock.json` - Plugin version lockfile (commit this after updates)
- `files/lua/plugins/` - Individual plugin configs (lsp.lua, telescope.lua, etc.)
- `files/lua/techdufus/core/` - Options, keymaps, autocommands
- `files/lua/techdufus/init.lua` - ConfigMode setting ("rich" or "simple")

## Patterns

### lazy.nvim Plugin Management
Each plugin in `lua/plugins/` with lazy loading:
```lua
return {
  "plugin/name",
  event = "BufRead",  -- Lazy load trigger
  config = function() ... end,
}
```
Use `:Lazy` to manage plugins, `:Lazy profile` for performance.

### Mason LSP Management
Servers auto-installed via Mason (`lua/plugins/lsp.lua`):
- gopls, ansiblels, bashls, lua_ls, yamlls, etc.
- Use `:Mason` to manage servers

### ConfigMode Setting
In `lua/techdufus/init.lua`:
- `"rich"` (default): Full icons, true color, transparent background
- `"simple"`: Basic 8-color for limited terminals

## Integration
- **Uses**: vim-tmux-navigator for seamless pane navigation
- **Uses**: Gitsigns, Lazygit for Git workflows
- **Uses**: Copilot and Avante for AI assistance

## Gotchas
- Space is leader key; arrow keys show warning (use hjkl)
- `lazy-lock.json` pins versions; run `:Lazy sync` then commit lockfile
- LSP keymaps: `gd` definition, `gr` references, `K` hover, `<Leader>ca` actions
- Neo-tree replaces netrw; Oil available as alternative
- 2-space indentation, 90-char color column
