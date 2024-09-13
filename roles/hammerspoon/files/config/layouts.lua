return {
  {
    name = 'Standard Dev',
    cells = {
      positions.standard.top_left,     -- 1
      positions.standard.bottom_left,  -- 2
      positions.standard.left_center,  -- 3
      positions.standard.center,       -- 4
      positions.standard.right,        -- 5
      positions.standard.left_hidden,  -- 6
      positions.standard.right_hidden, -- 7
    },
    apps = {
      MatterMost  = { cell = 1, open = true },
      Spotify     = { cell = 2, open = true },
      Obsidian    = { cell = 3, open = true },
      Kitty       = { cell = 4, open = true },
      Brave       = { cell = 5, open = true },
      OnePassword = { cell = 2, open = true },
      Discord     = { cell = 7, open = true },
      Outlook     = { cell = 7, },
    },
  },
  {
    name = 'Code Research',
    cells = {
      positions.standard.full_left,    -- 1
      positions.standard.left_center,  -- 2
      positions.standard.center,       -- 3
      positions.standard.right,        -- 4
      positions.standard.left_hidden,  -- 5
      positions.standard.right_hidden, -- 6
    },
    apps = {
      Brave    = { cell = 1, open = true },
      Obsidian = { cell = 2, open = true },
      Kitty    = { cell = 3, open = true },
    },
  },
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
