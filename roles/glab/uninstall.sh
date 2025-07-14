#!/usr/bin/env bash

# Get the absolute path of the dotfiles root directory
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the functions script
# shellcheck source=/dev/null
source "$DOTFILES_ROOT/bin/functions"

__task "Uninstalling GitLab CLI (glab)"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null && brew list glab &> /dev/null; then
        _cmd "brew uninstall glab"
    fi
elif [[ -f /etc/fedora-release ]]; then
    # Fedora
    if command -v glab &> /dev/null; then
        if rpm -q glab &> /dev/null; then
            _cmd "sudo dnf remove -y glab"
            # Remove the repository file
            if [[ -f /etc/yum.repos.d/glab.repo ]]; then
                _cmd "sudo rm -f /etc/yum.repos.d/glab.repo"
            fi
        else
            # Installed via github_release
            _cmd "sudo rm -f /usr/local/bin/glab"
        fi
    fi
elif [[ -f /etc/arch-release ]]; then
    # Arch Linux
    if pacman -Q gitlab-glab &> /dev/null; then
        _cmd "sudo pacman -R --noconfirm gitlab-glab"
    fi
elif [[ -f /etc/debian_version ]]; then
    # Ubuntu/Debian
    if command -v glab &> /dev/null; then
        # Likely installed via github_release
        _cmd "sudo rm -f /usr/local/bin/glab"
    fi
fi

# Prompt before removing configuration
if [[ -d "$HOME/.config/glab-cli" ]]; then
    echo ""
    read -p "Remove GitLab CLI configuration files? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _cmd "rm -rf $HOME/.config/glab-cli"
    else
        echo "Configuration files retained at: $HOME/.config/glab-cli"
    fi
fi

# Remove any authentication tokens
if [[ -f "$HOME/.config/glab-cli/config.yml" ]]; then
    echo ""
    echo "Note: GitLab authentication tokens may be stored in your system keychain."
    echo "You may want to remove them manually if you're completely removing glab."
fi

_task_done "GitLab CLI (glab) uninstalled"