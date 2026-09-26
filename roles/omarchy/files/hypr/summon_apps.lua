-- Summon registry (managed by ~/.dotfiles roles/omarchy).
-- key: logical key after the CapsLock leader; uppercase = SHIFT + letter.
-- classes: exact window classes, case-insensitive (matched against class and initial_class).
-- exec: launch candidates; the first whose binary is on PATH wins (launched via uwsm-app).
-- workspace: home workspace for windows summon launches. bring: move an existing window to the current workspace.
return {
  { name = "terminal", key = "g", classes = { "com.mitchellh.ghostty", "ghostty", "foot" }, exec = { "ghostty", "xdg-terminal-exec" }, workspace = "1" },
  { name = "orca", key = "t", classes = { "orca" }, exec = { "stably-orca" } },
  { name = "browser", key = "b", classes = { "brave-browser", "chromium", "app.zen_browser.zen", "zen", "firefox" }, exec = { "omarchy-launch-browser" }, workspace = "2" },
  { name = "discord", key = "d", classes = { "discord" }, exec = { "discord" }, workspace = "4" },
  { name = "signal", key = "C", classes = { "signal" }, exec = { "signal-desktop" }, workspace = "4" },
  { name = "spotify", key = "s", classes = { "spotify" }, exec = { "spotify-launcher", "spotify" }, workspace = "5" },
  { name = "obsidian", key = "n", classes = { "obsidian" }, exec = { "obsidian" }, workspace = "3" },
  { name = "onepassword", key = "o", classes = { "com.onepassword.OnePassword", "1password" }, exec = { "1password" }, bring = true },
  { name = "files", key = "f", classes = { "org.gnome.nautilus" }, exec = { "nautilus --new-window" }, bring = true },
}
