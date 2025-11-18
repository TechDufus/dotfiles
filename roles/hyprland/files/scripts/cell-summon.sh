#!/usr/bin/env bash
# Cell Summon - Focus or launch app in assigned cell
# Enhanced version of focus-or-launch.sh with cell-based positioning

# Get script directory and source manager functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cell-manager.sh"

APP_CLASS="$1"
APP_COMMAND="${2:-$1}"  # Default to class name if no command given

# Initialize state
init_state

# Get cell assignment for this app
CELL=$(get_cell_for_app "$APP_CLASS")

if [ -z "$CELL" ]; then
    # No cell assigned, use standard focus-or-launch behavior
    if hyprctl clients -j | jq -e ".[] | select(.class == \"$APP_CLASS\")" > /dev/null 2>&1; then
        # Focus existing window
        hyprctl dispatch focuswindow "class:^($APP_CLASS)$"
    else
        # Launch without cell positioning
        hyprctl dispatch exec "$APP_COMMAND"
    fi
    exit 0
fi

# Get cell dimensions
DIMS=$(get_cell_dimensions "$CELL")

if [ -z "$DIMS" ]; then
    echo "Error: Cell $CELL not found in definitions"
    notify-send "Cell Error" "Cell $CELL not defined"
    exit 1
fi

# Parse dimensions
MOVE=$(echo "$DIMS" | cut -d' ' -f1-2)
SIZE=$(echo "$DIMS" | cut -d' ' -f3-4)

# Check if app is already running
# Use a more robust check that handles any case variations
APP_EXISTS=$(hyprctl clients -j | jq -r --arg class "$APP_CLASS" '.[] | select(.class == $class) | .class' | head -n1)

if [ -n "$APP_EXISTS" ]; then
    # App is running - check if it's on current workspace
    CURRENT_WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.id')
    APP_WORKSPACE=$(hyprctl clients -j | jq -r --arg class "$APP_CLASS" '.[] | select(.class == $class) | .workspace.id' | head -n1)

    # If on different workspace, move it to current workspace
    if [ "$APP_WORKSPACE" != "$CURRENT_WORKSPACE" ]; then
        hyprctl dispatch movetoworkspacesilent "$CURRENT_WORKSPACE,class:^($APP_CLASS)$"
    fi

    # Focus the window and bring to front
    hyprctl dispatch focuswindow "class:^($APP_CLASS)$"

    # Bring window to front (important for floating windows like Discord)
    hyprctl dispatch bringactivetotop

    # Also ensure it's in the correct position (in case it was moved)
    hyprctl --batch "dispatch resizewindowpixel exact $SIZE,class:^($APP_CLASS)$; dispatch movewindowpixel exact $MOVE,class:^($APP_CLASS)$" 2>/dev/null
else
    # App not running - launch in cell position
    hyprctl dispatch exec "[float;move $MOVE;size $SIZE] $APP_COMMAND"
fi
