#!/usr/bin/env bash
# AwesomeWM Cell Management Uninstall Script

set -e

echo "Uninstalling AwesomeWM Cell Management..."

# Remove configuration files
if [ -d "$HOME/.config/awesome/cell-management" ]; then
  echo "Removing cell-management configuration..."
  rm -rf "$HOME/.config/awesome/cell-management"
fi

if [ -f "$HOME/.config/awesome/rc.lua" ]; then
  echo "NOTE: rc.lua not removed automatically (may contain custom config)"
  echo "      Backup location: $HOME/.config/awesome/rc.lua.backup"
  cp "$HOME/.config/awesome/rc.lua" "$HOME/.config/awesome/rc.lua.backup"
fi

# Optionally remove AwesomeWM package (commented out for safety)
# sudo apt remove awesome xdotool

echo " Cell management configuration removed"
echo " rc.lua backed up to rc.lua.backup"
echo ""
echo "To completely remove AwesomeWM:"
echo "  sudo apt remove awesome xdotool"
echo ""
echo "To remove configuration directory:"
echo "  rm -rf ~/.config/awesome"
