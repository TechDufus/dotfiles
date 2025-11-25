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
  },

  thirds = {
    left   = '0,0 27x40',
    center = '27,0 26x40',
    right  = '53,0 27x40',
  },

  halves = {
    left  = '0,0 40x40',
    right = '40,0 40x40',
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

    -- Center-left floating (behind terminal)
    center_left_float = '10,8 40x24',  -- Center-left float, ends at unit 50 (within terminal)
    center_left_large = '6,5 44x30',   -- Larger center-left float, ends at unit 50 (within terminal)

    -- Center positions
    center_large  = '10,5 60x30',     -- Large centered window
    center_padded = '1,1 78x38',      -- Centered with padding

    -- Utility positions
    right_small   = '48,8 30x24',     -- Small right-side window
  },
}
