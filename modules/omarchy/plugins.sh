#!/usr/bin/env bash
# Puts $OMARCHY_BAR_PLUGINS (cloned by [bootstrap.repos]) in the Omarchy bar and takes
# $OMARCHY_HIDDEN_PLUGINS out of it, once per value of the two lists: a later change in the bar
# stays until a list in mise.omarchy.toml changes. Fail-soft.
set -uo pipefail

read -ra bar <<<"${OMARCHY_BAR_PLUGINS:-}"
read -ra hidden <<<"${OMARCHY_HIDDEN_PLUGINS:-}"
(( ${#bar[@]} + ${#hidden[@]} > 0 )) || exit 0
want="bar=${bar[*]} hidden=${hidden[*]}"
marker=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/omarchy-plugins
[ "$(cat "$marker" 2>/dev/null)" != "$want" ] || exit 0

# The running shell enables and disables plugins and rewrites shell.json itself.
if [ "$(omarchy-shell shell ping 2>/dev/null)" != ok ]; then
  echo "omarchy-plugins: Omarchy shell not running, skipped"
  exit 0
fi

plugins_dir=$HOME/.config/omarchy/plugins
# A bar widget reports enabled only while it sits in the bar.
in_bar() {
  omarchy-plugin-list --json 2>/dev/null | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}
# A rescan loads plugins asynchronously; wait briefly for the shell to know the id.
known() {
  local attempt
  for ((attempt = 0; attempt < 40; attempt++)); do
    omarchy-plugin-list --json 2>/dev/null | jq -e --arg id "$1" 'any(.[]; .id == $id)' >/dev/null && return 0
    sleep 0.05
  done
  return 1
}

ok=1
for id in "${hidden[@]}"; do
  in_bar "$id" || continue
  if omarchy-plugin-disable "$id" >/dev/null; then
    echo "omarchy-plugins: took $id out of the bar"
  else
    echo "omarchy-plugins: disabling $id failed, skipped"
    ok=0
  fi
done

(( ${#bar[@]} == 0 )) || omarchy-shell shell rescanPlugins >/dev/null 2>&1
for id in "${bar[@]}"; do
  # [bootstrap.repos] clones without the validation `omarchy plugin add` runs.
  if ! omarchy-plugin-validate "$plugins_dir/$id"; then
    echo "omarchy-plugins: $id is missing or invalid in $plugins_dir, skipped"
    ok=0
    continue
  fi
  in_bar "$id" && continue
  if known "$id" && omarchy-plugin-enable "$id" >/dev/null; then
    echo "omarchy-plugins: put $id in the bar"
  else
    echo "omarchy-plugins: enabling $id failed, skipped"
    ok=0
  fi
done

if [ "$ok" = 1 ]; then
  mkdir -p "${marker%/*}" && printf '%s\n' "$want" >"$marker"
fi
exit 0
