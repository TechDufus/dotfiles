return {
  "sphamba/smear-cursor.nvim",
  opts = {
    -- How fast the smear's head moves towards the target.
    -- 0: no movement, 1: instantaneous, default: 0.6
    stiffness = 0.7,

    -- How fast the smear's tail moves towards the head.
    -- 0: no movement, 1: instantaneous, default: 0.3
    trailing_stiffness = 0.4,

    -- How much the tail slows down when getting close to the head.
    -- 0: no slowdown, more: more slowdown, default: 0.1
    trailing_exponent = 0.2,

    -- Stop animating when the smear's tail is within this distance (in characters) from the target.
    -- Default: 0.1
    distance_stop_animating = 0.3,
  }
}
