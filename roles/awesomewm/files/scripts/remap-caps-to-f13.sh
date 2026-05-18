#!/usr/bin/env bash
set -euo pipefail

localectl_field() {
  local field="$1"
  localectl status 2>/dev/null | awk -F': *' -v field="$field" '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); if ($1 == field) print $2 }'
}

setxkbmap_field() {
  local field="$1"
  setxkbmap -query 2>/dev/null | awk -v field="$field:" '$1 == field { print $2 }'
}

caps_lock_is_on() {
  command -v xset >/dev/null 2>&1 && xset q 2>/dev/null | grep -q 'Caps Lock:[[:space:]]*on'
}

turn_caps_lock_off() {
  if caps_lock_is_on && command -v xdotool >/dev/null 2>&1; then
    xdotool key Caps_Lock >/dev/null 2>&1 || true
  fi
}

layout="$(localectl_field "X11 Layout")"
model="$(localectl_field "X11 Model")"
variant="$(localectl_field "X11 Variant")"
options="$(localectl_field "X11 Options")"

if [ -z "$layout" ]; then layout="$(setxkbmap_field "layout")"; fi
if [ -z "$model" ]; then model="$(setxkbmap_field "model")"; fi
if [ -z "$variant" ]; then variant="$(setxkbmap_field "variant")"; fi
if [ -z "$options" ]; then options="$(setxkbmap_field "options")"; fi

if [ -z "$layout" ]; then layout="us"; fi
if [ -z "$model" ]; then model="pc105"; fi

case ",$options," in
  *,caps:none,*)
    ;;
  *)
    if [ -n "$options" ]; then
      options="$options,caps:none"
    else
      options="caps:none"
    fi
    ;;
esac

turn_caps_lock_off

setxkbmap -option

if [ -n "$variant" ]; then
  setxkbmap -model "$model" -layout "$layout" -variant "$variant" -option "$options"
else
  setxkbmap -model "$model" -layout "$layout" -option "$options"
fi

xmodmap -e 'keycode 66 = F13'
turn_caps_lock_off
