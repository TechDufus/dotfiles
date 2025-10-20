# K9s Role Documentation

## Overview

The k9s role provides a terminal-based Kubernetes UI for efficient cluster management. K9s offers real-time cluster monitoring, resource navigation, and streamlined operations for Kubernetes administrators and developers. This role configures k9s with the Catppuccin Mocha theme for visual consistency and includes custom aliases and plugins for enhanced productivity.

## Role Purpose

K9s serves as a powerful terminal-based dashboard for Kubernetes clusters, providing:
- **Real-time cluster monitoring** with live resource updates
- **Resource navigation** through an intuitive TUI (Terminal User Interface)
- **Operation efficiency** with keyboard shortcuts and custom commands
- **Multi-context support** for managing multiple clusters
- **Log streaming** and resource inspection capabilities
- **Custom theming** with the beautiful Catppuccin Mocha color scheme

## Configuration Files

### Core Configuration (`config.yaml`)

Located at: `~/.config/k9s/config.yaml` (Linux) or `~/Library/Application Support/k9s/config.yaml` (macOS)

Key configuration sections:

#### Performance Settings
```yaml
k9s:
  liveViewAutoRefresh: true    # Enable auto-refresh for resource views
  refreshRate: 1               # UI refresh interval (1 second)
  maxConnRetry: 5              # API server reconnection attempts
  readOnly: false              # Allow modification commands
```

#### UI Customization
```yaml
ui:
  enableMouse: false           # Disabled to allow text selection/copying
  logoless: true               # Hide K9s logo for clean interface
  reactive: true               # Live updates from disk changes
  skin: catppuccin_mocha       # Custom Catppuccin theme
  defaultsToFullScreen: false  # Keep windowed mode for better navigation
```

#### Logging Configuration
```yaml
logger:
  tail: 200                    # Lines to return in log view
  buffer: 500                  # Total log lines in memory
  sinceSeconds: 300            # Show logs from last 5 minutes
  textWrap: false              # Disable line wrapping
  showTime: false              # Hide timestamps for cleaner logs
```

#### Shell Pod Configuration
```yaml
shellPod:
  image: killerAdmin           # Debug container image
  namespace: default           # Target namespace for shell pods
  limits:
    cpu: 100m                  # CPU limit for shell pods
    memory: 100Mi              # Memory limit for shell pods
  tty: true                    # Enable TTY for interactive sessions
```

### Aliases Configuration (`aliases.yaml`)

Simplifies common resource access:

```yaml
aliases:
  dep: apps/v1/deployments     # Quick access to deployments
```

**Usage**: Type `:dep` in k9s to navigate directly to deployments view.

### Plugin System (`plugins.yaml`)

Custom plugins extend k9s functionality:

#### Helm Values Plugin
```yaml
plugins:
  helm-values:
    shortCut: v                # Press 'v' to activate
    confirm: false             # No confirmation needed
    description: Values        # Plugin description
    scopes:
      - helm                   # Only available in Helm resource views
    command: sh                # Execute shell command
    background: false          # Run in foreground
    args:
      - -c
      - "helm get values $COL-NAME -n $NAMESPACE --kube-context $CONTEXT | less -K"
```

**Usage**: Navigate to Helm releases, select a release, press 'v' to view values.

### Theme Configuration (`catppuccin_mocha.yaml`)

Located in `skins/` subdirectory, provides consistent Catppuccin Mocha theming:

#### Color Palette Features
- **Transparent background** preserves terminal appearance
- **Catppuccin Mocha colors** for consistent visual experience
- **Semantic color coding** for different resource states
- **Accessibility-focused** with sufficient contrast ratios

#### Key Color Mappings
```yaml
k9s:
  body:
    fgColor: '#cdd6f4'         # Main text (Catppuccin Text)
    logoColor: '#cba6f7'       # K9s logo (Catppuccin Mauve)
  frame:
    title:
      fgColor: '#94e2d5'       # Window titles (Catppuccin Teal)
      filterColor: '#a6e3a1'   # Filter text (Catppuccin Green)
    status:
      errorColor: '#f38ba8'    # Error states (Catppuccin Red)
      addColor: '#a6e3a1'      # Addition states (Catppuccin Green)
      modifyColor: '#b4befe'   # Modification states (Catppuccin Lavender)
```

## Installation Methods by OS

### macOS (Homebrew)
- Installs k9s via `brew install k9s`
- Configuration stored in `~/Library/Application Support/k9s/`
- Automatic dependency resolution

### Ubuntu/Debian (GitHub Release)
- Downloads latest release from GitHub
- Installs to `/usr/local/bin/k9s`
- Manual version checking and updates
- Configuration in `~/.config/k9s/`

### Fedora/RHEL (GitHub Release via Role)
- Uses `github_release` role for installation
- Supports both user and system-wide installation
- Architecture detection (amd64/arm64)
- Fallback to user directory without sudo

### Arch Linux (Package Manager)
- Installs via `pacman -S k9s`
- Uses official Arch package repository
- Automatic updates via system package manager

## Kubernetes Context Management

### Multi-Context Support
K9s automatically detects and supports multiple Kubernetes contexts:

```bash
# Switch contexts within k9s
:ctx                          # View available contexts
<Enter> on context           # Switch to selected context
```

### Context-Specific Configuration
- Each context can have unique settings
- Skin themes persist across contexts
- Resource filters maintained per context

## Resource Navigation and Filtering

### Navigation Patterns
```bash
# Resource Navigation
:pods                        # View pods
:svc                         # View services
:deploy                      # View deployments
:dep                         # Using alias for deployments
:ns                          # View namespaces

# Filtering
/search-term                 # Filter current view
Ctrl+U                       # Clear filter
```

