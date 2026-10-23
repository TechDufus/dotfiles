#!/usr/bin/env bash
# Stage and validate both releases before touching installed Spoons.
set -uo pipefail

spoons="$HOME/.hammerspoon/Spoons"
grid_url="https://github.com/jesseleite/GridLayout.spoon/releases/latest/download/GridLayout.spoon.zip"
wm_url="https://github.com/TechDufus/WorkspaceManager.spoon/releases/latest/download/WorkspaceManager.spoon.zip"
tmp=$(mktemp -d) || { echo "hammerspoon: could not create temp dir, skipped"; exit 0; }
transaction=""
committed=0
# Invoked indirectly by the EXIT trap below.
# shellcheck disable=SC2317,SC2329
cleanup() {
  trap '' HUP INT TERM
  local name failed=0
  if [ -n "$transaction" ] && [ "$committed" -eq 0 ]; then
    # The filesystem records completed moves, even if a signal arrived before
    # the shell could record their success.
    for name in GridLayout.spoon WorkspaceManager.spoon; do
      if [ -e "$transaction/old/$name" ] || [ -L "$transaction/old/$name" ]; then
        if ! rm -rf "${spoons:?}/$name" || ! mv "$transaction/old/$name" "${spoons:?}/$name"; then
          failed=1
        fi
      elif [ -f "$transaction/absent-$name" ]; then
        rm -rf "${spoons:?}/$name" || failed=1
      fi
    done
  fi
  rm -rf "$tmp"
  if [ -n "$transaction" ]; then
    if [ "$failed" -eq 0 ]; then
      rm -rf "$transaction"
    else
      echo "hammerspoon: rollback incomplete; backups retained at $transaction"
    fi
  fi
}
trap cleanup EXIT
trap 'echo "hammerspoon: interrupted, skipped"; exit 0' HUP INT TERM
skip() { echo "hammerspoon: $*, skipped"; exit 0; }

curl -fsSL -o "$tmp/GridLayout.spoon.zip" "$grid_url" || skip "GridLayout download failed"
curl -fsSL -o "$tmp/WorkspaceManager.spoon.zip" "$wm_url" || skip "WorkspaceManager download failed"
mkdir -p "$tmp/staged/GridLayout.spoon" || skip "could not create staging directory"
unzip -q -o "$tmp/GridLayout.spoon.zip" -d "$tmp/staged/GridLayout.spoon" || skip "GridLayout unzip failed"
unzip -q -o "$tmp/WorkspaceManager.spoon.zip" -d "$tmp/staged" || skip "WorkspaceManager unzip failed"
for file in GridLayout.spoon/{init,state,events,helpers}.lua WorkspaceManager.spoon/{init,summon,workspace_manager}.lua; do
  if [ ! -s "$tmp/staged/$file" ] || [ -L "$tmp/staged/$file" ]; then
    skip "missing required file $file"
  fi
done
# Reject symlinks before patching or installing archive contents.
[ -z "$(find "$tmp/staged" -type l -print)" ] || skip "archive contains symlinks"
# Exact bundle IDs do not need the title-search fallback, which can block on Chromium.
for file in summon.lua workspace_manager.lua; do
  perl -0pi -e 's/hs\.application\.get\(([A-Za-z_][A-Za-z0-9_.]*)\) or hs\.application\.find\(\1\)/hs.application.get($1)/g' "$tmp/staged/WorkspaceManager.spoon/$file" || skip "patching $file failed"
done

changed=""
for name in GridLayout.spoon WorkspaceManager.spoon; do
  if [ ! -d "$spoons/$name" ] || ! diff -qr "$tmp/staged/$name" "$spoons/$name" >/dev/null 2>&1; then
    changed="$changed $name"
  fi
done
# No writes beneath the watched Hammerspoon directory on an unchanged run.
[ -n "$changed" ] || exit 0
mkdir -p "$spoons" || skip "could not create $spoons"
transaction=$(mktemp -d "$spoons/.bootstrap.XXXXXX") || skip "could not create replacement directory"
mkdir "$transaction/new" "$transaction/old" || skip "could not prepare replacement directory"
for name in $changed; do
  cp -R "$tmp/staged/$name" "$transaction/new/$name" || skip "could not stage replacement $name"
done

for name in $changed; do
  if [ -e "$spoons/$name" ] || [ -L "$spoons/$name" ]; then
    mv "$spoons/$name" "$transaction/old/$name" || skip "backing up $name failed"
  else
    # Record absence before installing so cleanup also handles a signal
    # immediately after the replacement rename.
    touch "$transaction/absent-$name" || skip "recording original state for $name failed"
  fi
  mv "$transaction/new/$name" "$spoons/$name" || skip "replacing $name failed"
done
committed=1
echo "hammerspoon: updated$changed"
exit 0
