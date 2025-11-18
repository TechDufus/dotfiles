#!/usr/bin/env bash
# Focus-or-launch script for Hyprland
# Mimics Hammerspoon behavior: focus existing app or launch if not running

APP_CLASS="$1"
APP_COMMAND="$2"
POSITION="${3:-}"  # Optional position override

# Check if app is running
if hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_CLASS\")" > /dev/null 2>&1; then
    # App is running - focus it
    hyprctl dispatch focuswindow "class:^($APP_CLASS)$"
else
    # App not running - launch it
    if [ -n "$POSITION" ]; then
        # Launch with specific position
        hyprctl dispatch exec "[float;move $POSITION] $APP_COMMAND"
    else
        # Launch normally (window rules will position it)
        hyprctl dispatch exec "$APP_COMMAND"
    fi
fi
