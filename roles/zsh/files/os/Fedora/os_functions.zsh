#!/usr/bin/env zsh

# Fedora/DNF specific package management aliases
alias update='sudo dnf upgrade -y && sudo dnf autoremove -y && sudo dnf clean all'
# Flatpak integration (common on Fedora)
if command -v flatpak &> /dev/null; then
    alias update='sudo dnf upgrade -y && sudo dnf autoremove -y && sudo dnf clean all && flatpak update -y'
fi


# Function to clean system caches and temp files
clean-system() {
    echo "Cleaning DNF cache..."
    sudo dnf clean all

    echo "Cleaning journal logs older than 3 days..."
    sudo journalctl --vacuum-time=3d

    echo "Cleaning temporary files..."
    sudo rm -rf /tmp/* /var/tmp/*

    if command -v flatpak &> /dev/null; then
        echo "Cleaning unused Flatpak runtimes..."
        flatpak uninstall --unused -y
    fi

    echo "System cleanup complete!"
}

