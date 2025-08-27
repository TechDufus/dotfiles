# Ghostty Terminal Role

## Overview

The **Ghostty** role configures **Ghostty**, a modern GPU-accelerated terminal emulator written in Zig by Mitchell Hashimoto. This role sets up a highly customized terminal environment with advanced visual effects, custom shaders, and performance optimizations tailored for modern development workflows.

## Key Features

- **GPU Acceleration**: Leverages GPU for smooth rendering and animations
- **Custom Cursor Shaders**: Advanced visual effects for cursor movement
- **Background Images**: Support for custom background images with opacity control
- **Cross-Platform Configuration**: Currently supports macOS with extensible architecture
- **Catppuccin Theme**: Integrated Catppuccin Mocha color scheme
- **Advanced Typography**: BerkeleyMono Nerd Font with enhanced rendering

## Architecture

### Current Platform Support
- **macOS**: Full support with Homebrew Cask installation (`ghostty@tip` for nightly builds)
- **Linux**: Architecture ready but not yet implemented
- **Windows**: Architecture ready but not yet implemented

### Configuration Structure
```
roles/ghostty/
├── files/
│   ├── config                    # Main Ghostty configuration
│   └── shaders/                  # Custom GLSL shaders
│       ├── cursor_blaze.glsl     # Electric trail effect
│       └── cursor_smear.glsl     # Smooth trailing effect
├── tasks/
│   ├── main.yml                  # OS detection pattern
│   └── MacOSX.yml               # macOS installation tasks
└── uninstall.sh                 # Clean removal script
```

## Configuration Deep Dive

### Core Settings (`files/config`)

#### Theme and Appearance
```ini
theme = catppuccin-mocha          # Base color scheme
background = #030304              # Custom darker background
background-opacity = 1           # Solid background
background-blur-radius = 20      # Blur effect radius
```

#### Background Image Configuration
```ini
# Requires nightly version of ghostty
background-image = ~/OneDrive/Pictures/code-bgs/4k/sukuna-electric-3840x2160-22504.jpg
background-image-opacity = 0.5   # 50% transparency
background-image-fit = cover     # Maintain aspect ratio
```

#### Typography Settings
```ini
font-size = 20                   # Large, readable size
font-family = "BerkeleyMono Nerd Font"  # Professional monospace with icons
font-thicken = true             # Enhanced font rendering
bold-is-bright = true           # Bright colors for bold text
```

#### Window Behavior
```ini
macos-titlebar-style = hidden    # Clean, minimal interface
macos-option-as-alt = true      # Natural macOS key behavior
window-decoration = true        # Native window decorations
window-padding-x = 10           # Horizontal padding
window-padding-y = 10           # Vertical padding
window-padding-balance = true   # Balanced padding distribution
```

#### Cursor Configuration
```ini
cursor-style = block            # Block cursor style
cursor-style-blink = true       # Animated blinking
cursor-invert-fg-bg = true      # High contrast cursor
custom-shader = shaders/cursor_blaze.glsl  # Custom visual effect
mouse-hide-while-typing = true  # Clean typing experience
```

#### System Integration
```ini
clipboard-read = allow          # System clipboard access
clipboard-write = allow         # System clipboard writing
copy-on-select = true          # Automatic copying on text selection
auto-update = check            # Check for updates
auto-update-channel = tip      # Use nightly builds
shell-integration-features = no-cursor  # Disable shell cursor management
```

## Custom Shaders

### Cursor Blaze (`cursor_blaze.glsl`)

A sophisticated electric trail effect that creates a glowing, animated trail behind the cursor as it moves.

**Key Features:**
- **Electric Cyan Trail**: Bright blue-cyan color scheme matching the electric theme
- **Dynamic Animation**: Uses time-based animations with easing functions
- **Parallelogram Trail**: Creates connected trail segments between cursor positions
- **Distance-Based Opacity**: Trail fades based on distance and time
- **Anti-aliasing**: Smooth edges for professional appearance

**Technical Implementation:**
- Uses signed distance fields (SDF) for precise geometric calculations
- Implements Inigo Quilez's 2D distance functions for optimization
- Electric cyan colors: `vec4(0.0, 0.878, 1.0, 1.0)` with accent variations
- 200ms duration for smooth transitions
- Advanced blending functions for realistic motion blur

### Cursor Smear (`cursor_smear.glsl`)

A subtle, smooth trailing effect that provides gentle visual feedback for cursor movement.

**Key Features:**
- **Catppuccin Integration**: Uses Sapphire blue from Catppuccin Mocha palette
- **Multiple Color Options**: Commented alternatives for easy customization
- **Shorter Duration**: 120ms for snappy, responsive feel
- **Simplified Animation**: Cleaner, more minimal effect
- **Performance Optimized**: Reduced complexity for better performance

**Color Palette Options:**
```glsl
// Available Catppuccin Mocha colors
Sapphire: vec4(0.455, 0.780, 0.925, 1.0)  // Default
Pink:     vec4(0.961, 0.761, 0.906, 1.0)  
Mauve:    vec4(0.796, 0.651, 0.969, 1.0)  
Red:      vec4(0.953, 0.545, 0.659, 1.0)  
Green:    vec4(0.651, 0.890, 0.631, 1.0)  
// ... and more
```

## Performance Tuning

### GPU Optimization
- **Hardware Acceleration**: Utilizes Metal (macOS) for rendering
- **Shader Performance**: Optimized GLSL code with minimal branching
- **Memory Efficiency**: Smart texture management for background images
- **Frame Rate**: Maintains 60+ FPS with effects enabled

### Font Rendering
- **Font Thickening**: Enhanced glyph rendering for better readability
- **Nerd Font Support**: Full icon and symbol support for development
- **Subpixel Rendering**: Platform-native text rendering optimizations

