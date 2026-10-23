#!/usr/bin/env bash
set -uo pipefail

dest="$HOME/.task/completions/task.bash"
url="https://raw.githubusercontent.com/go-task/task/main/completion/bash/task.bash"

[ -e "$dest" ] && exit 0

tmp="$(mktemp)"
if mkdir -p "$(dirname "$dest")" && curl -fsSL -o "$tmp" "$url" && mv "$tmp" "$dest"; then
  chmod 0644 "$dest"
else
  rm -f "$tmp"
  echo "taskfile: task bash completion download failed, skipped"
fi
exit 0
