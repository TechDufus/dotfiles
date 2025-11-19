-- apps.lua - Application registry with WM_CLASS and summon keys
-- NOTE: WM_CLASS values must match exactly (use xprop WM_CLASS to verify)

return {
  Terminal = {
    class = "com.mitchellh.ghostty",  -- WM_CLASS to match (full name!)
    summon = "t",                     -- F13 + t
    exec = "ghostty",                 -- Command to launch
  },
  Browser = {
    class = "brave-browser",
    summon = "b",
    exec = "brave-browser",
  },
  Discord = {
    class = "discord",
    summon = "d",
    exec = "flatpak run com.discordapp.Discord",
  },
  Spotify = {
    class = "Spotify",           -- Note: Spotify uses capital S
    summon = "s",
    exec = "flatpak run com.spotify.Client",  -- Flatpak command
  },
  Obsidian = {
    class = "obsidian",
    summon = "n",
    exec = "obsidian",
  },
  OnePassword = {
    class = "1Password",         -- Note: capital P
    summon = "o",
    exec = "1password",
  },
  FileManager = {
    class = "Thunar",
    summon = "f",                -- F13 + f for files
    exec = "thunar",
  },
}
