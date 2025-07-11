return {
  {
    name = '4K Workspace',
    cells = {
      { positions.fourk.left_large, positions.fourk.left_wide, positions.full, positions.fourk.center_padded }, -- 1: Terminal positions
      { positions.fourk.right_side, positions.halves.right },   -- 2: Browser positions
      { positions.fourk.top_right, positions.halves.left },     -- 3: Top-right float
      { positions.fourk.bottom_right, positions.halves.left },  -- 4: Bottom-right float
      { positions.fourk.center_large, positions.halves.right }, -- 5: Center overlay
      { positions.fourk.right_small, positions.halves.left },   -- 6: Small utility
    },
    apps = {
      Terminal    = { cell = 1, open = true }, -- Primary workspace
      Browser     = { cell = 2, open = true }, -- Always docked right
      MatterMost  = { cell = 3, open = true }, -- Floating chat overlay
      Teams       = { cell = 3 },              -- Alternate chat
      Discord     = { cell = 3 },              -- Alternate chat
      Outlook     = { cell = 4 },              -- Email with communication apps
      Spotify     = { cell = 4, open = true }, -- Floating music control
      Finder      = { cell = 4 },              -- Alternate utility
      Obsidian    = { cell = 5 },              -- On-demand focus overlay
      OnePassword = { cell = 6 },              -- Quick access popup
      Claude      = { cell = 6 },              -- AI assistant popup
    },
  },
  {
    name = 'Standard Dev',
    cells = {
      { positions.standard.top_left,     positions.standard.full_left },
      { positions.standard.bottom_left,  positions.standard.full_left },
      { positions.standard.left_center,  positions.standard.left_center },
      { positions.standard.center,       positions.standard.center },
      { positions.standard.right,        positions.standard.right },
      { positions.standard.left_hidden,  positions.standard.left_hidden },
      { positions.standard.right_hidden, positions.standard.right_hidden },
    },
    apps = {
      MatterMost  = { cell = 1, open = true },
      Spotify     = { cell = 2, open = true },
      Outlook     = { cell = 2, open = true },
      Finder      = { cell = 2 },
      Obsidian    = { cell = 3, open = true },
      Gpt         = { cell = 3 },
      Terminal    = { cell = 4, open = true },
      Windows     = { cell = 4 },
      Browser     = { cell = 5, open = true },
      OnePassword = { cell = 6, open = true },
      Teams       = { cell = 6 },
      Agenda      = { cell = 6 },
      Discord     = { cell = 7, open = true },
    },
  },
  -- {
  --   name = 'Code Research',
  --   cells = {
  --     positions.standard.full_left,    -- 1
  --     positions.standard.left_center,  -- 2
  --     positions.standard.center,       -- 3
  --     positions.standard.right,        -- 4
  --     positions.standard.left_hidden,  -- 5
  --     positions.standard.right_hidden, -- 6
  --   },
  --   apps = {
  --     Browser  = { cell = 1, open = true },
  --     Obsidian = { cell = 2, open = true },
  --     Terminal = { cell = 3, open = true },
  --   },
  -- },
}
-- {
--   name = 'No Ray',
--   cells = {
--     { '0,0 21x20' },
--     { '21,0 39x20' },
--   },
--   apps = {
--     Brave   = { cell = 1, open = true },
--     WezTerm = { cell = 2, open = true },
--     Tower   = { cell = 2 },
--   },
-- },
-- {
--   name = 'Code Focused',
--   cells = {
--     { '0,0 7x20',  positions.sixths.left },
--     { '7,0 53x20', positions.fiveSixths.right },
--   },
--   apps = {
--     Ray     = { cell = 1, open = true },
--     WezTerm = { cell = 2, open = true },
--     Brave   = { cell = 2, open = true },
--     Tower   = { cell = 2 },
--   },
-- },
