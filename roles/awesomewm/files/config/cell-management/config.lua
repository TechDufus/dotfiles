-- config.lua - Shared configuration constants for cell management system

local M = {}

-- Hyper key definition (Shift+Super+Alt+Ctrl on Linux)
-- Change to { 'Mod4', 'Shift' } for easier pressing
M.hyper = { 'Shift', 'Mod4', 'Mod1', 'Control' }

-- Optional per-screen layout defaults.
-- Keys can be XRandR output names (preferred), "primary", or "screen:<index>".
-- Values can be the layout name from layouts.lua or a numeric layout index.
-- Example:
-- M.screen_layouts = {
--   ["DP-1"] = "4K Workspace",
--   ["HDMI-1"] = "HD Workspace",
--   primary = "4K Workspace",
--   ["screen:2"] = "Fullscreen",
-- }
M.screen_layouts = {}

-- Virtual grid dimensions (resolution-independent)
M.grid = {
  width = 80,
  height = 40,
}

return M
