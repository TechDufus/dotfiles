#!/usr/bin/env bash
# Plasma session setup after packages and dotfiles landed. Fail-soft: never blocks the rest of bootstrap.
set -uo pipefail

# Enable SDDM (never start it), unless another display manager owns display-manager.service.
dm=/etc/systemd/system/display-manager.service
if [ ! -e "$dm" ] && [ ! -L "$dm" ]; then
  sudo systemctl enable sddm.service || echo "plasma: enabling sddm failed, skipped"
elif [ "$(basename "$(readlink "$dm")")" = "sddm.service" ]; then
  sudo systemctl enable sddm.service || echo "plasma: enabling sddm failed, skipped"
else
  echo "plasma: display-manager.service points to $(readlink "$dm" || echo "an existing unit"); sddm not enabled"
fi

# Desktop preferences and KWin shortcuts.
if [ -x /usr/bin/kwriteconfig6 ]; then
  # shellcheck source=/dev/null
  . ./settings.sh
else
  echo "plasma: kwriteconfig6 missing, KWin summon script not enabled, skipped"
fi

# Running-session steps only inside a graphical session.
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  if [ -x /usr/bin/qdbus6 ]; then
    qdbus6 org.kde.kglobalaccel /component/systemsettings_desktop org.kde.kglobalaccel.Component.cleanUp || true
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript plasma-summon || true
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
      "$HOME/.local/share/kwin/scripts/plasma-summon/contents/code/main.js" plasma-summon || true
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start || true
    "$HOME/.local/bin/plasma-summon-service" --configure-shortcuts || true
    qdbus6 org.kde.KWin /KWin reconfigure || true
  fi
  # Before the service restart below, so the service sees the graphical environment.
  dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE XDG_SESSION_DESKTOP DESKTOP_SESSION KDE_FULL_SESSION KDE_SESSION_VERSION \
    QT_WAYLAND_RECONNECT XDG_DATA_DIRS XKB_DEFAULT_LAYOUT XKB_DEFAULT_VARIANT XKB_DEFAULT_OPTIONS || true
fi

if ! { systemctl --user daemon-reload \
  && systemctl --user enable plasma-summon.service \
  && systemctl --user restart plasma-summon.service; }; then
  echo "plasma: plasma-summon.service not started; it starts at the next graphical login"
fi

exit 0
