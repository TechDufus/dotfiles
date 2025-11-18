#!/usr/bin/env bash
# Cell Manager - Shared functions for cell-based window management
# Used by cell-summon, cell-overlay, cell-reassign, and cell-generate-rules

CELL_DIR="$HOME/.config/hypr/cells"
STATE_FILE="$CELL_DIR/state.json"

# Initialize state file if not exists
init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        echo '{"temporary":{}}' > "$STATE_FILE"
    fi
}

# Get cell number for app class
get_cell_for_app() {
    local app_class="$1"

    # Check temporary assignments first (session-specific)
    if [ -f "$STATE_FILE" ]; then
        local temp_cell
        temp_cell=$(jq -r ".temporary[\"$app_class\"] // empty" "$STATE_FILE" 2>/dev/null)
        if [ -n "$temp_cell" ]; then
            echo "$temp_cell"
            return 0
        fi
    fi

    # Check permanent assignments
    if [ -f "$CELL_DIR/assignments.conf" ]; then
        grep -E "^${app_class}:" "$CELL_DIR/assignments.conf" 2>/dev/null | cut -d: -f3
    fi
}

# Get cell dimensions (move and size)
get_cell_dimensions() {
    local cell_num="$1"

    # Source definitions and get values
    if [ -f "$CELL_DIR/definitions.conf" ]; then
        # shellcheck disable=SC1090
        source "$CELL_DIR/definitions.conf"

        local move_var="CELL_${cell_num}_MOVE"
        local size_var="CELL_${cell_num}_SIZE"

        # Use parameter expansion to get values
        local move="${!move_var}"
        local size="${!size_var}"

        if [ -n "$move" ] && [ -n "$size" ]; then
            echo "$move $size"
            return 0
        fi
    fi

    # Return empty if cell not found
    return 1
}

# Get summon key for app class
get_summon_key_for_app() {
    local app_class="$1"

    if [ -f "$CELL_DIR/assignments.conf" ]; then
        grep -E "^${app_class}:" "$CELL_DIR/assignments.conf" 2>/dev/null | cut -d: -f2
    fi
}

# Get all assigned apps
get_all_assignments() {
    if [ -f "$CELL_DIR/assignments.conf" ]; then
        grep -v '^#' "$CELL_DIR/assignments.conf" | grep -v '^$'
    fi
}

# Save temporary assignment
save_temp_assignment() {
    local app_class="$1"
    local cell_num="$2"

    init_state

    # Update state file with jq
    local temp_file
    temp_file=$(mktemp)
    jq ".temporary[\"$app_class\"] = \"$cell_num\"" "$STATE_FILE" > "$temp_file"
    mv "$temp_file" "$STATE_FILE"
}

# Clear temporary assignment
clear_temp_assignment() {
    local app_class="$1"

    if [ -f "$STATE_FILE" ]; then
        local temp_file
        temp_file=$(mktemp)
        jq "del(.temporary[\"$app_class\"])" "$STATE_FILE" > "$temp_file"
        mv "$temp_file" "$STATE_FILE"
    fi
}

# Clear all temporary assignments
clear_all_temp_assignments() {
    if [ -f "$STATE_FILE" ]; then
        echo '{"temporary":{}}' > "$STATE_FILE"
    fi
}
