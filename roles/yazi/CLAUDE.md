# Yazi Role

Terminal file manager with image preview support (via Kitty graphics protocol).

## Key Files
- `~/.config/yazi/yazi.toml` - Core settings
- `~/.config/yazi/keymap.toml` - Keybindings
- `~/.config/yazi/theme.toml` - Catppuccin Mocha theme

## Dependencies
Installed automatically:
- ffmpegthumbnailer - Video thumbnails
- unar - Archive extraction
- poppler - PDF previews
- fd/ripgrep - Fast search
- imagemagick - Image processing
- zoxide - Directory jumping (z command in yazi)

## Key Bindings
- `j/k` - Navigate up/down
- `h/l` - Parent dir / Enter
- `Space` - Select file
- `y` - Yank (copy)
- `p` - Paste
- `d` - Trash
- `a` - Create file
- `r` - Rename
- `.` - Toggle hidden files
- `z` - Jump via zoxide
- `/` - Search
- `q` - Quit

## Integration
- **tmux**: Requires `allow-passthrough on` for image previews (configured in tmux role)
- **Ghostty/Kitty**: Native image support via Kitty graphics protocol
- **zoxide**: `z` key jumps to frecent directories
