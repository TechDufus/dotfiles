return {
  {
    name = '4K Workspace',
    cells = {
      { positions.fourk.left_large,        positions.full },
      { positions.fourk.right_side,        positions.full },
      { positions.fourk.top_right,         positions.full },
      { positions.fourk.center_left_large, positions.full },
      { positions.fourk.center_large,      positions.full },
      { positions.fourk.right_small,       positions.full },
    },
    apps = {
      Terminal    = { cell = 1, open = true }, -- Primary workspace
      Browser     = { cell = 2, open = true }, -- Always docked right
      MatterMost  = { cell = 3, open = true }, -- Floating chat overlay
      Discord     = { cell = 3 },              -- Alternate chat
      Outlook     = { cell = 4 },              -- Email - center-left float (behind terminal)
      Spotify     = { cell = 4, open = true }, -- Music - center-left float (behind terminal)
      Finder      = { cell = 4 },              -- Files - center-left float (behind terminal)
      OnePassword = { cell = 4 },              -- Password manager - center-left float (behind terminal)
      Teams       = { cell = 5 },              -- Meeting focus - large centered
      Obsidian    = { cell = 3 },              -- Moved to smaller chat position
      ChatGPT     = { cell = 6 },              -- AI assistant popup
      Agenda      = { cell = 6 },              -- Granola popup
    },
  },
  {
    name = 'Fullscreen',
    cells = {
      { positions.full, positions.full },
    },
    apps = {
      Terminal    = { cell = 1, open = true },
      Browser     = { cell = 1, open = true },
      MatterMost  = { cell = 1 },
      Discord     = { cell = 1 },
      Outlook     = { cell = 1 },
      Spotify     = { cell = 1 },
      Finder      = { cell = 1 },
      OnePassword = { cell = 1 },
      Teams       = { cell = 1 },
      Obsidian    = { cell = 1 },
      ChatGPT     = { cell = 1 },
      Agenda      = { cell = 1 },
    },
  },
  {
    name = 'HD Workspace',
    cells = {
      { positions.hd.left_main,    positions.full },
      { positions.hd.right_side,   positions.full },
      { positions.hd.float_center, positions.full },
    },
    apps = {
      Terminal    = { cell = 1, open = true },
      Browser     = { cell = 2, open = true },
      MatterMost  = { cell = 3 },
      Discord     = { cell = 3 },
      Outlook     = { cell = 3 },
      Spotify     = { cell = 3 },
      Finder      = { cell = 3 },
      OnePassword = { cell = 3 },
      Teams       = { cell = 3 },
      Obsidian    = { cell = 3 },
      ChatGPT     = { cell = 3 },
      Agenda      = { cell = 3 },
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
      Teams       = { cell = 3 }, -- Meeting focus position
      Obsidian    = { cell = 6 }, -- Moved to utility position
      ChatGPT     = { cell = 6 },
      Terminal    = { cell = 4, open = true },
      Windows     = { cell = 4 },
      Browser     = { cell = 5, open = true },
      OnePassword = { cell = 6, open = true },
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
