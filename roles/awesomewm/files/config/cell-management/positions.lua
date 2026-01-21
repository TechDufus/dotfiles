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

  -- 1080p Monitor layout (1920x1080)
  -- Optimized for smaller screens with less floating, more tiling
  hd = {
    -- Main work areas (60/40 split works better on smaller screens)
    left_main     = '0,0 48x40',      -- 60% width, full height (main focus)
    right_side    = '48,0 32x40',     -- 40% width, full height

    -- Side panels (for chat/music)
    left_panel    = '0,0 20x40',      -- 25% width sidebar
    right_panel   = '60,0 20x40',     -- 25% width sidebar

    -- Center workspace (with sidebars)
    center_main   = '20,0 40x40',     -- 50% width center (between sidebars)
    center_wide   = '20,0 60x40',     -- 75% width center (left sidebar only)

    -- Floating utilities (larger relative sizes for readability)
    float_center  = '10,4 60x32',     -- Large centered float
    float_right   = '45,4 34x32',     -- Right-side float

    -- Stacked layout positions
    top_right     = '48,0 32x20',     -- Top-right half
    bottom_right  = '48,20 32x20',    -- Bottom-right half
    top_left      = '0,0 48x20',      -- Top-left half
    bottom_left   = '0,20 48x20',     -- Bottom-left half
  },
}
