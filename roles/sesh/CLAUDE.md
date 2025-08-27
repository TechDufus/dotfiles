# CLAUDE.md - Sesh Session Manager

This file provides guidance to Claude Code when working with the **sesh** role in this dotfiles repository.

## Role Overview and Purpose

The **sesh** role configures and deploys [sesh](https://github.com/joshmedeski/sesh), a smart terminal session manager that provides intelligent session switching and management capabilities. Sesh integrates seamlessly with tmux and zoxide to create a powerful workflow for managing development environments and project sessions.

### Key Features
- **Smart Session Management**: Automatically detects and manages tmux sessions, Git repositories, and frequently accessed directories
- **Fuzzy Finder Integration**: Uses fzf for interactive session selection with visual previews
- **Zoxide Integration**: Leverages zoxide's frecency algorithm for intelligent directory suggestions
- **Project-Based Sessions**: Automatically creates sessions based on project directories
- **Visual Session Previews**: Shows session content before switching

## Architecture

### Installation Method
Sesh is installed as a Go package via the `go` role:
```yaml
# From group_vars/all.yml
go:
  packages:
    - package: github.com/joshmedeski/sesh/v2@latest
      cmd: sesh
```

### Role Structure
```
roles/sesh/
├── tasks/
│   ├── main.yml          # Standard OS detection pattern
│   └── config.yml        # Configuration deployment
└── files/
    └── sesh.toml         # Sesh configuration file
```

## Configuration Structure (sesh.toml)

### Current Configuration
```toml
[[sessions]]
name = "dotfiles"
path = "~/.dotfiles"

# Default session configuration
[default_session]
startup_command = "tmux split-window -h -p 50 && tmux send-keys -t right 'claude --continue' C-m && tmux select-pane -L && tmux split-window -v -p 50"
startup_window_name = "main"
```

### Configuration Elements

#### Predefined Sessions (`[[sessions]]`)
- **name**: Session identifier displayed in the session list
- **path**: Working directory for the session
- **startup_command**: Optional command to run when session starts
- **startup_window_name**: Name for the initial window

#### Default Session Behavior (`[default_session]`)
- **startup_command**: Complex tmux layout creation with Claude integration
  - Creates horizontal split (50% width)
  - Starts Claude in continue mode in right pane
  - Returns to left pane and creates vertical split
- **startup_window_name**: Sets initial window name to "main"

## Tmux Integration

### Key Binding Configuration
Sesh is deeply integrated into tmux through a sophisticated key binding in `~/.config/tmux/tmux.conf`:

```bash
# Bound to prefix + o
bind-key "o" display-popup -E -w 80% -h 70% "sesh connect \"$(
  sesh list --icons -H | fzf --reverse --no-sort --ansi \
    --border-label ' sesh ' --prompt '⚡  ' \
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
    --preview 'echo {} | awk \"{print \\\$2}\" | xargs -I % sesh preview %' \
    --preview-window 'right:50%:border-left'
)\""
```

### Integration Features

#### Popup Interface
- **Size**: 80% width, 70% height popup window
- **Border**: Rounded borders with Catppuccin lavender color
- **Position**: Centered overlay on current tmux session

#### Interactive Controls
- **Tab/Shift-Tab**: Navigate selection up/down
- **Ctrl-A**: Show all available sessions (⚡ prompt)
- **Ctrl-T**: Show only tmux sessions (🪟 prompt)
- **Ctrl-G**: Show configuration directories (⚙️ prompt)
- **Ctrl-X**: Show zoxide directories (📁 prompt)
- **Ctrl-F**: File finder mode (🔎 prompt)
- **Ctrl-D**: Kill selected session and reload list

#### Preview Window
- **Position**: Right side, 50% width
- **Border**: Left border separation
- **Content**: Live preview of session contents using `sesh preview`

## Zoxide Integration

### Smart Directory Detection
Sesh integrates with zoxide through the `Ctrl-X` binding, which:
- Accesses zoxide's database of frequently used directories
- Shows directories ranked by frecency (frequency + recency)
- Allows quick session creation for any directory in zoxide's database

### Benefits
- **Automatic Discovery**: No need to manually configure session paths
- **Smart Ranking**: Most relevant directories appear first
- **Seamless Workflow**: Jump to any project directory with a few keystrokes

## Session Management Features

### Session Types

#### Predefined Sessions
- **dotfiles**: Dedicated session for dotfiles management
- Automatically opens in `~/.dotfiles` directory
- Uses default startup command for enhanced layout

#### Dynamic Sessions
- **Tmux Sessions**: Existing tmux sessions are automatically detected
- **Config Sessions**: Git repositories and configuration directories
- **Zoxide Sessions**: Frequently accessed directories from zoxide database
- **Find Sessions**: File system search using fd for directory discovery

### Session Creation Workflow
1. **Detection**: Sesh scans for existing sessions and potential session sources
2. **Listing**: Displays sessions with icons and metadata
3. **Selection**: User selects session via fuzzy finder
4. **Connection**: Sesh connects to existing session or creates new one
5. **Layout**: Applies default startup command if creating new session

## Key Bindings and Commands

### Tmux Integration
- **Prefix + o**: Open sesh session manager popup

### Within Sesh Interface
- **Enter**: Connect to selected session
- **Escape**: Close sesh interface
- **Tab/Shift-Tab**: Navigate session list
- **Ctrl-A**: All sessions mode
- **Ctrl-T**: Tmux sessions only
- **Ctrl-G**: Config/Git repositories
- **Ctrl-X**: Zoxide directories
- **Ctrl-F**: File finder mode
- **Ctrl-D**: Kill session (with confirmation)

### Command Line Usage
```bash
# List all available sessions
sesh list --icons

# Connect to specific session
sesh connect <session_name>

# Preview session contents
sesh preview <session_name>

# Kill session
sesh kill <session_name>
```

## Common Use Cases and Workflows

### Project Development Workflow
1. **Start Work**: Press `Prefix + o` in tmux
2. **Find Project**: Use `Ctrl-X` to browse zoxide directories or `Ctrl-F` to search
3. **Quick Switch**: Select project and press Enter
4. **Enhanced Layout**: New sessions automatically get Claude integration and split layout
5. **Session Management**: Use `Ctrl-D` to clean up unused sessions

### Configuration Management
1. **Access Configs**: Press `Prefix + o` then `Ctrl-G`
2. **Dotfiles**: Quickly jump to predefined dotfiles session
3. **Other Configs**: Browse detected configuration directories
4. **Edit and Test**: Work in dedicated session with proper context

### Multi-Project Development
1. **Session Switching**: Rapid switching between project sessions
2. **Context Preservation**: Each project maintains its own session state
3. **Resource Management**: Clean up unused sessions to maintain performance

## Advanced Configuration

### Adding Custom Sessions
To add more predefined sessions, extend `sesh.toml`:

```toml
[[sessions]]
name = "project-name"
path = "~/path/to/project"
startup_command = "optional startup command"
startup_window_name = "custom-name"
```

### Customizing Startup Commands
The default startup command creates a sophisticated development layout:
- **Right Pane**: Claude AI in continue mode for coding assistance
- **Left Top**: Primary development pane
- **Left Bottom**: Secondary pane for testing, logs, or terminals

### Integration with Other Tools
- **Claude AI**: Automatic startup in dedicated pane
- **Git**: Automatic detection of Git repositories
- **Zoxide**: Frecency-based directory suggestions
- **fd**: File system search capabilities
- **fzf**: Interactive selection interface

## Troubleshooting Tips

### Common Issues

#### Sesh Command Not Found
- **Cause**: Go binary not in PATH or not installed
- **Solution**: Ensure `go` role has run successfully and shell has been restarted

#### Empty Session List
- **Cause**: No zoxide database or tmux sessions
- **Solution**: Use directories for a while to populate zoxide, or use `Ctrl-F` for file search

#### Preview Not Working
- **Cause**: Session doesn't exist or tmux not running
- **Solution**: Verify session exists with `tmux list-sessions`

#### Popup Not Appearing
- **Cause**: Tmux version too old or key binding conflict
- **Solution**: Verify tmux version supports popups (2.6+) and check for key conflicts

### Performance Optimization

#### Large Directory Trees
- File finder (`Ctrl-F`) uses fd with depth limit of 2 to prevent performance issues
- Excludes .Trash directory to avoid irrelevant results

#### Session Cleanup
- Use `Ctrl-D` regularly to remove unused sessions
- Consider scripting session cleanup for automated maintenance

## Development Guidelines

### Role Modification
When modifying the sesh role:

1. **Configuration Changes**: Edit `files/sesh.toml` for sesh-specific settings
2. **Integration Changes**: Modify tmux configuration for interface adjustments
3. **Testing**: Test popup interface in various tmux environments
4. **Dependencies**: Ensure zoxide and fzf are available for full functionality

### Adding Features
- **New Session Types**: Extend `sesh list` commands in tmux key bindings
- **Custom Layouts**: Modify startup_command in sesh.toml
- **Additional Integrations**: Consider other tools that could benefit from session management

### Best Practices
- **Idempotency**: Configuration deployment should be safe to run multiple times
- **Cross-Platform**: Consider OS differences when adding new features
- **Performance**: Keep session detection fast to maintain responsive interface
- **Documentation**: Update this file when adding new configuration options

## Security Considerations

### Command Execution
- Startup commands are executed in user context
- No privilege escalation or system-wide changes
- Commands are defined in configuration, not dynamically generated

### Integration Safety
- tmux popup runs in isolated environment
- File system access limited to user directories
- No network operations or external command execution

This comprehensive session management system transforms terminal workflow by providing intelligent, context-aware session switching with powerful integrations for modern development environments.