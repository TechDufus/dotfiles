#!/usr/bin/env bash
# Cell Overlay - Visual display of cell layout
# Shows all cells and their assigned apps in rofi

# Get script directory and source manager functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/cell-manager.sh"

# Initialize state
init_state

# Generate cell overview
generate_overview() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║            CELL LAYOUT OVERVIEW                            ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║                                                            ║"

    # Group assignments by cell
    for cell in {1..6}; do
        # Get all apps assigned to this cell
        local apps
        apps=$(get_all_assignments | grep ":${cell}$" | cut -d: -f1 | tr '\n' ', ' | sed 's/,$//')

        if [ -n "$apps" ]; then
            # Get cell dimensions
            local dims
            dims=$(get_cell_dimensions "$cell")
            local size
            size=$(echo "$dims" | awk '{print $3" "$4}')

            # Format with proper padding
            printf "║ Cell %d [%s]: %-42s ║\n" "$cell" "$size" "$apps"
        fi
    done

    echo "║                                                            ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║ Press F13+V to view | F13+R to reassign                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
}

# Show with temporary assignments
show_temp_assignments() {
    if [ -f "$STATE_FILE" ]; then
        local temp_count
        temp_count=$(jq -r '.temporary | length' "$STATE_FILE" 2>/dev/null)

        if [ "$temp_count" -gt 0 ]; then
            echo ""
            echo "Temporary Assignments (this session):"
            jq -r '.temporary | to_entries[] | "  \(.key) → Cell \(.value)"' "$STATE_FILE" 2>/dev/null
        fi
    fi
}

# Generate full output
overview=$(generate_overview)
temp_info=$(show_temp_assignments)

# Show in rofi
if [ -n "$temp_info" ]; then
    full_output="$overview\n\n$temp_info"
else
    full_output="$overview"
fi

echo -e "$full_output" | rofi -dmenu -p "Cell Layout" -theme-str 'window {width: 700px;} listview {lines: 15;}'
