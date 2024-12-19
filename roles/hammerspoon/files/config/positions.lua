return {
  full_grid = '80x40',
  full = '0,0 80x40',

  standard = {
    top_left     = '0,0 19x21',
    bottom_left  = '0,21 19x19',
    full_left    = '0,0 19x40',
    left_center  = '19,0 8x40',
    center       = '27,0 31x40',
    right        = '58,0 22x40',
    right_hidden = '45,5 30x30', -- This is a full 1920x1080 on a 5120x1440 screen
    left_hidden  = '5,5 30x30',  -- This is a full 1920x1080 on a 5120x1440 screen
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
