# GitHub Release Role

A reusable Ansible role for downloading and installing binaries from GitHub releases.

## Features

- Automatically detects latest release or installs specific version
- Smart asset selection based on OS and architecture
- Supports multiple archive formats (tar.gz, zip, deb, rpm, AppImage, direct binary)
- Version checking to avoid unnecessary downloads
- Configurable installation paths and permissions
- Cleanup of temporary files

## Usage

### Basic Example

```yaml
- name: Install tool from GitHub
  ansible.builtin.include_role:
    name: github-release
  vars:
    github_release_repo: "owner/repository"
    github_release_binary_name: "tool-name"
```

### Advanced Example

```yaml
- name: Install specific version with custom settings
  ansible.builtin.include_role:
    name: github-release
  vars:
    github_release_repo: "derailed/k9s"
    github_release_binary_name: "k9s"
    github_release_tag: "v0.27.4"  # Specific version
    github_release_install_path: "/opt/bin"
    github_release_check_command: "k9s version -s"
    github_release_version_pattern: "v[0-9]+\\.[0-9]+\\.[0-9]+"
    github_release_owner: "{{ ansible_user_id }}"
    github_release_group: "{{ ansible_user_id }}"
```

## Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `github_release_repo` | GitHub repository in owner/repo format | `"cli/cli"` |
| `github_release_binary_name` | Name of the binary to install | `"gh"` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `github_release_tag` | `"latest"` | Release tag to install ("latest" or specific tag) |
| `github_release_install_path` | `"/usr/local/bin"` | Installation directory |
| `github_release_install_mode` | `"0755"` | File permissions for installed binary |
| `github_release_check_command` | `"{{ binary }} --version"` | Command to check installed version |
| `github_release_version_pattern` | `"[0-9]+\\.[0-9]+\\.[0-9]+"` | Regex to extract version |
| `github_release_force_install` | `false` | Force reinstall even if already installed |
| `github_release_asset_name_pattern` | `""` | Specific pattern to match asset name |
| `github_release_asset_type` | `"auto"` | Asset type (auto, tar.gz, zip, deb, rpm, binary, AppImage) |
| `github_release_become` | `true` | Use sudo for installation |
| `github_release_owner` | `"root"` | Owner of installed file |
| `github_release_group` | `"root"` | Group of installed file |
| `github_release_cleanup` | `true` | Clean up downloaded files |
| `github_release_strip_components` | `1` | Strip directory levels for tar archives |

## Asset Selection

The role automatically selects the appropriate asset based on:

1. Operating System (Linux, Darwin/macOS, Windows)
2. Architecture (x86_64/amd64, aarch64/arm64, etc.)
3. Asset type preference (tar.gz > zip > deb > AppImage > binary)

You can override automatic selection by specifying:
- `github_release_asset_name_pattern` - Regex pattern to match specific asset
- `github_release_asset_type` - Force specific asset type

## Examples

### Simple Binary Installation

```yaml
# Install lazygit
- name: Install lazygit
  ansible.builtin.include_role:
    name: github-release
  vars:
    github_release_repo: "jesseduffield/lazygit"
    github_release_binary_name: "lazygit"
```

### Debian Package Installation

```yaml
# Install bat (uses .deb for Ubuntu/Debian)
- name: Install bat
  ansible.builtin.include_role:
    name: github-release
  vars:
    github_release_repo: "sharkdp/bat"
    github_release_binary_name: "bat"
    github_release_asset_type: "deb"  # Force .deb package
```

### Custom Asset Pattern

```yaml
# Install tool with specific asset naming
- name: Install custom tool
  ansible.builtin.include_role:
    name: github-release
  vars:
    github_release_repo: "owner/repo"
    github_release_binary_name: "tool"
    github_release_asset_name_pattern: "tool-.*-linux-musl\\.tar\\.gz"
```

### User-Local Installation

```yaml
# Install to user directory without sudo
- name: Install to user directory
  ansible.builtin.include_role:
    name: github-release
  vars:
    github_release_repo: "owner/repo"
    github_release_binary_name: "tool"
    github_release_install_path: "{{ ansible_user_dir }}/.local/bin"
    github_release_become: false
    github_release_owner: "{{ ansible_user_id }}"
    github_release_group: "{{ ansible_user_id }}"
```

## Supported Asset Types

- **tar.gz** - Extracts archive and finds binary
- **zip** - Extracts archive and finds binary  
- **deb** - Installs using apt (Debian/Ubuntu)
- **rpm** - Installs using dnf/yum (RedHat/Fedora)
- **AppImage** - Copies directly as executable
- **binary** - Direct binary file (no archive)

## Error Handling

The role will fail with descriptive messages when:
- Required variables are not provided
- No matching asset found for OS/architecture
- Binary not found in extracted archive
- Version check command fails
- Installation permissions denied

## Performance

The role includes several optimizations:
- Checks current version before downloading
- Uses GitHub API efficiently
- Cleans up temporary files
- Supports caching through Ansible facts