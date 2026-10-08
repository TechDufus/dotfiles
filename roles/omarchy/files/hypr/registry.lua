-- Summon registry lookups shared by summon.lua and cells.lua. Managed by ~/.dotfiles roles/omarchy.
local apps = require("hypr.dotfiles.summon_apps")

local M = { apps = apps }

local function lower(s) return string.lower(s or "") end

-- True when the window's class or initial class equals one of app.classes (case-insensitive).
function M.matches(app, win)
  if not win then return false end
  local class, initial = lower(win.class), lower(win.initial_class)
  for _, cls in ipairs(app.classes) do
    local want = lower(cls)
    if class == want or initial == want then return true end
  end
  return false
end

function M.find(name)
  for _, app in ipairs(apps) do
    if app.name == name then return app end
  end
end

function M.for_window(win)
  for _, app in ipairs(apps) do
    if M.matches(app, win) then return app end
  end
end

return M
