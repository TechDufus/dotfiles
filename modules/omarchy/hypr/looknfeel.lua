-- Managed by ~/.dotfiles modules/omarchy. Tighter gaps than Omarchy's 5 / 10; cells.lua insets every cell by
-- these, so floating cells and tiles stay aligned. Omarchy's no-gaps toggle still loads later and wins.
hl.config({
  general = {
    gaps_in = 2,  -- each side of a window, so 4 px between neighbours
    gaps_out = 4, -- screen edges
  },
})

-- Every window fully opaque, focused or not, replacing Omarchy's 0.985 / 0.96 default and the
-- browsers' unfocused 0.985 (video showed the wallpaper through). Loaded after Omarchy's window rules,
-- so this rule wins; apps that want translucency set it themselves (Ghostty: background-opacity).
o.window(".*", { opacity = "1 1" })
