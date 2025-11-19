-- layouts.lua - Layout definitions with cell and app assignments
local positions = require("cell-management.positions")

return {
  {
    name = "4K Workspace",
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
      FileManager = { cell = 6, open = true },  -- Thunar in cell 6
      Obsidian    = { cell = 3 },               -- Don't auto-launch
      OnePassword = { cell = 4 },
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
