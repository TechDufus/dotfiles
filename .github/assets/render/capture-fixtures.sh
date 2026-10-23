#!/usr/bin/env bash
# Regenerates fixtures/ from read-only mise queries. render.py does NOT need this
# (the fixtures are committed); run it only to refresh them after the modules change.
#
#   plan.json, dot.json, tasks   `mise bootstrap plan --json`, `mise dot status --json`,
#                                `mise tasks ls --name-only` against the real HOME. All three
#                                only read; the JSON is reduced to the fields bin/dotfiles uses
#                                (no paths).
#   dry-<stage>.txt              `mise bootstrap --dry-run --only <parts>` against an isolated,
#                                empty HOME (a fresh-machine rehearsal, MISE_OFFLINE=1), with
#                                the temporary prefixes rewritten to /home/techdufus. Offline
#                                mise cannot resolve versions, so dry-tools.txt is built from
#                                `mise ls --json` in mise's "<tool>@<version> ⇢ would install"
#                                format and the offline version warnings are dropped.
#
# Never touches the real HOME's config, state or packages.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
fx=$here/fixtures
mkdir -p "$fx"

cd "$HOME"
mise bootstrap plan --json | jq -c '{resources: [.resources[] | {id, action}]}' >"$fx/plan.json"
mise dot status --json | jq -c '{files: [(.files // [])[] | {state}], edits: [(.edits // [])[] | {state}]}' >"$fx/dot.json"
mise tasks ls --name-only >"$fx/tasks"

sb=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fixtures.XXXXXX")
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/home" "$sb/mise" "$sb/data" "$sb/state" "$sb/cache"
ln -s "$repo/modules" "$sb/mise/conf.d"
printf 'auto_env = true\nenv = ["omarchy", "personal"]' >"$sb/mise/miserc.local.toml"

dry() { # dry <fixture name> <parts>
  (cd "$sb/home" && env -i HOME="$sb/home" PATH="$PATH" TERM=dumb NO_COLOR=1 \
    XDG_CONFIG_HOME="$sb/home/.config" XDG_DATA_HOME="$sb/data" XDG_STATE_HOME="$sb/state" XDG_CACHE_HOME="$sb/cache" \
    MISE_CONFIG_DIR="$sb/mise" MISE_DATA_DIR="$sb/data/mise" MISE_STATE_DIR="$sb/state/mise" MISE_CACHE_DIR="$sb/cache/mise" \
    MISE_OFFLINE=1 MISE_TASK_RUN_AUTO_INSTALL=0 MISE_TRUSTED_CONFIG_PATHS="$sb" \
    mise bootstrap --yes --dry-run --only "$2" 2>&1 || true) |
    sed "s#$sb/mise#/home/techdufus/.config/mise#g; s#$sb/home#/home/techdufus#g; s#$sb#/home/techdufus#g" >"$fx/dry-$1.txt"
}
dry packages accounts,plugins,packages
dry system files,services,firewall,compose
dry dotfiles repos,dotfiles
dry shell mise-shell-activate,macos-defaults,macos-launchd-agents,linux-systemd-units,user
dry modules task,final-hook
sed -i '/^mise WARN/d' "$fx/dry-modules.txt"
{
  echo 'mise bootstrap: tools'
  mise ls --json | jq -r 'to_entries[] | select(.value | length > 0) | "mise \(.key)@\(.value[0].version) ⇢ would install"' | sort
} >"$fx/dry-tools.txt"
wc -l "$fx"/dry-*.txt
