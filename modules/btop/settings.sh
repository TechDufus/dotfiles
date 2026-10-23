#!/usr/bin/env bash
# Sets the btop.conf keys named in the given files, later files winning, and leaves every
# other key where btop (or Omarchy's shipped default) put it. mise merges only JSON/TOML/YAML
# and btop rewrites the whole file when a setting changes in its menu, so neither a link,
# a copy, nor a block edit can own just these keys. Fail-soft.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"

owned=()
for f in "$@"; do
  case $f in /*) ;; *) f="$here/$f" ;; esac
  [ -r "$f" ] || { echo "btop: cannot read $f, skipped"; exit 0; }
  owned+=("$f")
done
[ ${#owned[@]} -gt 0 ] || { echo "btop: no settings files given, skipped"; exit 0; }

mkdir -p "${config%/*}" || { echo "btop: cannot create ${config%/*}, skipped"; exit 0; }
current=$config
[ -f "$config" ] || current=/dev/null

tmp="$(mktemp "$config.XXXXXX")" || { echo "btop: cannot create temp file, skipped"; exit 0; }
trap 'rm -f "$tmp"' EXIT

# Owned keys replace the first line that sets them in place (later duplicates are dropped);
# owned keys the file lacks are appended. Comments and unowned keys pass through unchanged.
if ! awk '
  function key(line,   k) {
    if (!match(line, /^[a-z0-9_]+[ \t]*=/)) return ""
    k = substr(line, 1, RLENGTH - 1)
    sub(/[ \t]+$/, "", k)
    return k
  }
  BEGIN {
    for (i = 1; i < ARGC - 1; i++) {
      while ((getline line < ARGV[i]) > 0) {
        k = key(line)
        if (k == "") continue
        v = line
        sub(/^[^=]*=[ \t]*/, "", v)
        sub(/[ \t\r]+$/, "", v)
        if (!(k in want)) order[++n] = k
        want[k] = k " = " v
      }
      close(ARGV[i])
      delete ARGV[i]
    }
  }
  {
    k = key($0)
    if (k != "" && (k in want)) {
      if (!(k in done)) { print want[k]; done[k] = 1 }
      next
    }
    print
  }
  END { for (i = 1; i <= n; i++) if (!(order[i] in done)) print want[order[i]] }
' "${owned[@]}" "$current" >"$tmp"; then
  echo "btop: merging into $config failed, skipped"
  exit 0
fi

[ "$current" != /dev/null ] && cmp -s "$tmp" "$config" && exit 0

# mv, not a write through: a leftover link into a checkout is replaced, never written into.
if ! { chmod 0644 "$tmp" && mv -f "$tmp" "$config"; }; then
  echo "btop: cannot write $config, skipped"
  exit 0
fi
echo "btop: set owned keys in $config"

# A running btop keeps its loaded settings and would write them back on its next save;
# SIGUSR2 makes it reload the file (Omarchy's theme switch sends the same signal).
pkill -USR2 -x btop >/dev/null 2>&1 || true
exit 0
