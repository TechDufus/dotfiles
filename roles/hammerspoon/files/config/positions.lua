return {
  full_grid = '80x40',
  full = '0,0 80x40',

  -- EXACT PIXELS
  -- 0,0 1356x689
  -- 0,690 1356x751
  -- 1357,0 504x1440
  -- 1860,0 1902x1440
  -- 3720,0 1358x1440
  -- Estimated based on above: 5120x1440 -> 160x40
  -- 0,0 42x19
  -- 0,9 42x21
  -- 43,0 16x40
  -- 59,0 60x40
  -- 102,0 42x40
  standard = {
    top_left     = '0,0 20x21',
    bottom_left  = '0,21 20x19',
    full_left    = '0,0 20x40',
    left_center  = '20,0 9x40',
    center       = '29,0 31x40',
    right        = '60,0 20x40',
    right_hidden = '45,5 30x30', -- This is a full 1920x1080 on a 5120x1440 screen
    left_hidden  = '5,5 30x30', -- This is a full 1920x1080 on a 5120x1440 screen
  },

  thirds = {
    -- left   = '0,0 1706x1440',
    -- center = '1707,0 1706x1440',
    -- right  = '3414,0 1706x1440',
    left   = '0,0 54x40',
    center = '54,0 53x40',
    right  = '106,0 54x40',
  },

  halves = {
    -- left  = '0,0 2560x1440',
    -- right = '2560,0 2560x1440',
    left  = '0,0 80x40',
    right = '80,0 80x40',
  },
}
