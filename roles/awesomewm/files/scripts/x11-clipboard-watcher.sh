#!/bin/bash
# X11 Clipboard Watcher for cliphist
# Monitors X11 clipboard and feeds changes to cliphist

POLL_INTERVAL=0.5  # seconds between checks
LAST_HASH=""
CLIPHIST_DB="$HOME/.cache/cliphist/db"

# Ensure cliphist directory exists
mkdir -p "$(dirname "$CLIPHIST_DB")"

# Function to get clipboard hash (for change detection)
get_clipboard_hash() {
  xclip -selection clipboard -o 2>/dev/null | md5sum | cut -d' ' -f1
}

# Function to store clipboard content
store_clipboard() {
  # Try to get image first
  if xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -q image; then
    # Image in clipboard
    local mime_type=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep image | head -1)
    xclip -selection clipboard -t "$mime_type" -o 2>/dev/null | \
      cliphist store
  else
    # Text in clipboard
    xclip -selection clipboard -o 2>/dev/null | cliphist store
  fi
}

# Main monitoring loop
while true; do
  CURRENT_HASH=$(get_clipboard_hash)

  if [[ "$CURRENT_HASH" != "$LAST_HASH" ]] && [[ -n "$CURRENT_HASH" ]]; then
    store_clipboard
    LAST_HASH="$CURRENT_HASH"
  fi

  sleep "$POLL_INTERVAL"
done
