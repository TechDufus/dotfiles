-- layouts.lua - Layout definitions with cell and app assignments
local positions = require("cell-management.positions")

-- Layout metadata for resolution-based auto-selection
-- Layouts can specify their preferred resolution (optional)
-- Resolution detection in init.lua will select the first matching layout

return {
  {
    name = "4K Workspace",
    min_width = 2560,  -- Only auto-select on 2560+ width screens
    cells = {
      positions.fourk.left_large,         -- Cell 1
      positions.fourk.right_side,         -- Cell 2
      positions.fourk.top_right,          -- Cell 3
      positions.fourk.center_left_large,  -- Cell 4
      positions.fourk.center_large,       -- Cell 5
      positions.fourk.right_small,        -- Cell 6
    },
    apps = {
      Terminal    = { cell = 1, open = true },  -- Auto-launch in cell 1
      Browser     = { cell = 2, open = true },
      Discord     = { cell = 3, open = true },
      Spotify     = { cell = 4, open = true },
      FileManager = { cell = 5, open = true },  -- Thunar in cell 5
      Obsidian    = { cell = 6 },               -- F13+n in cell 6 (don't auto-launch)
      OnePassword = { cell = 4 },
    },
  },
  {
    name = "HD Workspace",
    min_width = 0,     -- Default for smaller screens (1080p, 1440p)
    max_width = 2559,  -- Don't auto-select on 4K+
    cells = {
      positions.hd.left_main,         -- Cell 1: Terminal (60%)
      positions.hd.right_side,        -- Cell 2: Browser (40%)
      positions.hd.float_center,      -- Cell 4: Floating utilities
    },
    apps = {
      Terminal    = { cell = 1, open = true },
      Browser     = { cell = 2, open = true },
      Discord     = { cell = 3, open = true },
      Spotify     = { cell = 3, open = true },
      FileManager = { cell = 3 },
      Obsidian    = { cell = 3 },
      OnePassword = { cell = 3 },
    },
  },
  {
    name = "Standard Dev",
    cells = {
      positions.standard.top_left,
      positions.standard.bottom_left,
      positions.standard.center,
      positions.standard.right,
    },
    apps = {
      Terminal = { cell = 3, open = true },
      Browser  = { cell = 4, open = true },
      Discord  = { cell = 1, open = true },
      Spotify  = { cell = 2, open = true },
    },
  },
  {
    name = "Fullscreen",
    cells = {
      positions.full,  -- All windows fullscreen
    },
    apps = {
      Terminal    = { cell = 1, open = true },
      Browser     = { cell = 1, open = true },
      Discord     = { cell = 1, open = true },
      Spotify     = { cell = 1, open = true },
      FileManager = { cell = 1, open = true },
      Obsidian    = { cell = 1 },
      OnePassword = { cell = 1 },
    },
  },
}
