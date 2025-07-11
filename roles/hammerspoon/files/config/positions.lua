return {
  full_grid = '80x40',
  full = '0,0 80x40',

  standard = {
    top_left     = '0,0 22x21',
    bottom_left  = '0,21 22x19',
    full_left    = '0,0 19x40',
    left_center  = '19,0 8x40',
    center       = '22,0 36x40',
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

  -- 4K Monitor layout (3840x2160)
  -- Grid-based positioning (80x40 grid)
  fourk = {
    -- Left side positions
    left_large    = '0,0 52x40',      -- 65% width, full height
    left_wide     = '0,0 64x40',      -- 80% width, full height
    
    -- Right side positions  
    right_side    = '52,0 28x40',     -- 35% width, full height
    
    -- Floating positions
    top_right     = '50,2 28x20',     -- Top-right quadrant
    bottom_right  = '50,20 28x18',    -- Bottom-right quadrant
    
    -- Center positions
    center_large  = '10,5 60x30',     -- Large centered window
    center_padded = '8,4 64x32',      -- Centered with padding
    
    -- Utility positions
    right_small   = '48,8 30x24',     -- Small right-side window
  },
}
