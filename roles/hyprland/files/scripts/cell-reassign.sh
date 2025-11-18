#!/usr/bin/env bash
# Cell Reassign - Dynamically reassign windows to different cells
# Provides interactive rofi interface for reassignment

# Get script directory and source manager functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cell-manager.sh"

# Initialize state
init_state

# Step 1: Select app from running windows
apps=$(hyprctl clients -j | jq -r '.[].class' | sort -u)

if [ -z "$apps" ]; then
    notify-send "Cell Reassign" "No windows currently open"
    exit 0
fi

selected_app=$(echo "$apps" | rofi -dmenu -p "Select App to Reassign" -theme-str 'window {width: 400px;}')

if [ -z "$selected_app" ]; then
    exit 0
fi

# Step 2: Select target cell
cells="Cell 1: Left Primary (65% × 100%)
Cell 2: Right Side (35% × 100%)
Cell 3: Top-Right Float (35% × 50%)
Cell 4: Center-Left Float (55% × 75%)
Cell 5: Large Centered (75% × 75%)
Cell 6: Small Right Popup (37.5% × 60%)
Clear Assignment (free float)"

selected_line=$(echo "$cells" | rofi -dmenu -p "Select Target Cell" -theme-str 'window {width: 500px;}')

if [ -z "$selected_line" ]; then
    exit 0
fi

# Parse cell number from selection
if [[ "$selected_line" == "Clear Assignment"* ]]; then
    # Clear temporary assignment and restore to default
    clear_temp_assignment "$selected_app"
    notify-send "Cell Reassign" "$selected_app assignment cleared"
    exit 0
fi

selected_cell=$(echo "$selected_line" | grep -o '^Cell [0-9]' | grep -o '[0-9]')

if [ -z "$selected_cell" ]; then
    notify-send "Cell Reassign" "Invalid cell selection"
    exit 1
fi

# Step 3: Update temporary state
save_temp_assignment "$selected_app" "$selected_cell"

# Step 4: Move window immediately
dims=$(get_cell_dimensions "$selected_cell")

if [ -z "$dims" ]; then
    notify-send "Cell Reassign" "Error: Cell $selected_cell not defined"
    exit 1
fi

move=$(echo "$dims" | cut -d' ' -f1-2)
size=$(echo "$dims" | cut -d' ' -f3-4)

# Apply new position
hyprctl --batch "dispatch resizewindowpixel exact $size,class:^($selected_app)$; dispatch movewindowpixel exact $move,class:^($selected_app)$" 2>/dev/null

notify-send "Cell Reassigned" "$selected_app moved to Cell $selected_cell (temporary)"
