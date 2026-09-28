-- Summon registry (managed by ~/.dotfiles roles/omarchy).
-- Keys mirror roles/hammerspoon/files/config/apps.lua so macOS and Omarchy share muscle memory.
-- key: logical key after the CapsLock leader; uppercase = SHIFT + letter. No key = macro-only target.
-- classes: exact window classes, case-insensitive (matched against class and initial_class).
--   Omarchy web apps (omarchy-launch-webapp) get "brave-<host>__<path with / as _>-Default".
-- exec: launch candidates; the first whose binary is on PATH wins (launched via uwsm-app).
-- workspace: home workspace for windows summon launches. bring: move an existing window to the current workspace.
return {
  { name = "agenda", key = "a", classes = { "brave-notes.granola.ai__-Default" }, exec = { "omarchy-launch-webapp https://notes.granola.ai" } },
  { name = "browser", key = "b", classes = { "brave-browser", "chromium", "app.zen_browser.zen", "zen", "firefox" }, exec = { "omarchy-launch-browser" }, workspace = "2" },
  { name = "cursor", key = "c", classes = { "cursor" }, exec = { "cursor" } },
  { name = "signal", key = "C", classes = { "signal" }, exec = { "signal-desktop" }, workspace = "4" },
  { name = "discord", key = "d", classes = { "discord", "brave-discord.com__channels_@me-Default" }, exec = { "discord" }, workspace = "4" },
  { name = "outlook", key = "e", classes = { "brave-outlook.office.com__mail_-Default" }, exec = { "omarchy-launch-webapp https://outlook.office.com/mail/" } },
  { name = "files", key = "f", classes = { "org.gnome.nautilus" }, exec = { "nautilus --new-window" }, bring = true },
  { name = "teams", key = "m", classes = { "brave-teams.microsoft.com__v2_-Default" }, exec = { "omarchy-launch-webapp https://teams.microsoft.com/v2/" } },
  { name = "obsidian", key = "n", classes = { "md.obsidian.Obsidian", "obsidian" }, exec = { "obsidian" }, workspace = "3" },
  { name = "onepassword", key = "o", classes = { "com.onepassword.OnePassword", "1password" }, exec = { "1password" }, bring = true },
  { name = "orca", key = "O", classes = { "orca" }, exec = { "stably-orca" } },
  { name = "spotify", key = "s", classes = { "spotify" }, exec = { "spotify-launcher", "spotify" }, workspace = "5" },
  { name = "terminal", key = "t", classes = { "com.mitchellh.ghostty", "ghostty", "foot" }, exec = { "ghostty", "xdg-terminal-exec" }, workspace = "1" },
  -- Macro target (CapsLock twice, then g): Raycast GIF search stand-in.
  { name = "gifs", classes = { "brave-giphy.com__-Default" }, exec = { "omarchy-launch-webapp https://giphy.com" } },
}