### Background Processing
- **Blur Radius**: Configurable blur for performance vs. quality balance
- **Image Scaling**: Efficient cover fitting for various screen sizes
- **Opacity Blending**: Hardware-accelerated alpha compositing

## Integration with Development Tools

### Shell Integration
- **No-Cursor Mode**: Prevents shell from interfering with custom cursor effects
- **Clipboard Integration**: Seamless copy/paste with system clipboard
- **Auto-Select**: Productivity feature for quick text selection

### Terminal Features
- **True Color Support**: 24-bit color for accurate theme rendering
- **Unicode Support**: Full emoji and special character support
- **Fast Scrolling**: GPU-accelerated scrollback buffer

### macOS Integration
- **Native Window Management**: Uses macOS window system
- **Option Key Handling**: Natural Alt key behavior for text editing
- **System Notifications**: Update notifications through macOS

## Customization Guide

### Changing Cursor Effects
1. Switch between shaders by modifying the `custom-shader` line in `config`
2. Available options:
   - `shaders/cursor_blaze.glsl` - Electric trail effect
   - `shaders/cursor_smear.glsl` - Smooth trailing effect
   - Comment out for no effect

### Background Customization
1. **Custom Images**: Replace the `background-image` path
2. **Opacity Adjustment**: Modify `background-image-opacity` (0.0-1.0)
3. **Fit Options**: `cover`, `contain`, `stretch`, `tile`
4. **Blur Effects**: Adjust `background-blur-radius` for depth

### Font Modifications
1. **Size**: Adjust `font-size` for readability preferences
2. **Family**: Change `font-family` to any installed monospace font
3. **Rendering**: Toggle `font-thicken` for different font weights

### Color Scheme Modifications
1. **Base Theme**: Change `theme` to any supported Ghostty theme
2. **Background Override**: Modify `background` hex value
3. **Shader Colors**: Edit color constants in shader files

## Platform-Specific Considerations

### macOS-Specific Features
- **Homebrew Integration**: Uses `ghostty@tip` for latest features
- **Titlebar Management**: Hidden titlebar for clean interface
- **Option Key Behavior**: Configured for natural macOS Alt key usage
- **System Integration**: Native clipboard and notification support

### Nightly Build Requirements
- Background image support requires nightly builds
- Auto-update configured for `tip` channel
- Custom shaders may require recent features

### File Permissions
- Configuration directory: `~/.config/ghostty/` with 755 permissions
- Config file: 644 permissions for user read/write
- Shader directory: 755 permissions with 644 for shader files

## Troubleshooting

### Common Issues

#### Background Image Not Loading
- **Cause**: Path not found or permission issues
- **Solution**: Verify file path and permissions
- **Alternative**: Use absolute paths or move image to user directory

#### Shader Effects Not Working
- **Cause**: Older Ghostty version or GPU compatibility
- **Solution**: Update to nightly build, check GPU support
- **Fallback**: Comment out `custom-shader` line

#### Font Rendering Issues
- **Cause**: Font not installed or permission issues
- **Solution**: Install BerkeleyMono Nerd Font through Homebrew
- **Alternative**: Use system monospace font

#### Performance Issues
- **Cause**: Complex shaders on older hardware
- **Solution**: Disable custom shaders, reduce blur radius
- **Optimization**: Lower background image resolution

### Debugging Steps
1. **Version Check**: Ensure using nightly build (`ghostty@tip`)
2. **Config Validation**: Check syntax with Ghostty's config validator
3. **GPU Support**: Verify Metal/OpenGL support on system
4. **File Permissions**: Check all config files are readable

### Legacy Configuration Support
The uninstall script handles both:
- Modern config location: `~/.config/ghostty/`
- Legacy location: `~/Library/Application Support/com.mitchellh.ghostty`

## Development Guidelines

### Adding New Shaders
1. Create `.glsl` file in `files/shaders/` directory
2. Follow existing shader structure with `mainImage` function
3. Use Ghostty's built-in variables (`iCurrentCursor`, `iPreviousCursor`, etc.)
4. Test performance across different hardware
5. Document color schemes and customization options

### Extending Platform Support
1. Create OS-specific task file (e.g., `Ubuntu.yml`)
2. Add package installation tasks using appropriate package manager
3. Handle OS-specific configuration differences
4. Update uninstall script with new OS detection
5. Test configuration deployment and symlink creation

### Configuration Best Practices
- **Comments**: Document complex settings and their effects
- **Performance**: Balance visual effects with system performance  
- **Compatibility**: Test with various Ghostty versions
- **Accessibility**: Consider high contrast and readability needs
- **Modularity**: Keep platform-specific settings separate

### Testing New Configurations
1. **Backup**: Save current configuration before changes
2. **Incremental**: Test one feature at a time
3. **Performance**: Monitor GPU usage and frame rates
4. **Cross-Platform**: Test on supported operating systems
5. **Rollback**: Ensure easy reversion for problematic changes

## Future Enhancements

### Planned Features
- Linux support with native package management
- Windows support with appropriate installation methods
- Additional shader effects and animation options
- Dynamic theme switching based on system preferences
- Integration with other dotfiles roles (tmux, neovim colors)

### Shader Development
- Seasonal cursor effects
- Productivity-focused minimal effects  
- Performance-optimized versions for older hardware
- Interactive effects based on typing patterns
- Integration with terminal content (syntax highlighting colors)

### Configuration Extensions
- Multi-monitor support optimizations
- Workspace-specific configurations
- Time-based automatic theme switching
- Integration with macOS appearance modes
- Custom key binding configurations

This comprehensive setup makes Ghostty not just a terminal emulator, but a visually stunning and highly functional development environment centerpiece.