### Advanced Filtering
- **Regex support** in filter expressions
- **Column-specific filtering** with advanced patterns
- **Label selectors** for precise resource targeting
- **Status-based filtering** (Running, Pending, Failed)

## Custom Keybindings and Operations

### Standard Operations
```bash
# Resource Management
d                            # Delete selected resource
e                            # Edit resource
y                            # View YAML
l                            # View logs
s                            # Shell into container
p                            # Port forward

# Navigation
Enter                        # Drill down into resource
Esc                          # Go back up
q                            # Quit current view
:q                           # Quit k9s
```

### Custom Plugin Keybindings
```bash
v                            # View Helm values (in Helm scope)
```

## Integration with kubectl and helm

### Seamless kubectl Integration
- Uses current `kubectl` context automatically
- Respects `KUBECONFIG` environment variable
- Maintains kubectl configuration precedence

### Helm Integration
- Automatic Helm resource detection
- Custom plugin for viewing Helm values
- Context-aware Helm operations

### Environment Variables
```bash
export KUBECONFIG=~/.kube/config          # Standard kubeconfig
export KUBECONFIG=~/.kube/prod:~/.kube/dev  # Multiple configs
```

## Performance Optimization

### Resource Efficiency
```yaml
refreshRate: 1               # Balance between responsiveness and CPU
maxConnRetry: 5              # Prevent excessive API calls
logger:
  buffer: 500                # Limit memory usage for logs
  sinceSeconds: 300          # Reduce initial log load
```

### Network Optimization
- Connection pooling to Kubernetes API
- Efficient resource watching mechanisms
- Graceful handling of network interruptions

## Log Management and Streaming

### Log Configuration
```yaml
logger:
  tail: 200                  # Initial lines to fetch
  buffer: 500                # Maximum lines in memory
  sinceSeconds: 300          # Time window for log history
  textWrap: false            # Preserve original formatting
  showTime: false            # Clean log presentation
```

### Log Operations
```bash
l                            # View pod logs
Shift+L                      # View previous container logs
f                            # Toggle log following
w                            # Toggle line wrapping
s                            # Save logs to file
```

## Troubleshooting Tips

### Common Issues and Solutions

#### Connection Problems
```bash
# Check kubectl connectivity
kubectl cluster-info

# Verify context
kubectl config current-context

# Test API access
kubectl get nodes
```

#### Configuration Issues
```bash
# Reset k9s configuration
rm -rf ~/.config/k9s/        # Linux
rm -rf "~/Library/Application Support/k9s/"  # macOS

# Re-run dotfiles installation
dotfiles -t k9s
```

#### Theme Not Loading
- Verify `catppuccin_mocha.yaml` exists in skins directory
- Check `config.yaml` has correct skin reference
- Restart k9s after theme changes

#### Performance Issues
```yaml
# Reduce refresh rate in config.yaml
refreshRate: 2               # Increase to reduce CPU usage
liveViewAutoRefresh: false   # Disable auto-refresh if needed
```

### Debug Mode
```bash
k9s --debug                  # Enable debug logging
k9s --log-level debug        # Verbose logging
```

## Development Guidelines

### Adding New Aliases
1. Edit `files/aliases.yaml`
2. Add new alias entry:
   ```yaml
   aliases:
     myalias: api/v1/configmaps
   ```
3. Test with `dotfiles -t k9s`

### Creating Custom Plugins
1. Edit `files/plugins.yaml`
2. Add plugin definition:
   ```yaml
   plugins:
     my-plugin:
       shortCut: x              # Keyboard shortcut
       confirm: true            # Require confirmation
       description: "My Plugin"
       scopes:
         - pods                 # Available in pod views
       command: sh
       background: false
       args:
         - -c
         - "echo $COL-NAME"     # Your command here
   ```

### Theme Customization
1. Copy existing theme: `cp files/catppuccin_mocha.yaml files/custom_theme.yaml`
2. Modify colors as needed
3. Update `config.yaml`: `skin: custom_theme`
4. Test with `dotfiles -t k9s`

### Testing Configuration Changes
```bash
# Test syntax
k9s --dry-run

# Validate configuration
k9s --validate-config

# Check specific features
k9s --check-updates=false    # Skip version check during testing
```

### OS-Specific Customization
- Use templates for OS-specific configurations
- Leverage Ansible facts for conditional logic
- Test on all supported platforms

## Security Considerations

### RBAC Integration
- K9s respects Kubernetes RBAC policies
- Limited operations based on user permissions
- Clear indication of unauthorized actions

### Sensitive Data
- Logs may contain sensitive information
- Use `readOnly: true` in restricted environments
- Configure appropriate log retention policies

### Shell Pod Security
```yaml
shellPod:
  image: killerAdmin           # Use minimal debug images
  limits:                      # Resource constraints
    cpu: 100m
    memory: 100Mi
```

## Best Practices

### Workflow Optimization
1. **Use aliases** for frequently accessed resources
2. **Configure appropriate refresh rates** to balance performance
3. **Leverage plugins** for complex operations
4. **Master keyboard shortcuts** for efficiency

### Cluster Management
1. **Multi-context workflows** with quick context switching
2. **Resource filtering** for large clusters
3. **Log streaming** for real-time debugging
4. **Shell access** for direct container inspection

### Team Usage
1. **Consistent theming** across team members
2. **Shared plugin libraries** for common operations
3. **Documented shortcuts** and workflows
4. **Standardized configurations** for consistency

This comprehensive documentation ensures efficient Kubernetes cluster management through k9s while maintaining visual consistency with the Catppuccin theme ecosystem.