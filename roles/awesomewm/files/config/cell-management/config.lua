-- config.lua - Shared configuration constants for cell management system

local M = {}

-- Hyper key definition (Shift+Super+Alt+Ctrl on Linux)
-- Change to { 'Mod4', 'Shift' } for easier pressing
M.hyper = { 'Shift', 'Mod4', 'Mod1', 'Control' }

-- Virtual grid dimensions (resolution-independent)
M.grid = {
  width = 80,
  height = 40,
}

return M
