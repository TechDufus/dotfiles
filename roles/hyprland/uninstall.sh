#!/usr/bin/env bash
# Hyprland Uninstall Script
# Wraps JaKooLit's uninstall script and removes custom configurations

set -euo pipefail

INSTALLER_DIR="${HOME}/.cache/hyprland-installer"
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "24.04")

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Hyprland Uninstall Script${NC}"
echo ""
echo "This will:"
echo "  1. Run JaKooLit's official uninstall script"
echo "  2. Remove Hyprland configuration files"
echo "  3. Remove Waybar configuration files"
echo "  4. Clean up installer cache"
echo ""
echo -e "${RED}WARNING: This will completely remove Hyprland from your system${NC}"
echo ""

# User confirmation
read -p "Continue with removal? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

# Clone or update installer repository if needed
if [ ! -d "$INSTALLER_DIR" ]; then
    echo -e "${YELLOW}Cloning JaKooLit installer (branch: ${UBUNTU_VERSION})...${NC}"

    # Try version-specific branch first
    if ! git clone --branch "$UBUNTU_VERSION" \
        https://github.com/JaKooLit/Ubuntu-Hyprland.git \
        "$INSTALLER_DIR" 2>/dev/null; then

        echo -e "${YELLOW}Version branch not found, using main branch${NC}"
        git clone --branch main \
            https://github.com/JaKooLit/Ubuntu-Hyprland.git \
            "$INSTALLER_DIR"
    fi
fi

# Run JaKooLit's uninstall script
if [ -f "$INSTALLER_DIR/uninstall.sh" ]; then
    echo -e "${GREEN}Running JaKooLit uninstall script...${NC}"
    cd "$INSTALLER_DIR"
    chmod +x uninstall.sh

    # Run uninstall script with sudo
    if command -v sudo &> /dev/null && sudo -n true 2>/dev/null; then
        sudo ./uninstall.sh
    else
        echo -e "${RED}Error: Sudo access required for system package removal${NC}"
        echo "Please run with sudo or ensure you have sudo privileges"
        exit 1
    fi
else
    echo -e "${RED}Error: JaKooLit uninstall script not found${NC}"
    echo "Proceeding with configuration cleanup only..."
fi

# Remove custom configuration files
echo -e "${GREEN}Removing custom configurations...${NC}"

# Remove Hyprland configs (these are symlinks in dotfiles setup)
if [ -L "${HOME}/.config/hyprland/hyprland.conf" ] || [ -f "${HOME}/.config/hyprland/hyprland.conf" ]; then
    rm -f "${HOME}/.config/hyprland/hyprland.conf"
    echo "  ✓ Removed hyprland.conf"
fi

if [ -L "${HOME}/.config/hyprland/hyprlock.conf" ] || [ -f "${HOME}/.config/hyprland/hyprlock.conf" ]; then
    rm -f "${HOME}/.config/hyprland/hyprlock.conf"
    echo "  ✓ Removed hyprlock.conf"
fi

if [ -L "${HOME}/.config/hyprland/hypridle.conf" ] || [ -f "${HOME}/.config/hyprland/hypridle.conf" ]; then
    rm -f "${HOME}/.config/hyprland/hypridle.conf"
    echo "  ✓ Removed hypridle.conf"
fi

if [ -L "${HOME}/.config/hyprland/hyprpaper.conf" ] || [ -f "${HOME}/.config/hyprland/hyprpaper.conf" ]; then
    rm -f "${HOME}/.config/hyprland/hyprpaper.conf"
    echo "  ✓ Removed hyprpaper.conf"
fi

# Remove directory if empty
if [ -d "${HOME}/.config/hyprland" ]; then
    rmdir "${HOME}/.config/hyprland" 2>/dev/null && echo "  ✓ Removed hyprland config directory" || true
fi

# Remove Waybar configs (these are symlinks in dotfiles setup)
if [ -L "${HOME}/.config/waybar/config" ] || [ -f "${HOME}/.config/waybar/config" ]; then
    rm -f "${HOME}/.config/waybar/config"
    echo "  ✓ Removed waybar config"
fi

if [ -L "${HOME}/.config/waybar/style.css" ] || [ -f "${HOME}/.config/waybar/style.css" ]; then
    rm -f "${HOME}/.config/waybar/style.css"
    echo "  ✓ Removed waybar style"
fi

# Note: We don't remove the waybar directory as it might have other configs

# Remove Wayland flags from terminal configs
echo -e "${GREEN}Removing Wayland flags from terminal configs...${NC}"

if [ -f "${HOME}/.config/kitty/kitty.conf" ]; then
    sed -i '/^linux_display_server wayland$/d' "${HOME}/.config/kitty/kitty.conf"
    sed -i '/^wayland_titlebar_color background$/d' "${HOME}/.config/kitty/kitty.conf"
    echo "  ✓ Removed Wayland flags from Kitty config"
fi

if [ -f "${HOME}/.config/ghostty/config" ]; then
    sed -i '/^wayland-app-id = ghostty$/d' "${HOME}/.config/ghostty/config"
    echo "  ✓ Removed Wayland flags from Ghostty config"
fi

# Clean up installer cache
echo -e "${GREEN}Cleaning up installer cache...${NC}"
if [ -d "$INSTALLER_DIR" ]; then
    rm -rf "$INSTALLER_DIR"
    echo "  ✓ Removed installer cache"
fi

echo ""
echo -e "${GREEN}Hyprland uninstallation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Log out of your current session"
echo "  2. Select a different desktop environment at login"
echo "  3. (Optional) Reboot your system to ensure clean state"
echo ""
