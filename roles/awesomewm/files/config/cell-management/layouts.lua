-- layouts.lua - Layout definitions with cell and app assignments
local positions = require("cell-management.positions")

return {
  {
    name = "4K Workspace",
    cells = {
      { positions.fourk.left_large, positions.full },         -- Cell 1
      { positions.fourk.right_side, positions.full },         -- Cell 2
      { positions.fourk.top_right, positions.full },          -- Cell 3
      { positions.fourk.center_left_large, positions.full },  -- Cell 4
      { positions.fourk.center_large, positions.full },       -- Cell 5
      { positions.fourk.right_small, positions.full },        -- Cell 6
    },
    apps = {
      Terminal    = { cell = 1, open = true },  -- Auto-launch in cell 1
      Browser     = { cell = 2, open = true },
      Discord     = { cell = 3, open = true },
      Spotify     = { cell = 4, open = true },
      Obsidian    = { cell = 3 },               -- Don't auto-launch
      OnePassword = { cell = 4 },
    },
  },
  {
    name = "Standard Dev",
    cells = {
      { positions.standard.top_left, positions.standard.full_left },
      { positions.standard.bottom_left, positions.standard.full_left },
      { positions.standard.center, positions.standard.center },
      { positions.standard.right, positions.standard.right },
    },
    apps = {
      Terminal = { cell = 3, open = true },
      Browser  = { cell = 4, open = true },
      Discord  = { cell = 1, open = true },
      Spotify  = { cell = 2, open = true },
    },
  },
}
